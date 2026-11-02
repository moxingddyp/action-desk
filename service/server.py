#!/usr/bin/env python3
"""Private workbench read service, Linux-owned telemetry and atomic action snapshots."""
import argparse
import ipaddress
import copy
import datetime
import hashlib
import hmac
import json
import math
import os
from pathlib import Path
import re
import signal
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import activity
from private_links import apply_links, unknown_link
from lan_presence import fresh_lan, unknown_lan
from app_updates import ReleaseStore, ReleaseUnavailable, InvalidRelease

APPLE_EPOCH = 978307200
MAX_BODY = 2_000_000
IDS = ('mac', 'winpc', 'linux')
TAGS = {'优先做', '正在做', '当前可做', '条件做'}
HERE = Path(__file__).resolve().parent


def apple_now(): return time.time() - APPLE_EPOCH


def atomic_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    temp = path.with_name(path.name + '.tmp')
    data = json.dumps(value, ensure_ascii=False, allow_nan=False, separators=(',', ':')).encode()
    fd = os.open(temp, os.O_CREAT | os.O_TRUNC | os.O_WRONLY, 0o600)
    with os.fdopen(fd, 'wb') as handle:
        handle.write(data)
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(temp, path)
    path.chmod(0o600)


def parse_stamp(value):
    if not isinstance(value, str): raise ValueError('invalid_generated_at')
    parsed = datetime.datetime.fromisoformat(value.replace('Z', '+00:00'))
    if parsed.tzinfo is None: raise ValueError('generated_at_needs_timezone')
    return parsed.timestamp()


def validate_actions(value):
    if not isinstance(value, dict) or value.get('schemaVersion') != 1:
        raise ValueError('invalid_action_schema')
    for key in ('sourceRevision', 'revision'):
        if not re.fullmatch('[a-f0-9]{64}', value.get(key, '')):
            raise ValueError('invalid_' + key)
    if parse_stamp(value.get('generatedAt')) > time.time() + 300:
        raise ValueError('generated_at_in_future')
    items = value.get('items')
    if not isinstance(items, list) or len(items) >= 10000:
        raise ValueError('invalid_items')
    ids = set()
    for item in items:
        if not isinstance(item, dict) or not re.fullmatch(r'(?:[a-f0-9]{16}|[0-9]{4}-A[0-9]{2,})', item.get('id', '')):
            raise ValueError('invalid_item_id')
        if item['id'] in ids: raise ValueError('duplicate_item')
        ids.add(item['id'])
        tags = item.get('tags', [item.get('group')])
        if not isinstance(tags, list) or len(set(tags)) != len(tags) or not set(tags) <= TAGS:
            raise ValueError('invalid_item_tags')
        if len(set(tags) & {'正在做', '当前可做', '条件做'}) != 1:
            raise ValueError('ambiguous_item_classification')
        for k in ('label', 'current', 'next', 'deadline', 'output'):
            if not isinstance(item.get(k), str): raise ValueError('invalid_item_' + k)
    groups = value.get('groups')
    if not isinstance(groups, list): raise ValueError('invalid_groups')
    for g in groups:
        if not isinstance(g, dict) or g.get('name') not in TAGS:
            raise ValueError('invalid_group')
        if g.get('count') != sum(g['name'] in i.get('tags', [i.get('group')]) for i in items):
            raise ValueError('group_count_mismatch')
    if not isinstance(value.get('calendarEvents', []), list): raise ValueError('invalid_calendar')
    evidence = value.get('activityEvidence', {})
    if not isinstance(evidence, dict): raise ValueError('invalid_activity_evidence')
    if any(not isinstance(v, dict) or not isinstance(v.get('lastProgress', ''), str) or v.get('executionState') not in ('执行中', '未执行', '已结束') for v in evidence.values()):
        raise ValueError('invalid_activity_entry')
    return value


