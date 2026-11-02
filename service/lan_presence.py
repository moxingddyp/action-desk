"""Current household-LAN evidence; no probes or network mutations."""
from service_config import load_config
import ipaddress
import json
from pathlib import Path
import subprocess
import time
from private_links import endpoint_ip

APPLE_EPOCH = 978307200
TARGET = '家庭局域网'
PEER_ADDRESSES = load_config().get('linux', {}).get('peerAddresses', {})


def unknown_lan(now, source='lan-observation-unavailable'):
    return {'state':'unknown','target':TARGET,'observedAt':now,'source':source}


def fresh_lan(link, now):
    if not isinstance(link,dict): return unknown_lan(now)
    result=dict(link)
    if not isinstance(result.get('observedAt'),(int,float)) or not 0 <= now-result['observedAt'] < 5:
        result['state']='unknown'
    return result


class TrafficEvidence:
    """RX growth must use the same verified LAN endpoint on both observations."""
    def __init__(self): self.previous={}; self.confirmed={}
    def observe(self, key, peer, direct_lan, now):
        result=unknown_lan(now, 'linux-tailscale-rx-and-home-route')
        old=self.previous.get(key)
        endpoint=peer.get('CurAddr','') if isinstance(peer,dict) else ''
        rx=peer.get('RxBytes') if isinstance(peer,dict) else None
        active=isinstance(peer,dict) and peer.get('Online') is True and peer.get('Active') is True
        eligible=active and direct_lan and endpoint_ip(endpoint) is not None and isinstance(rx,int) and not isinstance(rx,bool) and rx>=0
        if not eligible or not old or old['endpoint']!=endpoint or not old['eligible'] or rx<old['rx']:
            self.confirmed.pop(key,None)
        elif 0 < now-old['at'] <= 5 and rx>old['rx']:
            self.confirmed[key]={'state':'online','target':TARGET,'observedAt':now,'source':'linux-tailscale-rx-and-home-route',
                                 'address':str(endpoint_ip(endpoint))}
        self.previous[key]={'endpoint':endpoint,'rx':rx if eligible else 0,'at':now,'eligible':eligible}
        proof=self.confirmed.get(key)
        if proof and 0<=now-proof['observedAt']<5:return dict(proof)
        return result


def command_json(args):
    p=subprocess.run(args,capture_output=True,text=True,timeout=1.5,check=True)
    return json.loads(p.stdout)


class HomeLANObserver:
    def __init__(self, interface=None, windows_alias=None):
        self.interface=interface
        self.traffic=TrafficEvidence()
        self.windows_address=None
        try:
            if not windows_alias: return
            p=subprocess.run(['ssh','-G',windows_alias],capture_output=True,text=True,timeout=2,check=True)
            options=dict(line.split(' ',1) for line in p.stdout.splitlines() if ' ' in line)
            if options.get('proxycommand','none')=='none' and options.get('proxyjump','none')=='none':
                self.windows_address=ipaddress.ip_address(options['hostname'])
        except (OSError,ValueError,KeyError,subprocess.SubprocessError):pass

    def snapshot(self):
        now=time.time()-APPLE_EPOCH
        values={key:unknown_lan(now) for key in ('mac','phone','winpc','linux')}
        try:
            if not self.interface: return values
            base=Path('/sys/class/net')/self.interface
            index=int((base/'ifindex').read_text())
            carrier=(base/'carrier').read_text().strip()=='1'
            interfaces=set()
            for p in base.parent.iterdir():
                try:
                    if p.name==self.interface or int((p/'iflink').read_text())==index:interfaces.add(p.name)
                except (OSError,ValueError):pass
            addresses=command_json(['ip','-j','address','show'])
            prefixes=[]; own=None
            for interface in addresses:
                if interface.get('ifname') not in interfaces:continue
                for a in interface.get('addr_info',[]):
                    if a.get('scope')!='global':continue
                    address=ipaddress.ip_address(a['local'])
                    prefixes.append(ipaddress.ip_network(str(address)+'/'+str(a['prefixlen']),strict=False))
                    if interface.get('ifname')==self.interface and address.version==4:own=str(address)
            if not prefixes:raise ValueError('no_home_lan_prefix')
            values['linux']={'state':'online' if carrier else 'offline','target':TARGET,'observedAt':now,'source':'linux-home-interface-carrier'}
            if own:values['linux']['address']=own
            def direct(address):
                if not carrier or address is None or not any(address.version==p.version and address in p for p in prefixes):return False
                try:
                    route=command_json(['ip']+(['-6'] if address.version==6 else [])+['-j','route','get',str(address)])
                    return bool(route) and route[0].get('dev') in interfaces and not route[0].get('gateway')
                except (OSError, ValueError, subprocess.SubprocessError): return False
            if direct(self.windows_address):
                values['winpc']={'state':'unknown','target':TARGET,'observedAt':now,'source':'linux-verified-lan-ssh',
                                  'address':str(self.windows_address),'requiresFreshSample':True}
            try: status=command_json(['tailscale','status','--json'])
            except (OSError,ValueError,subprocess.SubprocessError): status={}
            peers={address:peer for peer in status.get('Peer',{}).values() for address in peer.get('TailscaleIPs',[])}
            for key,address in PEER_ADDRESSES.items():
                peer=peers.get(address,{})
                candidate=endpoint_ip(peer.get('CurAddr',''))
                values[key]=self.traffic.observe(key,peer,direct(candidate),now)
        except (OSError,ValueError,KeyError,TypeError,subprocess.SubprocessError):
            # Missing current evidence invalidates old positive observations.
            self.traffic.previous.clear();self.traffic.confirmed.clear()
            values={key:unknown_lan(now) for key in values}
        return values
