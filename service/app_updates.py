"""Authenticated APK release lookup. Paths are version+SHA mappings, never client filenames."""
import hashlib
import json
import os
from pathlib import Path
import re
import stat

HASH = re.compile(r'[0-9a-f]{64}')
PACKAGE = re.compile(r'[a-zA-Z][a-zA-Z0-9_]*(?:\.[a-zA-Z][a-zA-Z0-9_]*)+')
APK_ROUTE = re.compile(r'/v1/app-updates/android/apk/([1-9][0-9]{0,9})/([0-9a-f]{64})\.apk')
MAX_APK_BYTES = 256 * 1024 * 1024
MANIFEST_FIELDS = {'packageName','versionCode','versionName','size','sha256','certSHA256','downloadPath'}


class ReleaseUnavailable(Exception): pass
class InvalidRelease(Exception): pass


def validate_manifest(value):
    if not isinstance(value,dict) or set(value)!=MANIFEST_FIELDS:raise InvalidRelease('invalid_metadata_fields')
    if not isinstance(value['packageName'],str) or not PACKAGE.fullmatch(value['packageName']):raise InvalidRelease('invalid_package')
    code=value['versionCode']
    if isinstance(code,bool) or not isinstance(code,int) or not 0<code<=2147483647:raise InvalidRelease('invalid_version')
    if not isinstance(value['versionName'],str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9.+_-]{0,99}',value['versionName']):raise InvalidRelease('invalid_version_name')
    if isinstance(value['size'],bool) or not isinstance(value['size'],int) or not 0<value['size']<=MAX_APK_BYTES:raise InvalidRelease('invalid_size')
    for k in ('sha256','certSHA256'):
        if not isinstance(value[k],str) or not HASH.fullmatch(value[k]):raise InvalidRelease('invalid_'+k)
    expected='/v1/app-updates/android/apk/'+str(code)+'/'+value['sha256']+'.apk'
    if value['downloadPath']!=expected:raise InvalidRelease('invalid_download_path')
    return value


def read_small_json(path):
    try:
        if path.is_symlink() or path.stat().st_size>8192:raise InvalidRelease('invalid_metadata_file')
        return json.loads(path.read_text())
    except FileNotFoundError:raise ReleaseUnavailable('android_release_unavailable')
    except (OSError,ValueError):raise InvalidRelease('metadata_unreadable')


class ReleaseStore:
    def __init__(self,directory):self.directory=Path(directory)
    def verify_policy(self,manifest):
        policy=read_small_json(self.directory/'policy.json')
        if not isinstance(policy,dict) or policy.get('packageName')!=manifest['packageName'] or policy.get('certSHA256')!=manifest['certSHA256']:
            raise InvalidRelease('release_identity_mismatch')
    def folder(self,code,digest):
        folder=self.directory/(str(code)+'-'+digest)
        if folder.is_symlink():raise InvalidRelease('symlink_release_forbidden')
        return folder
    def validate_file(self,folder,manifest):
        path=folder/'app.apk'
        try:
            info=path.lstat()
            if not stat.S_ISREG(info.st_mode) or info.st_size!=manifest['size']:raise InvalidRelease('apk_size_or_type_mismatch')
        except FileNotFoundError:raise ReleaseUnavailable('android_apk_unavailable')
        return path
    def current(self):
        manifest=validate_manifest(read_small_json(self.directory/'current.json'))
        self.verify_policy(manifest)
        folder=self.folder(manifest['versionCode'],manifest['sha256'])
        committed=validate_manifest(read_small_json(folder/'metadata.json'))
        if committed!=manifest:raise InvalidRelease('release_commit_mismatch')
        self.validate_file(folder,manifest)
        return manifest
    def open_download(self,path):
        matched=APK_ROUTE.fullmatch(path)
        if not matched:raise ReleaseUnavailable('android_apk_unavailable')
        code=int(matched[1]);digest=matched[2]
        if code>2147483647:raise ReleaseUnavailable('android_apk_unavailable')
        folder=self.folder(code,digest)
        manifest=validate_manifest(read_small_json(folder/'metadata.json'))
        if manifest['versionCode']!=code or manifest['sha256']!=digest:raise InvalidRelease('release_mapping_mismatch')
        self.verify_policy(manifest)
        file=self.validate_file(folder,manifest)
        try:
            fd=os.open(file,os.O_RDONLY|os.O_NOFOLLOW)
            handle=os.fdopen(fd,'rb')
            info=os.fstat(fd)
            if not stat.S_ISREG(info.st_mode) or info.st_size!=manifest['size']:
                handle.close();raise InvalidRelease('apk_changed')
        except FileNotFoundError:raise ReleaseUnavailable('android_apk_unavailable')
        return manifest,handle
