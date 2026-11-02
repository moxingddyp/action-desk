# Read-only LAN telemetry over an existing SSH connection. No installed service.
import json, os, time, shutil, subprocess, socket
from service_config import load_config
from pathlib import Path
from datetime import datetime
import copy, io, http.client, threading, ipaddress
from private_links import classify_peer, unknown_link
from lan_presence import HomeLANObserver, unknown_lan
from path_probes import PathProbeCache
APPLE_EPOCH = 978307200
PREVIOUS_PEERS = {}
MAX_AGE = 75
GATEWAY_POLL_SECONDS = 1
GATEWAY_MAX_AGE = 5
CONFIG = load_config()
GATEWAY_COMMAND = CONFIG.get('gatewayAdapter', {}).get('command', [])
HOST_UNITS = [tuple(entry) for entry in CONFIG.get('linux', {}).get('hostUnits', [])]
GUEST_UNITS = CONFIG.get('gatewayAdapter', {}).get('serviceNames', [])

def unread_gateway(error):
    return {'services': [{'name': name, 'state': 'unknown'} for name in GUEST_UNITS],
            'dnsListening': None, 'proxyListening': None,
            'proxy': {'nodes': [], 'source': 'openwrt-guest-controller', 'error': error},
            'privateLinks': {key: unknown_link() for key in ('mac','phone','winpc','linux')},
            'gatewayStatus': {'id':'gateway','host':'gateway','receivedAt':time.time()-APPLE_EPOCH,
                              'lanLink':unknown_lan(time.time()-APPLE_EPOCH), 'privateLink':unknown_link()}}

def host_services():
    values = []
    for name, user in HOST_UNITS:
        try:
            cmd = ['systemctl'] + (['--user'] if user else []) + ['is-active', name]
            p = subprocess.run(cmd, capture_output=True, text=True, timeout=1)
            state = p.stdout.strip()
            if state not in ('active', 'inactive', 'failed', 'activating', 'deactivating'):
                state = 'unknown'
        except (OSError, subprocess.TimeoutExpired):
            state = 'unknown'
        values.append({'name': name, 'state': state})
    return values

def read_gateway_snapshot():
    if not GATEWAY_COMMAND:
        raise RuntimeError('gateway_adapter_not_configured')
    if not isinstance(GATEWAY_COMMAND, list) or not all(isinstance(arg, str) for arg in GATEWAY_COMMAND):
        raise ValueError('invalid_gateway_adapter_command')
    p = subprocess.run(GATEWAY_COMMAND, capture_output=True, timeout=5, check=True)
    if len(p.stdout) > 1048576: raise ValueError('gateway_response_too_large')
    payload = json.loads(p.stdout)
    meta = payload['metadata']
    packet = payload.get('controller', {})
    expected = set(GUEST_UNITS)
    states = meta.get('services', [])
    if len(states) != len(expected) or {s.get('name') for s in states} != expected:
        raise ValueError('guest_service_identity_mismatch')
    for s in states:
        if s.get('state') not in ('active', 'inactive'):
            raise ValueError('invalid_guest_service_state')
    # Only the status adapter's explicit whitelist crosses back to the Mac.
    # Raw controller JSON is neither logged nor persisted.
    proxy = proxy_status(packet, CONFIG.get('gatewayAdapter', {}).get('proxyGroup', 'WAN')) if packet else {'nodes': [], 'error': 'controller_not_configured'}
    proxy['source'] = 'openwrt-guest-controller'
    observed_at = time.time() - APPLE_EPOCH
    private_links = {}
    for key in ('mac','phone','winpc','linux'):
        peer = meta.get('privatePeers', {}).get(key)
        private_links[key] = classify_peer(peer, meta.get('lanPrefixes', []), observed_at, PREVIOUS_PEERS.get(key))
        if isinstance(peer, dict): PREVIOUS_PEERS[key] = {**peer, 'observedAt': observed_at}
    own = meta.get('gatewaySelf', {})
    self_link = unknown_link(observed_at)
    self_link['target'] = '私网成员'
    if isinstance(own.get('online'), bool):
        self_link['online'] = own['online']
        self_link['kind'] = 'unknown' if own['online'] else 'offline'
    if isinstance(own.get('active'), bool): self_link['active'] = own['active']
    try:
        address = ipaddress.ip_address(own.get('tailnetAddress', ''))
        if address.version == 4: self_link['tailnetAddress'] = str(address)
    except ValueError: pass
    lan_link = unknown_lan(observed_at, 'gateway-home-interface-carrier')
    if isinstance(meta.get('lanInterfaceUp'), bool) and meta.get('lanPrefixes'):
        lan_link['state'] = 'online' if meta['lanInterfaceUp'] else 'offline'
        for prefix in meta['lanPrefixes']:
            try:
                address = ipaddress.ip_interface(prefix).ip
                if address.version == 4: lan_link['address'] = str(address); break
            except ValueError: pass
    gateway_status = {'id':'gateway','host':'gateway','receivedAt':observed_at,
                      'privateLink':self_link,'lanLink':lan_link,'services':states}
    return {'services': states,
            'dnsListening': meta.get('dnsListening') is True,
            'proxyListening': meta.get('proxyListening') is True,
            'proxy': proxy, 'privateLinks': private_links, 'gatewayStatus':gateway_status}

