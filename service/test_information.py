import json
from pathlib import Path
import tempfile
import threading
import unittest
import urllib.request
import urllib.error
from server import Handler, Service, Store

class InformationRead(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.server=Service(('127.0.0.1',0),Handler)
        self.server.store=Store(self.tmp.name)
        self.server.config={'readToken':'test-read-token'}
        self.thread=threading.Thread(target=self.server.serve_forever,daemon=True);self.thread.start()
    def tearDown(self):
        self.server.shutdown();self.server.server_close();self.thread.join();self.tmp.cleanup()
    def get(self,token='test-read-token'):
        request=urllib.request.Request('http://127.0.0.1:'+str(self.server.server_port)+'/v1/information',headers={'Authorization':'Bearer '+token})
        try:
            with urllib.request.urlopen(request) as response:return response.status,json.load(response)
        except urllib.error.HTTPError as error:return error.code,json.load(error)
    def test_requires_reader_role(self):self.assertEqual(self.get('wrong')[0],401)
    def test_unpublished_is_explicit(self):self.assertEqual(self.get()[0],404)
    def test_preserves_long_text_links_and_dates(self):
        report={'title':'日报','highlights':[{'summary':'长文\n\n'+('上下文'*1000),'sources':['https://example.org/paper'],'publishedAt':'2026-11-01'}]}
        Path(self.tmp.name,'information.json').write_text(json.dumps(report))
        self.assertEqual(self.get(),(200,report))
    def test_invalid_and_oversize_fail_visibly(self):
        target=Path(self.tmp.name,'information.json');target.write_text('{')
        self.assertEqual(self.get()[0],503)
        target.write_bytes(b' '*2000001);self.assertEqual(self.get()[0],503)
