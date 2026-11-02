#!/usr/bin/env python3
"""Repair stale workbench widget binaries after a signed app replacement.

Only the installed workbench's two extensions are eligible. Does not reset
WidgetKit/LaunchServices globally, remove widgets, restart the host or networking.
"""
import argparse
import datetime
import json
import os
from pathlib import Path
import plistlib
import signal
import subprocess

APP = Path('/Applications/CXY Workbench OSS.app')
EXTENSIONS = {'CXYActionWidget.appex': 'local.cxy.actiondesk.opensource.widget',
              'CXYDeviceWidget.appex': 'local.cxy.actiondesk.opensource.deviceswidget'}
LSREGISTER = '/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'


def run(args, check=True):
    return subprocess.run(args, capture_output=True, text=True, check=check, timeout=20)


def inspect():
    host = plistlib.loads((APP/'Contents/Info.plist').read_bytes())
    if host['CFBundleIdentifier'] != 'local.cxy.actiondesk.opensource':
        raise RuntimeError('Unexpected installed host identity')
    run(['/usr/bin/codesign', '--verify', '--deep', '--strict', str(APP)])
    processes = []
    rows = run(['/bin/ps', '-axo', 'pid=,uid=,comm=']).stdout.splitlines()
    packages = []
    for name, identity in EXTENSIONS.items():
        package = APP/'Contents/PlugIns'/name
        info = plistlib.loads((package/'Contents/Info.plist').read_bytes())
        if info['CFBundleIdentifier'] != identity or info['CFBundleVersion'] != host['CFBundleVersion']:
            raise RuntimeError('Host and installed extension version/identity differ')
        executable = package/'Contents/MacOS'/info['CFBundleExecutable']
        inode = executable.stat().st_ino
        packages.append(dict(path=str(package), identity=identity, build=info['CFBundleVersion'], inode=inode))
        for line in rows:
            cells = line.split(None, 2)
            if len(cells) != 3 or cells[1] != str(os.getuid()) or cells[2] != str(executable):
                continue
            pid = int(cells[0]); loaded = None; current_inode = None
            for field in run(['/usr/sbin/lsof', '-a', '-p', str(pid), '-d', 'txt', '-Fin'], check=False).stdout.splitlines():
                if field.startswith('f'): current_inode = None
                elif field.startswith('i'): current_inode = int(field[1:])
                elif field == 'n' + str(executable): loaded = current_inode
            if loaded is None:
                raise RuntimeError('Cannot establish loaded widget inode: '+str(pid))
            processes.append(dict(pid=pid, executable=str(executable), identity=identity,
                                  loadedInode=loaded, installedInode=inode, stale=loaded != inode))
    return dict(hostBuild=host['CFBundleVersion'], packages=packages, processes=processes)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    os.umask(0o077)
    report = dict(at=datetime.datetime.now(datetime.timezone.utc).isoformat(), before=inspect(), applied=False)
    output = Path(args.output); output.parent.mkdir(parents=True, exist_ok=True)
    def save(): output.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
    save()
    if args.apply:
        run([LSREGISTER, '-f', str(APP)])
        for package in report['before']['packages']:
            run(['/usr/bin/pluginkit', '-a', package['path']])
        retired=[]
        for process in report['before']['processes']:
            if not process['stale']: continue
            # Check ownership/path again so a recycled PID cannot be targeted.
            row=run(['/bin/ps','-p',str(process['pid']),'-o','uid=,comm='],check=False).stdout.strip().split(None,1)
            if row != [str(os.getuid()), process['executable']]:
                raise RuntimeError('Widget process changed during inspection')
            os.kill(process['pid'], signal.SIGTERM); retired.append(process['pid'])
        report.update(applied=True, retiredStalePIDs=retired,
                      hostRestarted=False, systemServicesRestarted=False, widgetPlacementChanged=False,
                      networkChanged=False)
        save()
        run(['/usr/bin/open','-g','-a',str(APP),'cxy-actiondesk-oss://widgets-reload','--args','--background'])
    print(json.dumps(report, ensure_ascii=False))

if __name__=='__main__': main()