class GatewayCache:
    def __init__(self):
        self.lock = threading.Lock()
        self.last_started = -GATEWAY_POLL_SECONDS
        self.updated = 0
        self.running = False
        self.value = unread_gateway('awaiting_guest_sample')
    def refresh(self):
        with self.lock:
            if self.running or time.monotonic() - self.last_started < GATEWAY_POLL_SECONDS:
                return
            self.running = True; self.last_started = time.monotonic()
        threading.Thread(target=self._read, daemon=True, name='gateway-read').start()
    def _read(self):
        try:
            value = read_gateway_snapshot()
        except Exception as exc:
            value = unread_gateway(type(exc).__name__)
        value['services'] = host_services() + value['services']
        with self.lock:
            self.value = value; self.updated = time.monotonic(); self.running = False
    def snapshot(self):
        with self.lock:
            if not self.updated or time.monotonic() - self.updated > GATEWAY_MAX_AGE:
                value = unread_gateway('gateway_sample_stale')
                value['services'] = [{'name': n, 'state': 'unknown'} for n, _ in HOST_UNITS] + value['services']
                return value
            return copy.deepcopy(self.value)

def proxy_status(packet, group_name="WAN", now=None):
    now = time.time() if now is None else now
    proxies = packet.get('proxies', {})
    group = proxies.get(group_name, {})
    if not isinstance(group, dict):
        raise ValueError('Configured proxy group not returned')
    names = group.get('all')
    if not isinstance(names, list):
        raise ValueError('Configured proxy group has no member list')
    test_url = group.get('testUrl')
    selected = group.get('now')
    seen_choices = set()
    while selected not in seen_choices and isinstance(proxies.get(selected), dict) and isinstance(proxies[selected].get('all'), list):
        seen_choices.add(selected)
        selected = proxies[selected].get('now')
    members = []
    visited = set()
    def expand(name):
        if name in visited:return
        visited.add(name)
        item=proxies.get(name,{})
        if not isinstance(item,dict):return
        if isinstance(item.get('all'),list):
            for child in item['all']:expand(child)
        elif item.get('type') not in ('Direct','Reject','RejectDrop','Pass','Dns'):
            members.append(name)
    for name in names:expand(name)
    nodes = []
    for name in members:
        leaf = proxies.get(name, {})
        test = (leaf.get('extra') or {}).get(test_url, {}) if test_url else {}
        history = test.get('history') or []
        latest = history[-1] if history else {}
        stamp, age, delay = None, None, None
        try:
            parsed = datetime.fromisoformat(latest['time'].replace('Z', '+00:00'))
            if parsed.tzinfo is not None:
                stamp = parsed.isoformat()
                age = now - parsed.timestamp()
                delay = latest.get('delay')
                if not isinstance(delay, (int, float)) or delay < 0:
                    delay = None
        except (ValueError, KeyError, TypeError):
            pass
        fresh = age is not None and -5 <= age <= MAX_AGE
        health = 'unknown'
        if history and not fresh:
            health = 'stale'
        elif fresh and test.get('alive') is True:
            health = 'healthy'
        elif fresh and test.get('alive') is False:
            health = 'unhealthy'
        nodes.append({
            'id': name,
            'name': name,
            'type': leaf.get('type'),
            'selected': name == selected,
            'health': health,
            'latencyMs': delay if fresh and health == 'healthy' else None,
            'latencyKind': 'proxy_http',
            'probeAt': stamp,
            'ageSeconds': round(age, 1) if age is not None else None,
        })
    return {'group': group_name, 'groupType': group.get('type'),
            'selected': selected, 'nodes': nodes,
            'source': 'mihomo-native-url-test-history',
            'sampledAtUnix': now}

