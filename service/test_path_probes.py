import path_probes
import copy
import unittest
from unittest.mock import patch
from path_probes import parse_pong, PathProbeCache, probe_peer


class PathProbeTests(unittest.TestCase):
    def setUp(self):
        self.peers = patch.dict(path_probes.PEERS, {'winpc':'198.51.100.20', 'linux':'198.51.100.30'}, clear=True)
        self.peers.start()
        self.addCleanup(self.peers.stop)
    def test_real_cli_direct_ipv6_format(self):
        v=parse_pong('pong from example-pc (198.51.100.20) via [2001:db8::12]:41641 in 1ms\n','198.51.100.20')
        self.assertEqual(v['kind'],'direct');self.assertEqual(v['transportVersion'],'IPv6');self.assertEqual(v['latencyMs'],1)
    def test_derp_and_peer_relay(self):
        v=parse_pong('pong from example-gateway (198.51.100.30) via DERP(hkg) in 34ms','198.51.100.30')
        self.assertEqual(v['kind'],'derp');self.assertEqual(v['relay'],'hkg')
        v=parse_pong('pong from example-gateway (198.51.100.30) via peer-relay(203.0.113.2:7777:vni:1) in 4ms','198.51.100.30')
        self.assertEqual(v['kind'],'peer-relay')
    def test_wrong_peer_or_target_cannot_confirm(self):
        with self.assertRaises(ValueError):parse_pong('pong from other (203.0.113.2) via 198.51.100.1:41641 in 1ms','198.51.100.20')
        with self.assertRaises(ValueError):probe_peer('phone')
        with self.assertRaises(ValueError):parse_pong('anything','203.0.113.1')
    def test_idle_success_has_measured_path_without_fake_active(self):
        cache=PathProbeCache(clock=lambda:110)
        cache.results={'winpc':{'ok':True,'observedAt':100,'kind':'lan-direct','endpoint':'198.51.100.165:41641','transportVersion':'IPv4','latencyMs':1}}
        original={'winpc':{'online':True,'active':False,'kind':'idle','observedAt':110}}
        result=cache.overlay(original)['winpc']
        self.assertEqual(result['kind'],'lan-direct');self.assertFalse(result['active']);self.assertEqual(result['pathObservedAt'],100)
        self.assertEqual(original['winpc']['kind'],'idle')
    def test_expired_or_failed_never_reuses_old_success(self):
        cache=PathProbeCache(clock=lambda:145)
        cache.results={'winpc':{'ok':True,'observedAt':100,'kind':'direct'}}
        base={'winpc':{'online':True,'active':False,'kind':'idle','observedAt':145}}
        result=cache.overlay(base)['winpc'];self.assertEqual(result['kind'],'unknown');self.assertEqual(result['pathProbeState'],'expired')
        cache.results={'winpc':{'ok':False,'observedAt':144,'error':'probe_timeout'}}
        result=cache.overlay(base)['winpc'];self.assertEqual(result['kind'],'unknown');self.assertTrue(result['online']);self.assertEqual(result['pathProbeState'],'failed')
        base['winpc']['kind']='direct'
        self.assertEqual(cache.overlay(base)['winpc']['kind'],'unknown')
    def test_offline_and_real_passive_change_win(self):
        cache=PathProbeCache(clock=lambda:110);cache.results={'winpc':{'ok':True,'observedAt':109,'kind':'direct'}}
        result=cache.overlay({'winpc':{'online':False,'kind':'offline','observedAt':110}})['winpc'];self.assertEqual(result['kind'],'offline')
        result=cache.overlay({'winpc':{'online':True,'active':True,'kind':'derp','relay':'hkg','observedAt':110}})['winpc'];self.assertEqual(result['kind'],'derp');self.assertEqual(result['evidenceType'],'passive');self.assertNotIn('pathObservedAt',result)
    def test_only_two_idle_online_peers_and_interval(self):
        cache=PathProbeCache(clock=lambda:100)
        base={'winpc':{'online':True,'kind':'idle'},'linux':{'online':False,'kind':'direct'},'phone':{'online':True,'kind':'idle'}}
        with patch('path_probes.threading.Thread') as thread:
            cache.refresh(base);thread.assert_called_once();self.assertEqual(thread.call_args.kwargs['args'][0],['winpc'])
        cache.running=False;cache.attempts['winpc']=90
        with patch('path_probes.threading.Thread') as thread:cache.refresh(base);thread.assert_not_called()
    def test_probe_worker_serial_targets(self):
        called=[];cache=PathProbeCache(probe=lambda k:(called.append(k) or {'ok':True,'observedAt':100,'kind':'direct'}),clock=lambda:100)
        cache.running=True;cache._run(['winpc','linux'])
        self.assertEqual(called,['winpc','linux']);self.assertFalse(cache.running);self.assertEqual(cache.attempts,{'winpc':100,'linux':100})

if __name__=='__main__':unittest.main()
