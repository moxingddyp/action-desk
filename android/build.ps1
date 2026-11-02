param(
 [string]$Source=$PSScriptRoot,
 [Parameter(Mandatory=$true)][string]$Runtime,
 [Parameter(Mandatory=$true)][string]$Output,
 [Parameter(Mandatory=$true)][string]$Keystore,
 [Parameter(Mandatory=$true)][string]$PasswordFile,
 [string]$KeyAlias='cxy-workbench',
 [string]$Python='python'
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$jdk=Get-ChildItem -Directory $Runtime | Where-Object {$_.Name -like 'jdk-21*'} | Select-Object -First 1
if(-not $jdk){throw 'Portable JDK missing'}
$env:JAVA_HOME=$jdk.FullName
$env:PATH="$($jdk.FullName)\bin;$env:PATH"
$platform=Get-ChildItem -Recurse -File $Runtime -Filter android.jar | Select-Object -First 1
$tool=Get-ChildItem -Recurse -File $Runtime -Filter aapt2.exe | Select-Object -First 1
if(-not $platform -or -not $tool){throw 'Official Android platform/build-tools missing'}
$bt=$tool.DirectoryName
$build=Join-Path $Source 'build-1.6.1'
New-Item -ItemType Directory -Force $build,(Join-Path $build 'gen'),(Join-Path $build 'classes'),(Join-Path $build 'dex'),$Output | Out-Null
function Run-Tool([string]$Name,[string[]]$Arguments){ & $Name @Arguments; if($LASTEXITCODE -ne 0){throw "$Name failed: $LASTEXITCODE"} }
Run-Tool (Join-Path $bt 'aapt2.exe') @('compile','--dir',(Join-Path $Source 'res'),'-o',(Join-Path $build 'resources.zip'))
Run-Tool (Join-Path $bt 'aapt2.exe') @('link','-o',(Join-Path $build 'base.apk'),'--manifest',(Join-Path $Source 'AndroidManifest.xml'),'-I',$platform.FullName,'--java',(Join-Path $build 'gen'),'--version-code','13','--version-name','1.6.1',(Join-Path $build 'resources.zip'))
$files=@(Get-ChildItem -Recurse -File (Join-Path $Source 'src'),(Join-Path $build 'gen') -Filter '*.java' | ForEach-Object {$_.FullName})
$javacArgs=@('-encoding','UTF-8','--release','8','-classpath',$platform.FullName,'-d',(Join-Path $build 'classes'))+$files
Run-Tool (Join-Path $jdk.FullName 'bin\javac.exe') $javacArgs
Run-Tool (Join-Path $jdk.FullName 'bin\jar.exe') @('cf',(Join-Path $build 'classes.jar'),'-C',(Join-Path $build 'classes'),'.')
Run-Tool (Join-Path $bt 'd8.bat') @('--release','--min-api','30','--lib',$platform.FullName,'--output',(Join-Path $build 'dex'),(Join-Path $build 'classes.jar'))
Run-Tool $Python @('-c','import zipfile,sys; z=zipfile.ZipFile(sys.argv[1],"a"); z.write(sys.argv[2],"classes.dex"); z.close()',(Join-Path $build 'base.apk'),(Join-Path $build 'dex\classes.dex'))
Run-Tool (Join-Path $bt 'zipalign.exe') @('-f','-p','4',(Join-Path $build 'base.apk'),(Join-Path $build 'aligned.apk'))
if(-not (Test-Path $Keystore) -or -not (Test-Path $PasswordFile)){throw 'Provide an existing private signing key and password file outside the source tree'}
$apk=Join-Path $Output 'CXY-工作台-Android-1.6.1.apk'
Run-Tool (Join-Path $jdk.FullName 'bin\java.exe') @('-jar',(Join-Path $bt 'lib\apksigner.jar'),'sign','--ks',$Keystore,'--ks-key-alias',$KeyAlias,'--ks-pass',"file:$PasswordFile",'--out',$apk,(Join-Path $build 'aligned.apk'))
Run-Tool (Join-Path $jdk.FullName 'bin\java.exe') @('-jar',(Join-Path $bt 'lib\apksigner.jar'),'verify','--verbose','--print-certs',$apk)
Run-Tool (Join-Path $bt 'aapt2.exe') @('dump','badging',$apk)
$receipt=@{built=$true;apk=$apk;sha256=(Get-FileHash -Algorithm SHA256 $apk).Hash.ToLower();bytes=(Get-Item $apk).Length;minSdk=30;targetSdk=36;configurationEmbedded=$false;deviceInstalled=$false}
$receipt | ConvertTo-Json | Set-Content -Encoding utf8 (Join-Path $Output 'build-receipt-1.6.1.json')
$receipt | ConvertTo-Json -Compress
