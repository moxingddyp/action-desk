import copy
import unittest
from private_links import classify_peer, apply_links


class PrivateLinks(unittest.TestCase):
    def peer(self, **changes):
        p={'online':True,'active':True,'endpoint':'198.51.100.168:41642','relay':'hkg','peerRelay':'','lanRouteDirect':True,'rxBytes':200,'txBytes':100,'tailnetAddress':'198.51.100.11'}
        p.update(changes);return p
    def test_direct_wins_over_relay_metadata(self):
        v=classify_peer(self.peer(),['198.51.100.3/24'],100)
        self.assertEqual(v['kind'],'lan-direct');self.assertNotIn('relay',v);self.assertEqual(v['tailnetAddress'],'198.51.100.11')
    def test_private_ip_is_not_enough_for_lan(self):
        self.assertEqual(classify_peer(self.peer(endpoint='203.0.113.5:41642'),['198.51.100.3/24'],100)['kind'],'direct')
        self.assertEqual(classify_peer(self.peer(lanRouteDirect=False),['198.51.100.3/24'],100)['kind'],'direct')
    def test_ipv6_requires_prefix_and_route(self):
        p=self.peer(endpoint='[2001:db8::1234]:41642')
        self.assertEqual(classify_peer(p,[],100)['kind'],'direct')
        v=classify_peer(p,['2001:db8::1/64'],100)
        self.assertEqual(v['kind'],'lan-direct');self.assertEqual(v['transportVersion'],'IPv6')
    def test_idle_online_is_not_offline(self):
        v=classify_peer(self.peer(active=False),[],100)
        self.assertEqual(v['kind'],'idle');self.assertTrue(v['online'])
    def test_offline_is_not_direct(self):
        self.assertEqual(classify_peer(self.peer(online=False),[],100)['kind'],'offline')
    def test_peer_relay_before_derp(self):
        self.assertEqual(classify_peer(self.peer(endpoint='',peerRelay='203.0.113.1:7777:vni:1'),[],100)['kind'],'peer-relay')
        self.assertEqual(classify_peer(self.peer(endpoint=''),[],100)['kind'],'derp')
    def test_unknown_if_status_not_read(self):
        self.assertEqual(classify_peer({},[],100)['kind'],'unknown')
    def test_gateway_rates(self):
        v=classify_peer(self.peer(),[],102,{'rxBytes':100,'txBytes':50,'observedAt':100})
        self.assertEqual(v['gatewayRxBytesPerSecond'],50)
        self.assertEqual(v['gatewayTxBytesPerSecond'],25)
    def test_reset_counter_not_negative(self):
        v=classify_peer(self.peer(),[],102,{'rxBytes':9999,'txBytes':9999,'observedAt':100})
        self.assertNotIn('gatewayRxBytesPerSecond',v)
    def test_stale_link_not_refreshed_by_mac_upload(self):
        link=classify_peer(self.peer(),['198.51.100.3/24'],90)
        samples=[{'id':'mac','receivedAt':100},{'id':'winpc','receivedAt':100},{'id':'linux','receivedAt':100,'privateLinks':{'mac':link,'phone':link}}]
        d,p=apply_links(samples,100)
        self.assertEqual(d[0]['privateLink']['kind'],'unknown')
        self.assertEqual(d[0]['privateLink']['observedAt'],90)
        self.assertEqual(p['privateLink']['kind'],'unknown')
        self.assertNotIn('cpu',p)
        self.assertEqual(len(d),3)
        self.assertIn('privateLinks',samples[2])
    def test_sampler_stale_invalidates_links(self):
        link=classify_peer(self.peer(),['198.51.100.3/24'],99)
        d,p=apply_links([{'id':'mac','receivedAt':100},{'id':'linux','receivedAt':90,'privateLinks':{'mac':link,'phone':link}}],100)
        self.assertEqual(d[0]['privateLink']['kind'],'unknown');self.assertIn('issue',p)

if __name__=='__main__':unittest.main()