def main():
    last=None
    cache=GatewayCache()
    lan=HomeLANObserver(interface=CONFIG.get('linux', {}).get('lanInterface'), windows_alias=CONFIG.get('windows', {}).get('sshAlias'))
    probes=PathProbeCache()
    while True:
        started=time.monotonic()
        try:
            cpu=list(map(int,Path('/proc/stat').read_text().splitlines()[0].split()[1:]));total=sum(cpu[:8]);idle=cpu[3]+cpu[4]
            mem={r.split(':')[0]:int(r.split()[1])*1024 for r in Path('/proc/meminfo').read_text().splitlines()}
            routes=[r.split() for r in Path('/proc/net/route').read_text().splitlines()[1:]]
            interfaces={r[0] for r in routes if r[1]=='00000000'}
            net={r.split(':')[0].strip():list(map(int,r.split(':')[1].split())) for r in Path('/proc/net/dev').read_text().splitlines()[2:]}
            rx=sum(net[n][0] for n in interfaces if n in net);tx=sum(net[n][8] for n in interfaces if n in net)
            gpu=None
            for f in Path('/sys/class/drm').glob('card*/device/gpu_busy_percent'):
                try:gpu=float(f.read_text().strip());break
                except (OSError,ValueError):pass
            disks=[]
            for mount in CONFIG.get('linux', {}).get('mounts', ['/']):
                if mount!='/' and not os.path.ismount(mount):continue
                u=shutil.disk_usage(mount);disks.append({'name':mount,'total':u.total,'used':u.used})
            cache.refresh()
            gateway=cache.snapshot()
            probes.refresh(gateway['privateLinks'])
            gateway['privateLinks']=probes.overlay(gateway['privateLinks'])
            pct=None if last is None else max(0,min(100,100*(1-(idle-last[1])/max(1,total-last[0]))))
            elapsed=started-last[4] if last else 0
            result={'id':'linux','host':socket.gethostname(),'cpu':pct,'gpu':gpu,'memoryUsed':mem['MemTotal']-mem['MemAvailable'],'memoryTotal':mem['MemTotal'],'download':None if not last else max(0,(rx-last[2])/elapsed),'upload':None if not last else max(0,(tx-last[3])/elapsed),'interfaces':','.join(sorted(interfaces)), 'disks':disks,'services':gateway['services'],'dnsListening':gateway['dnsListening'],'proxyListening':gateway['proxyListening'],'uptime':float(Path('/proc/uptime').read_text().split()[0]), 'proxy':gateway['proxy'],'privateLinks':gateway['privateLinks'],'gatewayStatus':gateway['gatewayStatus'],'lanLinks':lan.snapshot()}
            print(json.dumps(result),flush=True);last=(total,idle,rx,tx,started)
        except Exception as e:
            print(json.dumps({'id':'linux','host':socket.gethostname(),'error':type(e).__name__}),flush=True)
        time.sleep(max(.05,1-(time.monotonic()-started)))

if __name__ == "__main__":
    main()
