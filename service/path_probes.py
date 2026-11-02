"""Bounded, serial official Tailscale route measurements for idle PC/Linux peers."""
from service_config import load_config
import copy
import ipaddress
import json
import math
import re
import shlex
import subprocess
import threading
import time
from private_links import classify_peer, endpoint_ip

APPLE_EPOCH = 978307200
CONFIG = load_config().get('pathProbes', {})
PEERS = CONFIG.get('peers', {})
PROBE_INTERVAL = 30
PROBE_MAX_AGE = 45
PROBE_COMMAND = CONFIG.get('command', [])
ROUTE_COMMAND = CONFIG.get('routeContextCommand', [])
PONG = re.compile(r'^pong from .+ \((?P<peer>[0-9.]+)\) via (?P<route>.+?) in (?P<latency>[0-9]+(?:\.[0-9]+)?)(?P<unit>ms|s|µs|us|ns)$')


def parse_pong(output, expected):
    if expected not in PEERS.values():raise ValueError('probe_target_not_allowed')
    parsed=None
    for line in output.splitlines():
        matched=PONG.fullmatch(line.strip())
        if not matched or matched['peer']!=expected:continue
        latency=float(matched['latency'])*{'s':1000,'ms':1,'µs':.001,'us':.001,'ns':.000001}[matched['unit']]
        if not math.isfinite(latency) or not 0<=latency<=10000:continue
        route=matched['route']
        if route.startswith('DERP(') and route.endswith(')') and re.fullmatch('[A-Za-z0-9_-]+',route[5:-1]):
            parsed={'kind':'derp','relay':route[5:-1],'latencyMs':latency}
        elif route.startswith('peer-relay(') and route.endswith(')'):
            relay=route[11:-1]
            if relay and re.fullmatch(r'[A-Za-z0-9.:_\[\]%-]+',relay):parsed={'kind':'peer-relay','relay':relay,'latencyMs':latency}
        elif endpoint_ip(route) is not None:
            address=endpoint_ip(route)
            parsed={'kind':'direct','endpoint':route,'transportVersion':'IPv4' if address.version==4 else 'IPv6','latencyMs':latency}
    if parsed is None:raise ValueError('no_valid_pong')
    return parsed


def route_context(address):
    address = str(ipaddress.ip_address(address))
    if not ROUTE_COMMAND: raise RuntimeError('route_context_not_configured')
    p = subprocess.run(ROUTE_COMMAND + [address], capture_output=True, timeout=3, check=True)
    return json.loads(p.stdout)


def probe_peer(key):
    if key not in PEERS:raise ValueError('probe_target_not_allowed')
    ip=PEERS[key]
    try:
        if not PROBE_COMMAND: raise RuntimeError('path_probe_not_configured')
        # Explicit operator adapter receives only a configured validated IP.
        ip = str(ipaddress.ip_address(ip))
        p=subprocess.run(PROBE_COMMAND + [ip],capture_output=True,timeout=6,check=True)
        result=parse_pong(p.stdout.decode(errors='replace'),ip)
        if result['kind']=='direct':
            try: context=route_context(endpoint_ip(result['endpoint']))
            except (OSError,ValueError,RuntimeError,subprocess.TimeoutExpired): context=None
            if isinstance(context,dict):
                classified=classify_peer({'online':True,'active':True,'endpoint':result['endpoint'],
                                          'lanRouteDirect':context.get('direct') is True},context.get('prefixes',[]),time.time()-APPLE_EPOCH)
                result['kind']=classified['kind']
        return {'ok':True,'observedAt':time.time()-APPLE_EPOCH,**result}
    except subprocess.TimeoutExpired:return {'ok':False,'observedAt':time.time()-APPLE_EPOCH,'error':'probe_timeout'}
    except (OSError,ValueError,RuntimeError,subprocess.CalledProcessError,json.JSONDecodeError):
        return {'ok':False,'observedAt':time.time()-APPLE_EPOCH,'error':'probe_unconfirmed'}


class PathProbeCache:
    def __init__(self,probe=probe_peer,clock=None):
        self.probe=probe;self.clock=clock or (lambda:time.time()-APPLE_EPOCH)
        self.lock=threading.Lock();self.attempts={};self.results={};self.running=False
    def refresh(self,links):
        now=self.clock()
        with self.lock:
            if self.running:return
            # Exactly these two peers get an initial baseline and, once started,
            # one measurement at most every 30s, even if the probe made them active.
            eligible=[key for key in PEERS if links.get(key,{}).get('online') is True
                      and now-self.attempts.get(key,float('-inf'))>=PROBE_INTERVAL]
            if not eligible:return
            self.running=True
        threading.Thread(target=self._run,args=(eligible,),daemon=True,name='bounded-gateway-path-probe').start()
    def _run(self,keys):
        try:
            for key in keys:
                with self.lock:self.attempts[key]=self.clock()
                result=self.probe(key)
                with self.lock:self.results[key]=result
        finally:
            with self.lock:self.running=False
    def overlay(self,links):
        now=self.clock();result=copy.deepcopy(links)
        with self.lock:measurements=copy.deepcopy(self.results);attempts=dict(self.attempts)
        for key in PEERS:
            link=result.get(key)
            if not isinstance(link,dict) or link.get('online') is not True:continue
            passive=link.get('kind','unknown');link['passiveKind']=passive
            measurement=measurements.get(key)
            if measurement and not measurement.get('ok'):
                link.update(kind='unknown',pathObservedAt=measurement.get('observedAt'),
                            pathMaxAgeSeconds=PROBE_MAX_AGE,pathProbeState='failed')
                continue
            if passive not in ('idle','unknown'):
                link['evidenceType']='passive'
                # A status read is not a new probe. Attach a measurement timestamp
                # only when a still-valid real probe agrees with this exact path.
                if measurement and measurement.get('ok') and 0<=now-measurement.get('observedAt',0)<PROBE_MAX_AGE:
                    same=(measurement.get('kind')==passive and
                          measurement.get('endpoint')==link.get('endpoint') and
                          measurement.get('relay')==link.get('relay'))
                    if same:
                        link.update(pathObservedAt=measurement['observedAt'],pathMaxAgeSeconds=PROBE_MAX_AGE,
                                    latencyMs=measurement.get('latencyMs'),evidenceType='probe',pathProbeState='confirmed')
                continue
            link['kind']='unknown'
            if not measurement:
                link['pathProbeState']='pending';continue
            age=now-measurement.get('observedAt',0)
            link['pathObservedAt']=measurement.get('observedAt')
            link['pathMaxAgeSeconds']=PROBE_MAX_AGE
            if not measurement.get('ok'):
                link['pathProbeState']='failed';continue
            if not 0<=age<PROBE_MAX_AGE:
                link['pathProbeState']='expired';continue
            for field in ('kind','endpoint','relay','transportVersion','latencyMs'):
                if field in measurement:link[field]=measurement[field]
            link['evidenceType']='probe';link['pathProbeState']='confirmed'
            link['source']='gateway-tailscale-status+bounded-probe'
        return result
