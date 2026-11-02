import copy
import tempfile
import unittest
from unittest.mock import patch
from lan_presence import TrafficEvidence, fresh_lan, unknown_lan
from server import Store


def peer(endpoint='198.51.100.168:41642',rx=100,active=True,online=True):
    return {'CurAddr':endpoint,'RxBytes':rx,'Active':active,'Online':online}


class LANPresence(unittest.TestCase):
    def test_first_packet_no_invented_confirmation(self):
        observer=TrafficEvidence()
        self.assertEqual(observer.observe('phone',peer(),True,100)['state'],'unknown')
        self.assertEqual(observer.observe('phone',peer(rx=200),True,101)['state'],'online')
    def test_same_endpoint_same_lan_proof_required(self):
        observer=TrafficEvidence();observer.observe('phone',peer(),True,100)
        self.assertEqual(observer.observe('phone',peer(endpoint='198.51.100.169:41642',rx=200),True,101)['state'],'unknown')
        self.assertEqual(observer.observe('phone',peer(endpoint='198.51.100.169:41642',rx=300),True,102)['state'],'online')
        self.assertEqual(observer.observe('phone',peer(endpoint='203.0.113.1:41642',rx=400),False,103)['state'],'unknown')
    def test_no_traffic_expires_even_if_active_and_neighbor_stale(self):
        observer=TrafficEvidence();observer.observe('phone',peer(),True,100)
        observer.observe('phone',peer(rx=200),True,101)
        self.assertEqual(observer.observe('phone',peer(rx=200),True,104)['state'],'online')
        self.assertEqual(observer.observe('phone',peer(rx=200),True,106)['state'],'unknown')
    def test_counter_reset_discards_positive(self):
        observer=TrafficEvidence();observer.observe('mac',peer(),True,100);observer.observe('mac',peer(rx=200),True,101)
        self.assertEqual(observer.observe('mac',peer(rx=1),True,102)['state'],'unknown')
    def test_route_loss_or_offline_discards_positive(self):
        observer=TrafficEvidence();observer.observe('mac',peer(),True,100);observer.observe('mac',peer(rx=200),True,101)
        self.assertEqual(observer.observe('mac',peer(rx=300),False,102)['state'],'unknown')
        self.assertEqual(observer.observe('mac',peer(rx=400,online=False),True,103)['state'],'unknown')
    def test_expired_lan_does_not_change_private_online(self):
        link={'state':'online','target':'家庭局域网','observedAt':90,'source':'test'}
        self.assertEqual(fresh_lan(link,100)['state'],'unknown');self.assertEqual(link['state'],'online')
    def test_pc_lan_requires_fresh_actual_ssh_sample(self):
        with tempfile.TemporaryDirectory() as path:
            store=Store(path)
            store.accept_sample({'id':'linux','host':'linux','lanLinks':{'winpc':{'state':'unknown','target':'家庭局域网','observedAt':100,'source':'linux-verified-lan-ssh','requiresFreshSample':True}}},'linux')
            store.samples['linux']['receivedAt']=100
            store.accept_sample({'id':'winpc','host':'pc'},'winpc');store.samples['winpc']['receivedAt']=100
            with patch('server.apple_now',return_value=101):
                result=store.telemetry();self.assertEqual(result['devices'][1]['lanLink']['state'],'online')
            store.samples['winpc']['receivedAt']=90
            with patch('server.apple_now',return_value=101):self.assertEqual(store.telemetry()['devices'][1]['lanLink']['state'],'unknown')
    def test_no_linux_observation_does_not_borrow_phone_hardware(self):
        with tempfile.TemporaryDirectory() as path:
            store=Store(path);store.accept_sample({'id':'phone','host':'model','networkType':'wifi'},'phone')
            result=store.telemetry()
            self.assertTrue(result['phone']['hardwareFresh']);self.assertEqual(result['phone']['lanLink']['state'],'unknown')
            self.assertNotIn('online',result['gateway']['privateLink'])

if __name__=='__main__':unittest.main()
