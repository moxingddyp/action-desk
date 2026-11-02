import copy
import json
from pathlib import Path
import tempfile
import threading
import unittest
import urllib.request
import urllib.error
from server import Handler, Service, Store, validate_phone, combine_phone


def phone_packet():
    return {'id':'phone','host':'Test Model','batteryPercent':80.5,'batteryCharging':False,'onACPower':True,
            'memoryUsed':100,'memoryTotal':200,'disks':[{'name':'内部存储','total':1000,'used':200}], 'networkType':'wifi'}


def network_packet(kind='lan-direct',observed=100):
    return {'id':'phone','host':'phone','receivedAt':observed,
            'privateLink':{'kind':kind,'target':'家庭网关','observedAt':observed,'online':kind!='offline', 'source':'gateway-tailscale-status'}}


class PhoneValidation(unittest.TestCase):
    def test_fields_and_network_enums(self):
        for network in ('wifi','mobile','ethernet','vpn','none','unknown'):
            self.assertEqual(validate_phone({**phone_packet(),'networkType':network})['networkType'],network)
        validate_phone({'id':'phone','host':'model'})
        for extra in ('privateLink','cpu','gpu','download','upload','receivedAt'):
            with self.subTest(extra=extra):
                with self.assertRaises(ValueError):validate_phone({**phone_packet(),extra:0})
    def test_percent_and_boolean_types(self):
        for value in (-1,101,True,'80',None,float('nan'),float('inf')):
            with self.subTest(value=value):
                with self.assertRaises(ValueError):validate_phone({**phone_packet(),'batteryPercent':value})
        for field in ('batteryCharging','onACPower'):
            for value in (0,1,'false',None):
                with self.subTest(field=field,value=value):
                    with self.assertRaises(ValueError):validate_phone({**phone_packet(),field:value})
    def test_memory_and_disks_bounds(self):
        for changes in ({'memoryUsed':201},{'memoryTotal':-1},{'memoryUsed':False},{'memoryTotal':'200'},
                        {'disks':[{'name':'内部存储','total':100,'used':101}]},
                        {'disks':[{'name':'内部存储','total':float('inf'),'used':100}]},
                        {'disks':[{'name':'内部存储','total':100,'used':True}]},
                        {'disks':[{'name':'内部存储','total':100,'used':1,'token':'no'}]},
                        {'disks':[{'name':'a','total':100,'used':1}]*2},
                        {'networkType':'cellular'},{'host':''},{'host':123},{'id':'mac'}):
            with self.subTest(changes=changes):
                with self.assertRaises(ValueError):validate_phone({**phone_packet(),**changes})
    def test_no_hardware_is_not_network_heartbeat(self):
        merged=combine_phone(network_packet(),None,100)
        self.assertNotIn('receivedAt',merged)
        self.assertFalse(merged['hardwareSampleAvailable']);self.assertFalse(merged['hardwareFresh'])
        self.assertEqual(merged['networkObservedAt'],100)
        self.assertEqual(merged['privateLink']['kind'],'lan-direct')
    def test_network_cannot_freshen_stale_hardware(self):
        hardware={**phone_packet(),'receivedAt':80}
        merged=combine_phone(network_packet(observed=100),hardware,100)
        self.assertEqual(merged['receivedAt'],80);self.assertFalse(merged['hardwareFresh'])
        self.assertIn('hardwareIssue',merged);self.assertEqual(merged['privateLink']['observedAt'],100)
    def test_hardware_cannot_freshen_network(self):
        merged=combine_phone(network_packet('unknown',80),{**phone_packet(),'receivedAt':100},100)
        self.assertTrue(merged['hardwareFresh']);self.assertEqual(merged['privateLink']['kind'],'unknown')
        self.assertEqual(merged['networkObservedAt'],80);self.assertIn('networkIssue',merged)
    def test_role_and_invalid_does_not_replace_last_good(self):
        with tempfile.TemporaryDirectory() as directory:
            store=Store(directory);http=Service(('127.0.0.1',0),Handler);http.store=store
            http.config={'readToken':'read','macToken':'mac','actionsToken':'actions','phoneToken':'phone'}
            threading.Thread(target=http.serve_forever,daemon=True).start()
            base='http://127.0.0.1:'+str(http.server_address[1])
            def request(path,role,data=None):
                req=urllib.request.Request(base+path,data=json.dumps(data).encode() if data is not None else None,
                                           method='PUT' if data is not None else 'GET',headers={'Authorization':'Bearer '+role})
                try:
                    with urllib.request.urlopen(req) as response:return response.status,json.load(response)
                except urllib.error.HTTPError as response:return response.code,json.load(response)
            try:
                for wrong in ('read','mac','actions','wrong'):
                    self.assertEqual(request('/v1/phone',wrong,phone_packet())[0],401)
                self.assertEqual(request('/v1/phone','phone',phone_packet())[0],200)
                self.assertEqual(request('/v1/mac','phone',{'id':'mac','host':'mac'})[0],401)
                self.assertEqual(request('/v1/health','phone')[0],401)
                self.assertEqual(request('/v1/phone','phone',{**phone_packet(),'privateLink':{'kind':'direct'}})[0],400)
                code,data=request('/v1/telemetry','read')
                self.assertEqual(code,200);self.assertEqual(len(data['devices']),3)
                self.assertEqual(data['phone']['batteryPercent'],80.5);self.assertTrue(data['phone']['hardwareFresh'])
                self.assertEqual(data['phone']['privateLink']['kind'],'unknown')
            finally:http.shutdown();http.server_close()

if __name__=='__main__':unittest.main()
