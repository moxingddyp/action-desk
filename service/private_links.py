"""Read-only gateway-to-device path classification; never trigger peer probes."""
import copy
import ipaddress
import math
import time

APPLE_EPOCH = 978307200
TARGET = '家庭网关'
PEERS = {'mac': 'mac', 'phone': 'phone'}


def endpoint_ip(endpoint):
    if not isinstance(endpoint, str) or not endpoint: return None
    try:
        if endpoint.startswith('['): address = endpoint[1:endpoint.index(']')]
        else: address = endpoint.rsplit(':', 1)[0]
        return ipaddress.ip_address(address.split('%')[0])
    except (ValueError, IndexError): return None


def classify_peer(peer, lan_prefixes, observed_at, previous=None):
    result = {'kind': 'unknown', 'target': TARGET, 'observedAt': observed_at,
              'source': 'gateway-tailscale-status'}
    if not isinstance(peer, dict) or not isinstance(peer.get('online'), bool) or not isinstance(peer.get('active'), bool):
        return result
    online, active = peer['online'], peer['active']
    result.update(online=online, active=active)
    try:
        address = ipaddress.ip_address(peer.get('tailnetAddress', ''))
        if address.version == 4: result['tailnetAddress'] = str(address)
    except ValueError: pass
    endpoint = peer.get('endpoint', '')
    address = endpoint_ip(endpoint)
    if not online: result['kind'] = 'offline'
    elif not active: result['kind'] = 'idle'
    elif address is not None:
        result.update(kind='direct', endpoint=endpoint, transportVersion='IPv4' if address.version == 4 else 'IPv6')
        networks = []
        for prefix in lan_prefixes:
            try: networks.append(ipaddress.ip_network(prefix, strict=False))
            except (ValueError, TypeError): pass
        if peer.get('lanRouteDirect') is True and any(address.version == n.version and address in n for n in networks):
            result['kind'] = 'lan-direct'
    elif peer.get('peerRelay'):
        result.update(kind='peer-relay', relay=peer['peerRelay'])
    elif peer.get('relay'):
        result.update(kind='derp', relay=peer['relay'])
    if previous:
        elapsed = observed_at - previous.get('observedAt', observed_at)
        if .1 <= elapsed <= 10:
            for source, target in [('rxBytes','gatewayRxBytesPerSecond'),('txBytes','gatewayTxBytesPerSecond')]:
                value, old = peer.get(source), previous.get(source)
                if isinstance(value, (int,float)) and isinstance(old, (int,float)) and value >= old:
                    rate=(value-old)/elapsed
                    if math.isfinite(rate): result[target]=rate
    return result


def unknown_link(observed_at=None):
    return {'kind':'unknown','target':TARGET,'observedAt':time.time()-APPLE_EPOCH if observed_at is None else observed_at,
            'source':'gateway-tailscale-status'}


def apply_links(devices, now):
    """Return metric devices plus separate phone network-only record."""
    devices = copy.deepcopy(devices)
    linux = next((x for x in devices if x.get('id')=='linux'), {})
    linux.pop('lanLinks', None)
    linux.pop('gatewayStatus', None)
    links = linux.pop('privateLinks', {})
    linux_fresh = not linux.get('issue') and not linux.get('error') and now-linux.get('receivedAt',0)<5
    def current(key):
        link=links.get(key)
        if not linux_fresh or not isinstance(link,dict): return unknown_link(now)
        if now-link.get('observedAt',0)>=5: return unknown_link(link.get('observedAt',now))
        return link
    for sample in devices:
        if sample.get('id') in ('mac','winpc','linux'): sample['privateLink']=current(sample['id'])
    phone_link=current('phone')
    phone={'id':'phone','host':'phone','receivedAt':phone_link['observedAt'],'privateLink':phone_link}
    if phone_link['kind']=='unknown': phone['issue']='私网路径未取得或已过期'
    elif phone_link['kind']=='offline': phone['issue']='手机私网离线'
    return devices, phone
