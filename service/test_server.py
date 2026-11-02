import copy
import datetime
import hashlib
import json
from pathlib import Path
import tempfile
import threading
import time
import unittest
import urllib.error
import urllib.request
from server import Handler, Service, Store, validate_actions, apple_now, action_view


def snapshot():
    return {'schemaVersion':1,'sourceRevision':'a'*64,'revision':'b'*64,
            'generatedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),
            'groups':[{'name':'正在做','label':'正在做','count':1}],
            'items':[{'id':'0123456789abcdef','tags':['正在做'],'label':'样例','current':'当前','next':'下一步','output':'','deadline':''}],
            'calendarEvents':[]}


class Validation(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(); self.store=Store(self.tmp.name)
    def tearDown(self): self.tmp.cleanup()
    def test_action_atomic_reject(self):
        good=snapshot(); self.store.put_actions(good)
        bad=copy.deepcopy(good);bad['items'].append(bad['items'][0])
        with self.assertRaises(ValueError):self.store.put_actions(bad)
        self.assertEqual(self.store.actions,good)
        self.assertEqual(json.loads(Path(self.tmp.name,'actions.json').read_text()),good)
    def test_old_snapshot_rejected(self):
        good=snapshot();self.store.put_actions(good);bad=copy.deepcopy(good);bad['generatedAt']='2000-01-01T00:00:00Z'
        with self.assertRaises(ValueError):self.store.put_actions(bad)
    def test_group_consistency(self):
        bad=snapshot();bad['groups'][0]['count']=2
        with self.assertRaises(ValueError):validate_actions(bad)
    def test_stale_mac(self):
        self.store.accept_sample({'id':'mac','host':'mac','cpu':20},'mac')
        self.store.samples['mac']['receivedAt']-=13
        self.assertEqual(self.store.telemetry()['devices'][0]['issue'],'采样未更新')
    def test_host_spoof(self):
        with self.assertRaises(ValueError):self.store.accept_sample({'id':'linux','host':'bad'},'mac')
    def test_nan_rejected(self):
        with self.assertRaises(ValueError):self.store.accept_sample({'id':'mac','cpu':float('nan')},'mac')
    def test_apple_epoch(self):self.assertLess(abs(apple_now()+978307200-time.time()),1)
    def test_offline_activity_expiry(self):
        good=snapshot();good['activityEvidence']={'0123456789abcdef':{'lastProgress':'2026-10-28T12:00:00+08:00','executionState':'未执行'}}
        now=datetime.datetime.fromisoformat('2026-10-31T12:00:00+08:00')
        derived=action_view(good,now)
        self.assertEqual(derived['items'][0]['tags'],['当前可做'])
        self.assertEqual(derived['sourceRevision'],good['sourceRevision'])
        self.assertEqual(good['items'][0]['tags'],['正在做'])
    def test_running_or_unknown_preserved(self):
        good=snapshot();good['activityEvidence']={'0123456789abcdef':{'lastProgress':'','executionState':'执行中'}}
        self.assertEqual(action_view(good)['items'][0]['tags'],['正在做'])
        good['activityEvidence']['0123456789abcdef']['executionState']='未执行'
        self.assertEqual(action_view(good)['items'][0]['tags'],['正在做'])
    def test_blocked_preserved(self):
        good=snapshot();good['items'][0]['tags']=['优先做','条件做'];good['groups']=[{'name':'条件做','count':1}]
        good['activityEvidence']={'0123456789abcdef':{'lastProgress':'2026-10-28T12:00:00+08:00','executionState':'未执行'}}
        self.assertEqual(action_view(good)['items'][0]['tags'],['优先做','条件做'])
    def test_battery_valid_boundaries_and_old_packet(self):
        for battery in (0, 80.5, 100):
            packet={'id':'mac','host':'mac','batteryPercent':battery,'batteryCharging':False,'onACPower':True}
            self.store.accept_sample(packet,'mac')
            self.assertEqual(self.store.samples['mac']['batteryPercent'],battery)
            self.assertFalse(self.store.samples['mac']['batteryCharging'])
            self.assertTrue(self.store.samples['mac']['onACPower'])
        self.store.accept_sample({'id':'mac','host':'mac'},'mac')
        self.assertNotIn('batteryPercent',self.store.samples['mac'])
    def test_battery_invalid_percent_retains_sample(self):
        self.store.accept_sample({'id':'mac','host':'mac','batteryPercent':80},'mac')
        for bad in (-1,101,float('inf'),float('nan'),'80',True,None):
            with self.subTest(value=bad):
                with self.assertRaises(ValueError):self.store.accept_sample({'id':'mac','batteryPercent':bad},'mac')
        self.assertEqual(self.store.samples['mac']['batteryPercent'],80)
    def test_battery_booleans_strict(self):
        for key in ('batteryCharging','onACPower'):
            for bad in (0,1,'true',None):
                with self.subTest(key=key,value=bad):
                    with self.assertRaises(ValueError):self.store.accept_sample({'id':'mac',key:bad},'mac')
    def test_battery_http_role_and_payload(self):
        http=Service(('127.0.0.1',0),Handler);http.store=self.store;http.config={'readToken':'read','macToken':'mac','actionsToken':'actions'}
        threading.Thread(target=http.serve_forever,daemon=True).start()
        url='http://127.0.0.1:'+str(http.server_address[1])+'/v1/mac'
        def put(token,packet):
            req=urllib.request.Request(url,data=json.dumps(packet).encode(),method='PUT',headers={'Authorization':'Bearer '+token})
            try:
                with urllib.request.urlopen(req) as response:return response.status
            except urllib.error.HTTPError as response:return response.code
        packet={'id':'mac','host':'mac','batteryPercent':80,'batteryCharging':False,'onACPower':True}
        try:
            self.assertEqual(put('read',packet),401)
            self.assertEqual(put('actions',packet),401)
            self.assertEqual(put('mac',packet),200)
            self.assertEqual(put('mac',{**packet,'batteryPercent':101}),400)
            self.assertEqual(self.store.samples['mac']['batteryPercent'],80)
        finally:http.shutdown();http.server_close()
    def test_roles_and_hash(self):
        http=Service(('127.0.0.1',0),Handler);http.store=self.store;http.config={'readToken':'read','macToken':'mac','actionsToken':'actions'}
        t=threading.Thread(target=http.serve_forever,daemon=True);t.start()
        url='http://127.0.0.1:'+str(http.server_address[1])
        def req(path,token,data=None,digest=None):
            headers={'Authorization':'Bearer '+token}
            if digest:headers['X-Content-SHA256']=digest
            r=urllib.request.Request(url+path,data=data,headers=headers,method='PUT' if data else 'GET')
            try:
                with urllib.request.urlopen(r) as x:return x.status,json.load(x)
            except urllib.error.HTTPError as e:return e.code,json.load(e)
        try:
            self.assertEqual(req('/v1/health','read')[0],200)
            self.assertEqual(req('/v1/health','wrong')[0],401)
            body=json.dumps(snapshot()).encode()
            self.assertEqual(req('/v1/actions','read',body)[0],401)
            self.assertEqual(req('/v1/actions','actions',body,'0'*64)[0],400)
            self.assertEqual(req('/v1/actions','actions',body,hashlib.sha256(body).hexdigest())[0],200)
        finally:http.shutdown();http.server_close()

if __name__=='__main__':unittest.main()
