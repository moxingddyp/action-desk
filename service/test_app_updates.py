import hashlib
import io
import json
from pathlib import Path
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
import zipfile
from app_updates import InvalidRelease, ReleaseUnavailable, ReleaseStore, validate_manifest
from publish_android import publish
from server import Handler, Service, Store


class AppUpdates(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.base=Path(self.tmp.name);self.release=self.base/'releases'
        self.apk=self.base/'input.apk'
        with zipfile.ZipFile(self.apk,'w',zipfile.ZIP_STORED) as z:
            z.writestr('AndroidManifest.xml',b'fixture manifest, not installed')
            z.writestr('classes.dex',bytes(range(256))*512)
        self.meta={'packageName':'com.example.workbench','versionCode':5,'versionName':'1.3.0','certSHA256':'a'*64}
    def tearDown(self):self.tmp.cleanup()
    def test_unpublished_is_explicit(self):
        with self.assertRaises(ReleaseUnavailable):ReleaseStore(self.release).current()
    def test_publish_bytes_hash_and_permissions(self):
        m=publish(self.apk,self.meta,self.release)
        self.assertEqual(m['size'],self.apk.stat().st_size)
        self.assertEqual(m['sha256'],hashlib.sha256(self.apk.read_bytes()).hexdigest())
        self.assertEqual(ReleaseStore(self.release).current(),m)
        self.assertEqual((self.release/'current.json').stat().st_mode&0o777,0o600)
        m2,h=ReleaseStore(self.release).open_download(m['downloadPath'])
        with h:self.assertEqual(h.read(),self.apk.read_bytes())
        self.assertEqual(m2,m)
    def test_wrong_hash_does_not_publish(self):
        with self.assertRaises(InvalidRelease):publish(self.apk,{**self.meta,'sha256':'0'*64},self.release)
        self.assertFalse((self.release/'current.json').exists())
    def test_new_version_keeps_prior_download_and_refuses_downgrade(self):
        m=publish(self.apk,self.meta,self.release)
        newer=publish(self.apk,{**self.meta,'versionCode':6,'versionName':'1.3.1'},self.release)
        self.assertEqual(ReleaseStore(self.release).current(),newer)
        _,h=ReleaseStore(self.release).open_download(m['downloadPath']);h.close()
        with self.assertRaises(InvalidRelease):publish(self.apk,self.meta,self.release)
        self.assertEqual(ReleaseStore(self.release).current(),newer)
    def test_identity_pinned(self):
        old=publish(self.apk,self.meta,self.release)
        for changes in ({'certSHA256':'b'*64},{'packageName':'com.other.workbench'}):
            with self.assertRaises(InvalidRelease):publish(self.apk,{**self.meta,'versionCode':6,**changes},self.release)
        self.assertEqual(ReleaseStore(self.release).current(),old)
    def test_same_version_cannot_replace_content(self):
        old=publish(self.apk,self.meta,self.release)
        with zipfile.ZipFile(self.apk,'a') as z:z.writestr('changed',b'different')
        with self.assertRaises(InvalidRelease):publish(self.apk,self.meta,self.release)
        self.assertEqual(ReleaseStore(self.release).current(),old)
    def test_no_arbitrary_paths_or_symlinks(self):
        m=publish(self.apk,self.meta,self.release);store=ReleaseStore(self.release)
        for path in ('/etc/passwd','/v1/app-updates/android/apk/../../config.json','/v1/app-updates/android/apk/5/'+m['sha256']+'.apk?token=bad',m['downloadPath'].replace(m['sha256'],'0'*64)):
            with self.assertRaises((InvalidRelease,ReleaseUnavailable)):store.open_download(path)
        folder=self.release/('5-'+m['sha256']);(folder/'app.apk').unlink();(folder/'app.apk').symlink_to(self.apk)
        with self.assertRaises(InvalidRelease):store.open_download(m['downloadPath'])
    def test_bad_apk_and_manifest(self):
        self.apk.write_bytes(b'not an APK')
        with self.assertRaises(InvalidRelease):publish(self.apk,self.meta,self.release)
        self.assertFalse((self.release/'current.json').exists())
    def test_http_roles_streaming_and_no_upload(self):
        state=Store(self.base/'state');root=state.directory/'app-releases/android'
        http=Service(('127.0.0.1',0),Handler);http.store=state
        http.config={'readToken':'read','macToken':'mac','phoneToken':'phone','actionsToken':'actions'}
        threading.Thread(target=http.serve_forever,daemon=True).start()
        base='http://127.0.0.1:'+str(http.server_address[1])
        def req(path,token,method='GET'):
            r=urllib.request.Request(base+path,method=method,headers={'Authorization':'Bearer '+token})
            try:
                with urllib.request.urlopen(r) as x:return x.status,dict(x.headers),x.read()
            except urllib.error.HTTPError as x:return x.code,dict(x.headers),x.read()
        try:
            status,_,body=req('/v1/app-updates/android','read');self.assertEqual(status,404)
            self.assertEqual(json.loads(body)['error'],'android_release_unavailable')
            m=publish(self.apk,self.meta,root)
            for role in ('wrong','phone','mac','actions'):
                self.assertEqual(req('/v1/app-updates/android',role)[0],401)
                self.assertEqual(req(m['downloadPath'],role)[0],401)
            status,_,body=req('/v1/app-updates/android','read');self.assertEqual(status,200);self.assertEqual(json.loads(body),m)
            status,headers,body=req(m['downloadPath'],'read');self.assertEqual(status,200)
            self.assertEqual(headers['Content-Length'],str(len(body)))
            self.assertEqual(headers['Content-Type'],'application/vnd.android.package-archive')
            self.assertEqual(hashlib.sha256(body).hexdigest(),m['sha256'])
            self.assertEqual(req('/v1/app-updates/android','phone','PUT')[0],404)
        finally:http.shutdown();http.server_close()

if __name__=='__main__':unittest.main()