def action_view(value, now=None):
    result = copy.deepcopy(value)
    evidence = result.get('activityEvidence', {})
    if not evidence: return result
    lines = ['## 事项安排', '| 事项ID | 名称 | 标签 |']
    for item in result['items']:
        lines.append('| ' + item['id'] + ' | item | ' + '、'.join(item.get('tags', [item.get('group')])) + ' |')
    lines += ['## 行动活跃依据', '| 事项ID | 时间 | 状态 | 证据 |']
    for key, item in evidence.items():
        lines.append('| ' + key + ' | ' + item.get('lastProgress', '') + ' | ' + item.get('executionState', '') + ' | snapshot |')
    _, changes, _ = activity.classify('\n'.join(lines), now)
    changed = {c['id']: c['after'].split('、') for c in changes}
    for item in result['items']:
        if item['id'] in changed:
            item['tags'] = changed[item['id']]
            item['group'] = item['tags'][0]
            item['groupShort'] = item['group']
    for group in result['groups']:
        group['count'] = sum(group['name'] in i.get('tags', [i.get('group')]) for i in result['items'])
    result['sourceSnapshotRevision'] = result['revision']
    # Keep the original source hash and snapshot timestamp. Display changes get
    # their own revision so clients refresh without claiming a new source edit.
    if changes:
        result['revision'] = hashlib.sha256(json.dumps({'source': result['revision'], 'changes': changes},sort_keys=True).encode()).hexdigest()
    result['activityEvaluatedAt'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    return result


PHONE_FIELDS = {'id', 'host', 'batteryPercent', 'batteryCharging', 'onACPower',
                'memoryUsed', 'memoryTotal', 'disks', 'networkType'}
PHONE_NETWORK_TYPES = {'wifi', 'mobile', 'ethernet', 'vpn', 'none', 'unknown'}


def validate_phone(value):
    if not isinstance(value, dict) or not set(value) <= PHONE_FIELDS or value.get('id') != 'phone':
        raise ValueError('invalid_phone_fields')
    if not isinstance(value.get('host'), str) or not 0 < len(value['host']) <= 200:
        raise ValueError('invalid_phone_host')
    def finite_number(v):
        return not isinstance(v, bool) and isinstance(v, (int, float)) and math.isfinite(v)
    if 'batteryPercent' in value and (not finite_number(value['batteryPercent']) or not 0 <= value['batteryPercent'] <= 100):
        raise ValueError('invalid_phone_battery')
    for field in ('batteryCharging', 'onACPower'):
        if field in value and not isinstance(value[field], bool): raise ValueError('invalid_phone_' + field)
    for field in ('memoryUsed', 'memoryTotal'):
        if field in value and (not finite_number(value[field]) or value[field] < 0): raise ValueError('invalid_phone_' + field)
    if 'memoryUsed' in value and ('memoryTotal' not in value or value['memoryUsed'] > value['memoryTotal']):
        raise ValueError('invalid_phone_memory_bounds')
    if 'networkType' in value and (not isinstance(value['networkType'], str) or value['networkType'] not in PHONE_NETWORK_TYPES):
        raise ValueError('invalid_phone_network_type')
    if 'disks' in value:
        if not isinstance(value['disks'], list) or len(value['disks']) > 32: raise ValueError('invalid_phone_disks')
        names = set()
        for disk in value['disks']:
            if not isinstance(disk, dict) or set(disk) != {'name','total','used'}:
                raise ValueError('invalid_phone_disk')
            if not isinstance(disk['name'], str) or not 0 < len(disk['name']) <= 120 or disk['name'] in names:
                raise ValueError('invalid_phone_disk_name')
            names.add(disk['name'])
            if not finite_number(disk['total']) or not finite_number(disk['used']) or not 0 <= disk['used'] <= disk['total']:
                raise ValueError('invalid_phone_disk_bounds')
    return value


def combine_phone(network_sample, hardware, now):
    link = copy.deepcopy(network_sample['privateLink'])
    result = {'id':'phone', 'host':'phone', 'privateLink':link,
              'networkObservedAt':link['observedAt'], 'hardwareSampleAvailable':hardware is not None,
              'hardwareFresh':False}
    if 'lanLink' in network_sample: result['lanLink'] = copy.deepcopy(network_sample['lanLink'])
    if hardware is not None:
        result.update(copy.deepcopy(hardware))
        result['privateLink'] = link
        result['hardwareFresh'] = 0 <= now-hardware.get('receivedAt', 0) < 12
        if not result['hardwareFresh']: result['hardwareIssue'] = '手机硬件采样未更新'
    if link['kind'] == 'unknown': result['networkIssue'] = '私网路径未取得或已过期'
    elif link['kind'] == 'offline': result['networkIssue'] = '手机私网离线'
    return result


class Store:
    def __init__(self, directory):
        self.directory = Path(directory)
        self.directory.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.lock = threading.RLock()
        self.samples = {}
        self.sample_counts = {k: 0 for k in IDS}
        self.actions = None
        self.actions_received = None
        p = self.directory / 'actions.json'
        if p.exists():
            self.actions = validate_actions(json.loads(p.read_text()))
            self.actions_received = p.stat().st_mtime
        self.sampling_errors = {}

    def accept_sample(self, value, expected):
        if not isinstance(value, dict) or value.get('id') != expected:
            raise ValueError('sample_identity_mismatch')
        if expected == 'phone': validate_phone(value)
        for k in ('cpu', 'gpu', 'memoryUsed', 'memoryTotal', 'download', 'upload', 'uptime'):
            v = value.get(k)
            if v is not None and (not isinstance(v, (float, int)) or not math.isfinite(v)):
                raise ValueError('invalid_sample_' + k)
        if expected == 'mac':
            if 'batteryPercent' in value:
                battery = value['batteryPercent']
                if isinstance(battery, bool) or not isinstance(battery, (int, float)) or not math.isfinite(battery) or not 0 <= battery <= 100:
                    raise ValueError('invalid_sample_batteryPercent')
            for key in ('batteryCharging', 'onACPower'):
                if key in value and not isinstance(value[key], bool):
                    raise ValueError('invalid_sample_' + key)
        clean = copy.deepcopy(value)
        clean['receivedAt'] = apple_now()
        if not clean.get('error'): clean.pop('issue', None)
        with self.lock:
            self.samples[expected] = clean
            self.sample_counts[expected] = self.sample_counts.get(expected, 0) + 1
            self.sampling_errors.pop(expected, None)

    def issue(self, expected, error):
        with self.lock: self.sampling_errors[expected] = error

    def telemetry(self):
        now = apple_now()
        with self.lock:
            devices = []
            for k in IDS:
                s = copy.deepcopy(self.samples.get(k, {'id': k, 'host': '', 'issue': '等待采样'}))
                if k in self.sampling_errors: s['issue'] = self.sampling_errors[k]
                elif now - s.get('receivedAt', 0) >= 12: s['issue'] = '采样未更新'
                devices.append(s)
            phone_hardware = copy.deepcopy(self.samples.get('phone'))
        linux = next((d for d in devices if d['id']=='linux'), {})
        lan_links = linux.get('lanLinks', {})
        gateway = copy.deepcopy(linux.get('gatewayStatus'))
        linux_fresh = not linux.get('issue') and not linux.get('error') and 0 <= now-linux.get('receivedAt',0)<5
        devices, phone = apply_links(devices, now)
        for sample in devices:
            lan = fresh_lan(lan_links.get(sample['id']), now) if linux_fresh else unknown_lan(now)
            if lan.pop('requiresFreshSample', False):
                if not sample.get('issue') and not sample.get('error') and 0 <= now-sample.get('receivedAt',0)<5 and 0 <= now-lan.get('observedAt',0)<5:
                    lan['state'] = 'online'
                    lan['observedAt'] = min(lan['observedAt'], sample['receivedAt'])
                else: lan['state'] = 'unknown'
            sample['lanLink'] = lan
        phone['lanLink'] = fresh_lan(lan_links.get('phone'), now) if linux_fresh else unknown_lan(now)
        phone = combine_phone(phone, phone_hardware, now)
        if not gateway or not linux_fresh or not 0 <= now-gateway.get('receivedAt',0)<5:
            gateway = {'id':'gateway','host':'gateway','receivedAt':now,
                       'lanLink':unknown_lan(now),'privateLink':unknown_link(now), 'issue':'网关状态未取得或已过期'}
        else:
            gateway['lanLink'] = fresh_lan(gateway.get('lanLink'),now)
            parent_lan = next((d['lanLink'] for d in devices if d['id']=='linux'), unknown_lan(now))
            if gateway['lanLink'].get('state')=='online' and parent_lan.get('state')!='online':
                gateway['lanLink']['state']='offline' if parent_lan.get('state')=='offline' else 'unknown'
            gateway['lanLink']['source']='gateway-home-interface-and-linux-parent-carrier'
        return {'generatedAt': now, 'devices': devices, 'phone': phone, 'gateway':gateway}

    def put_actions(self, value):
        validate_actions(value)
        with self.lock:
            if self.actions and parse_stamp(value['generatedAt']) < parse_stamp(self.actions['generatedAt']):
                raise ValueError('older_snapshot_rejected')
            atomic_json(self.directory / 'actions.json', value)
            self.actions = copy.deepcopy(value)
            self.actions_received = time.time()
        return {'accepted': True, 'sourceRevision': value['sourceRevision']}


class Sampler:
    def __init__(self, store, device, args):
        self.store, self.device, self.args = store, device, args
        self.stop = threading.Event()
        self.process = None
        self.thread = threading.Thread(target=self.run, daemon=True, name='sampler-' + device)
    def start(self): self.thread.start()
    def close(self):
        self.stop.set()
        if self.process and self.process.poll() is None:
            self.process.terminate()
    def run(self):
        while not self.stop.is_set():
            last = time.monotonic()
            try:
                self.process = subprocess.Popen(self.args, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                                bufsize=0, start_new_session=True)
                process = self.process
                stderr = process.stderr
                # Drain diagnostics, never persist payload/credentials.
                def drain():
                    while stderr.read(4096): pass
                threading.Thread(target=drain, daemon=True).start()
                def watchdog():
                    while process.poll() is None and not self.stop.wait(2):
                        if time.monotonic() - last > 25:
                            process.terminate()
                            break
                threading.Thread(target=watchdog, daemon=True).start()
                for raw in self.process.stdout:
                    if self.stop.is_set(): break
                    if len(raw) > 131072:
                        self.store.issue(self.device, '采样响应过大'); continue
                    try:
                        value = json.loads(raw)
                        self.store.accept_sample(value, self.device)
                        last = time.monotonic()
                    except (ValueError, TypeError, json.JSONDecodeError):
                        self.store.issue(self.device, '采样格式无效')
                self.process.wait(timeout=3)
                if not self.stop.is_set(): self.store.issue(self.device, '采样连接断开，等待重连')
            except (OSError, subprocess.SubprocessError):
                self.store.issue(self.device, '采样器启动失败，等待重连')
                if self.process and self.process.poll() is None: self.process.kill()
            self.stop.wait(5)


class Service(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True


class Handler(BaseHTTPRequestHandler):
    server_version = 'CXYWorkbench/1'
    def log_message(self, *args): pass
    def setup(self):
        super().setup()
        self.connection.settimeout(8)
    def answer(self, code, value):
        data = json.dumps(value, ensure_ascii=False, allow_nan=False, separators=(',', ':')).encode()
        self.send_response(code)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Content-Length', str(len(data)))
        if self.server.store.actions:
            self.send_header('X-Actions-Received-At', str(self.server.store.actions_received))
        self.end_headers()
        self.wfile.write(data)
    def authorized(self, role):
        supplied = self.headers.get('Authorization', '')
        wanted = 'Bearer ' + self.server.config.get(role, '')
        if not self.server.config.get(role) or not hmac.compare_digest(supplied, wanted):
            self.answer(401, {'error': 'unauthorized'})
            return False
        return True
    def release_store(self):
        return ReleaseStore(self.server.store.directory / 'app-releases/android')
    def apk_download(self):
        try:
            manifest, handle = self.release_store().open_download(self.path)
        except ReleaseUnavailable:
            self.answer(404, {'error':'android_apk_unavailable'});return
        except (InvalidRelease,OSError):
            self.answer(503, {'error':'android_release_invalid'});return
        with handle:
            self.send_response(200)
            self.send_header('Content-Type','application/vnd.android.package-archive')
            self.send_header('Content-Length',str(manifest['size']))
            self.send_header('Content-Disposition','attachment; filename="CXY-Workbench-'+str(manifest['versionCode'])+'.apk"')
            self.send_header('Cache-Control','no-store')
            self.send_header('ETag','"'+manifest['sha256']+'"')
            self.end_headers()
            try:
                while True:
                    block=handle.read(65536)
                    if not block:break
                    self.wfile.write(block)
            except (BrokenPipeError,ConnectionResetError):
                # Client cancelled; no release state or update result changes.
                return
    def do_GET(self):
        if not self.authorized('readToken'): return
        if self.path == '/v1/health':
            with self.server.store.lock:
                value = {'ok': True, 'schemaVersion': 1, 'sampleIntervalSeconds': 1,
                         'sampleCounts': dict(self.server.store.sample_counts),
                         'actionsAvailable': self.server.store.actions is not None,
                         'actionsReceivedAt': self.server.store.actions_received}
            self.answer(200, value)
        elif self.path == '/v1/app-updates/android':
            try: manifest=self.release_store().current()
            except ReleaseUnavailable: self.answer(404, {'error':'android_release_unavailable'})
            except (InvalidRelease,OSError): self.answer(503, {'error':'android_release_invalid'})
            else: self.answer(200,manifest)
        elif self.path.startswith('/v1/app-updates/android/apk/'):
            self.apk_download()
        elif self.path == '/v1/information':
            try:
                path = self.server.store.directory / 'information.json'
                if path.stat().st_size > 2000000: raise ValueError('report_too_large')
                value = json.loads(path.read_text())
                if not isinstance(value, dict) or not isinstance(value.get('highlights'), list): raise ValueError('invalid_report')
            except FileNotFoundError: self.answer(404, {'error': 'information_not_published'})
            except (OSError, ValueError): self.answer(503, {'error': 'information_invalid'})
            else: self.answer(200, value)
        elif self.path == '/v1/telemetry': self.answer(200, self.server.store.telemetry())
        elif self.path == '/v1/actions':
            with self.server.store.lock: value = action_view(self.server.store.actions) if self.server.store.actions else None
            self.answer(200 if value else 503, value or {'error': 'no_action_snapshot'})
        else: self.answer(404, {'error': 'not_found'})
    def do_PUT(self):
        role = {'/v1/actions': 'actionsToken', '/v1/mac': 'macToken', '/v1/phone':'phoneToken'}.get(self.path)
        if not role:
            self.answer(404, {'error': 'not_found'}); return
        if not self.authorized(role): return
        try:
            if self.headers.get('Transfer-Encoding'): raise ValueError('chunked_body_not_supported')
            count = int(self.headers.get('Content-Length', '0'))
            if not 0 < count <= MAX_BODY: raise ValueError('invalid_body_length')
            raw = self.rfile.read(count)
            if len(raw) != count: raise ValueError('incomplete_body')
            digest = self.headers.get('X-Content-SHA256')
            if digest and not hmac.compare_digest(digest, hashlib.sha256(raw).hexdigest()):
                raise ValueError('content_hash_mismatch')
            value = json.loads(raw, parse_constant=lambda _: (_ for _ in ()).throw(ValueError('non_finite_json')))
            if self.path == '/v1/mac':
                # Only a whitelisted Mac counter packet is allowed, not arbitrary commands.
                fields = {'id','host','cpu','gpu','gpuMemoryUsed','gpuMemoryTotal','memoryUsed','memoryTotal',
                          'download','upload','interfaces','disks','uptime','error','issue','receivedAt',
                          'batteryPercent','batteryCharging','onACPower'}
                if not isinstance(value, dict) or not set(value) <= fields: raise ValueError('invalid_mac_fields')
                self.server.store.accept_sample(value, 'mac'); result = {'accepted': True}
            elif self.path == '/v1/phone':
                self.server.store.accept_sample(value, 'phone'); result = {'accepted': True}
            else: result = self.server.store.put_actions(value)
            self.answer(200, result)
        except (ValueError, TypeError, KeyError, json.JSONDecodeError):
            self.answer(400, {'error': 'invalid_payload'})


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--config', required=True)
    args = parser.parse_args()
    config = json.loads(Path(args.config).read_text())
    address = config.get('bind', '127.0.0.1')
    parsed_address = ipaddress.ip_address(address)
    if not parsed_address.is_loopback and not config.get('allowPrivateBind', False):
        raise ValueError('explicit_private_bind_required')
    if parsed_address.is_unspecified or parsed_address.is_multicast or parsed_address.is_global:
        raise ValueError('private_bind_required')
    os.environ['WORKBENCH_CONFIG'] = str(Path(args.config).resolve())
    store = Store(config['stateDirectory'])
    server = Service((address, config.get('port', 18766)), Handler)
    server.store, server.config = store, config
    samplers = []
    if config.get('linux', {}).get('enabled', False):
        samplers.append(Sampler(store, 'linux', ['python3', '-u', str(HERE / 'linux_telemetry.py')]))
    windows_config = config.get('windows', {})
    if windows_config.get('enabled', False):
        import base64
        alias = windows_config['sshAlias']
        if not isinstance(alias, str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]*', alias):
            raise ValueError('invalid_windows_ssh_alias')
        windows = (HERE / 'windows_telemetry.ps1').read_text().encode('utf-16-le')
        encoded = base64.b64encode(windows).decode()
        samplers.append(Sampler(store, 'winpc', ['ssh', '-T', '-o', 'BatchMode=yes',
            '-o', 'StrictHostKeyChecking=yes', '-o', 'ConnectTimeout=5',
            '-o', 'ServerAliveInterval=6', '-o', 'ServerAliveCountMax=2',
            alias, 'pwsh', '-NoProfile', '-NonInteractive', '-EncodedCommand', encoded]))
    for sampler in samplers: sampler.start()
    def stop(*_):
        for sampler in samplers: sampler.close()
        threading.Thread(target=server.shutdown, daemon=True).start()
    signal.signal(signal.SIGTERM, stop); signal.signal(signal.SIGINT, stop)
    try: server.serve_forever(poll_interval=.25)
    finally:
        for sampler in samplers: sampler.close()
        server.server_close()


if __name__ == '__main__': main()
