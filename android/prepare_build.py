"""Download official Windows Android build tools after the operator accepts SDK terms."""
import concurrent.futures,hashlib,json,urllib.request,zipfile,os
from pathlib import Path
import xml.etree.ElementTree as E
import argparse
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--runtime',type=Path,required=True)
parser.add_argument('--accept-sdk-license',action='store_true')
args=parser.parse_args()
if not args.accept_sdk_license:parser.error('Read https://developer.android.com/studio/terms and explicitly accept using --accept-sdk-license')
ROOT=args.runtime.resolve();ROOT.mkdir(parents=True,exist_ok=True)
repo=E.fromstring(urllib.request.urlopen('https://dl.google.com/android/repository/repository2-3.xml',timeout=40).read())
jobs=[]
for p in repo.findall('remotePackage'):
 if p.get('path') not in ['platforms;android-36','build-tools;36.0.0']:continue
 for a in p.findall('./archives/archive'):
  if a.findtext('host-os') not in (None,'windows'):continue
  archive=a.find('complete');jobs.append({'url':'https://dl.google.com/android/repository/'+archive.findtext('url'),'sha1':archive.findtext('checksum'),'size':int(archive.findtext('size')),'kind':p.get('path')})
jobs.append({'url':'https://aka.ms/download-jdk/microsoft-jdk-21.0.12.1-windows-x64.zip','kind':'jdk'})
def fetch(j):
 dest=ROOT/j['url'].rsplit('/',1)[1]
 if not dest.exists():
  tmp=dest.with_suffix('.part')
  with urllib.request.urlopen(j['url'],timeout=60) as r,open(tmp,'wb') as out:
   while True:
    b=r.read(1024*1024)
    if not b:break
    out.write(b)
  tmp.rename(dest)
 sha=hashlib.sha256(dest.read_bytes()).hexdigest()
 if 'sha1'in j:assert hashlib.sha1(dest.read_bytes()).hexdigest()==j['sha1']
 if 'size'in j:assert dest.stat().st_size==j['size']
 if j['kind']=='jdk':
  expected=urllib.request.urlopen(j['url']+'.sha256sum.txt',timeout=30).read().decode().split()[0].lower()
  assert sha==expected,(sha,expected)
 with zipfile.ZipFile(dest) as z:
  for n in z.namelist():
   if Path(n).is_absolute() or '..' in Path(n).parts:raise ValueError('unsafe archive')
  z.extractall(ROOT)
 return {'kind':j['kind'],'file':str(dest),'sha256':sha,'bytes':dest.stat().st_size}
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:receipts=list(pool.map(fetch,jobs))
(ROOT/'official-packages.json').write_text(json.dumps({'sdkLicenseAcceptedByOperator':True,'terms':'https://developer.android.com/studio/terms','packages':receipts},indent=2))
print(json.dumps({'prepared':True,'packages':receipts}))
