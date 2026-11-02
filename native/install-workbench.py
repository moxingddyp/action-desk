#!/usr/bin/env python3
"""Upgrade an existing public OSS workbench and reconcile its running widgets.

For first installation, copy the app into Applications using the installation guide.

Without --apply this only validates. A changed build requires a new backup
directory. Identical artifacts still run the mandatory widget reconciliation.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import signal
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
APP = Path('/Applications/CXY Workbench OSS.app')
SOURCE = Path('/tmp/CXY-Workbench-OSS-Build/CXY Workbench OSS.app')
EXTENSIONS = {'CXYActionWidget.appex': 'local.cxy.actiondesk.opensource.widget',
              'CXYDeviceWidget.appex': 'local.cxy.actiondesk.opensource.deviceswidget'}


def run(args):
    return subprocess.run([str(a) for a in args], capture_output=True,
                          text=True, check=True, timeout=30)


def validate(app):
    run(['/usr/bin/codesign', '--verify', '--deep', '--strict', app])
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    if info['CFBundleIdentifier'] != 'local.cxy.actiondesk.opensource':
        raise RuntimeError('Unexpected host identity')
    for name, identity in EXTENSIONS.items():
        root = app / 'Contents/PlugIns' / name
        data = plistlib.loads((root / 'Contents/Info.plist').read_bytes())
        if data['CFBundleIdentifier'] != identity or data['CFBundleVersion'] != info['CFBundleVersion']:
            raise RuntimeError('Host and extension identity/version differ')
        if not (root / 'Contents/Resources/Metadata.appintents/extract.actionsdata').is_file():
            raise RuntimeError('Missing AppIntents metadata')
    return info['CFBundleVersion']


def digest(app):
    h = hashlib.sha256()
    for p in sorted(app.rglob('*')):
        if p.is_symlink():
            h.update(str(p.relative_to(app)).encode()); h.update(os.readlink(p).encode())
        elif p.is_file():
            h.update(str(p.relative_to(app)).encode()); h.update(p.read_bytes())
    return h.hexdigest()


def stop_host():
    executable = str(APP / 'Contents/MacOS/CXYActionDesk')
    pids = []
    for row in run(['/bin/ps', '-axo', 'pid=,uid=,comm=']).stdout.splitlines():
        parts = row.split(None, 2)
        if len(parts) == 3 and parts[1:] == [str(os.getuid()), executable]:
            pid = int(parts[0])
            # Recheck exact ownership/path before signalling; no broad process kill.
            live = run(['/bin/ps', '-p', pid, '-o', 'uid=,comm=']).stdout.strip().split(None, 1)
            if live != [str(os.getuid()), executable]:
                raise RuntimeError('Host identity changed during installation')
            os.kill(pid, signal.SIGTERM); pids.append(pid)
    for _ in range(50):
        if not any(subprocess.run(['/bin/kill', '-0', str(pid)], capture_output=True).returncode == 0 for pid in pids):
            return pids
        time.sleep(.1)
    raise RuntimeError('Host did not stop; installed App not replaced')


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--source', type=Path, default=SOURCE)
    ap.add_argument('--backup-dir', type=Path)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--apply', action='store_true')
    a = ap.parse_args(); os.umask(0o077)
    source = a.source.resolve()
    build = validate(source); previous = validate(APP)
    fingerprint = digest(source); changed = fingerprint != digest(APP)
    report = dict(build=build, previousBuild=previous, replacementRequired=changed,
                  applied=False, networkChanged=False, preferencesChanged=False)
    a.output.parent.mkdir(parents=True, exist_ok=True)
    def save():
        a.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    save()
    if not a.apply:
        print(json.dumps(report, ensure_ascii=False)); return
    try:
        if changed:
            if not a.backup_dir or not a.backup_dir.is_absolute():
                raise RuntimeError('Replacement requires an absolute new --backup-dir')
            backup = a.backup_dir
            backup.mkdir(mode=0o700, parents=True, exist_ok=False)
            # Preserve a complete, verified copy before changing the installed App.
            run(['/usr/bin/ditto', APP, backup / 'CXY Workbench OSS.app'])
            if digest(backup / 'CXY Workbench OSS.app') != digest(APP):
                raise RuntimeError('Backup verification failed')
            report['backup'] = str(backup / 'CXY Workbench OSS.app'); save()
            report['stoppedHostPIDs'] = stop_host()
            run(['/usr/bin/ditto', source, APP])
            if validate(APP) != build or digest(APP) != fingerprint:
                raise RuntimeError('Installed artifact verification failed; use saved backup')
        # Mandatory even when a prior installer already copied this same build.
        repair = a.output.with_name(a.output.stem + '-widgets.json')
        run([sys.executable, HERE / 'refresh-installed-widgets.py', '--apply', '--output', repair])
        report['widgetReceipt'] = str(repair)
        if changed:
            run(['/usr/bin/open', '-g', '-a', APP, '--args', '--background'])
        expected = {p['identity'] for p in json.loads(repair.read_text())['before']['processes']}
        readback = a.output.with_name(a.output.stem + '-widgets-readback.json')
        for attempt in range(8):
            run([sys.executable, HERE / 'refresh-installed-widgets.py', '--output', readback])
            processes = json.loads(readback.read_text())['before']['processes']
            if not any(p['stale'] for p in processes) and expected <= {p['identity'] for p in processes}:
                break
            if attempt == 7:
                raise RuntimeError('Updated widget processes not confirmed; inspect readback')
            time.sleep(.5)
        report['widgetReadback'] = str(readback)
        report.update(applied=True, complete=True)
        save(); print(json.dumps(report, ensure_ascii=False))
    except Exception as error:
        report.update(complete=False, error=str(error)); save()
        raise


if __name__ == '__main__':
    main()
