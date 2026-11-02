#!/usr/bin/env python3
"""Publish a root-reviewed APK release over existing SSH, no running-service reload."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import tempfile
import zipfile
from app_updates import MAX_APK_BYTES, ReleaseStore, validate_manifest, InvalidRelease, read_small_json, ReleaseUnavailable


def write_atomic(path,value):
    raw=json.dumps(value,ensure_ascii=False,sort_keys=True,indent=2).encode()+b'\n'
    fd,name=tempfile.mkstemp(prefix='.'+path.name+'-',dir=path.parent)
    try:
        os.fchmod(fd,0o600)
        with os.fdopen(fd,'wb') as handle:handle.write(raw);handle.flush();os.fsync(handle.fileno())
        os.replace(name,path)
    finally:
        if os.path.exists(name):os.unlink(name)


def publish(apk,metadata,directory):
    apk=Path(apk);root=Path(directory)
    if apk.is_symlink() or not apk.is_file():raise InvalidRelease('apk_must_be_regular_file')
    root.mkdir(parents=True,exist_ok=True,mode=0o700);root.chmod(0o700)
    lock=os.open(root/'.publish.lock',os.O_CREAT|os.O_RDWR,0o600)
    with os.fdopen(lock,'wb') as lock_handle:
        fcntl.flock(lock_handle,fcntl.LOCK_EX)
        size=apk.stat().st_size
        if not 0<size<=MAX_APK_BYTES:raise InvalidRelease('invalid_apk_size')
        digest=hashlib.sha256()
        stage=Path(tempfile.mkdtemp(prefix='.stage-',dir=root));stage.chmod(0o700)
        try:
            with apk.open('rb') as source,(stage/'app.apk').open('wb') as target:
                os.fchmod(target.fileno(),0o600)
                while True:
                    chunk=source.read(65536)
                    if not chunk:break
                    digest.update(chunk);target.write(chunk)
                target.flush();os.fsync(target.fileno())
            copied=stage/'app.apk';sha=digest.hexdigest()
            if copied.stat().st_size!=size:raise InvalidRelease('apk_changed_during_copy')
            try:
                with zipfile.ZipFile(copied) as archive:
                    if 'AndroidManifest.xml' not in archive.namelist():raise InvalidRelease('missing_android_manifest')
            except zipfile.BadZipFile:raise InvalidRelease('invalid_apk_container')
            allowed={'packageName','versionCode','versionName','certSHA256','sha256','size'}
            if not isinstance(metadata,dict) or not set(metadata)<=allowed:raise InvalidRelease('invalid_publish_metadata')
            if metadata.get('size',size)!=size or metadata.get('sha256',sha)!=sha:raise InvalidRelease('reviewed_apk_hash_mismatch')
            manifest={k:metadata[k] for k in ['packageName','versionCode','versionName','certSHA256']}
            manifest.update(size=size,sha256=sha,downloadPath='/v1/app-updates/android/apk/'+str(manifest['versionCode'])+'/'+sha+'.apk')
            validate_manifest(manifest)
            policy_file=root/'policy.json'
            if policy_file.exists():ReleaseStore(root).verify_policy(manifest)
            current_file=root/'current.json'
            if current_file.exists():
                current=ReleaseStore(root).current()
                if manifest['versionCode']<current['versionCode']:raise InvalidRelease('version_downgrade_forbidden')
                if manifest['versionCode']==current['versionCode'] and manifest!=current:raise InvalidRelease('version_already_used')
            write_atomic(stage/'metadata.json',manifest)
            destination=root/(str(manifest['versionCode'])+'-'+sha)
            if destination.exists():
                if destination.is_symlink() or validate_manifest(read_small_json(destination/'metadata.json'))!=manifest:raise InvalidRelease('release_collision')
                digest_existing=hashlib.sha256((destination/'app.apk').read_bytes()).hexdigest()
                if digest_existing!=sha:raise InvalidRelease('existing_apk_integrity_failure')
                shutil.rmtree(stage)
            else:os.rename(stage,destination)
            if not policy_file.exists():write_atomic(policy_file,{k:manifest[k] for k in ['packageName','certSHA256']})
            write_atomic(current_file,manifest)
            return manifest
        finally:
            if stage.exists():shutil.rmtree(stage)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apk',required=True)
    parser.add_argument('--metadata',required=True,help='Root-verified package/version/certificate metadata; optional expected APK SHA/size')
    parser.add_argument('--release-dir',default=str(Path.home()/'.local/state/workbench/app-releases/android'))
    args=parser.parse_args()
    # APK signer/package identity must have been checked with official Android
    # tooling before preparing this administrator-supplied metadata file.
    manifest=publish(args.apk,json.loads(Path(args.metadata).read_text()),args.release_dir)
    print(json.dumps({'published':True,'metadata':manifest},ensure_ascii=False))

if __name__=='__main__':main()
