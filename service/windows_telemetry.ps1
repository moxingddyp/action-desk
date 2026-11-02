# CXY Workbench Linux collector v1; read-only counters; no service, network or driver changes.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
# Only the newest dashboard sampler is needed. Match the exact source marker;
# unrelated PowerShell, SSH and model jobs must remain untouched.
foreach ($candidate in @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='pwsh.exe'")) {
    if ($candidate.ProcessId -eq $PID) { continue }
    $source = ''
    if ($candidate.CommandLine -match '-EncodedCommand\s+(\S+)') {
        try { $source = [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($Matches[1])) } catch { }
    }
    if ($source.StartsWith('# CXY Workbench Linux collector v1; read-only counters; no service, network or driver changes.') -and
        $source.Contains('Get-NetAdapterStatistics') -and $source.Contains("id='winpc'")) {
        Stop-Process -Id $candidate.ProcessId -ErrorAction SilentlyContinue
    }
}
# Windows' SSH default shell can retain a child's stdin after disconnect.
# Watch the actual per-connection sshd ancestor instead of depending on stdin EOF.
$ancestor = $PID
$owner = $null
for ($level = 0; $level -lt 6; $level++) {
    $parent = Get-CimInstance Win32_Process -Filter "ProcessId=$ancestor"
    if ($null -eq $parent) { break }
    if ($parent.Name -eq 'sshd.exe') { $owner = Get-Process -Id $parent.ProcessId; break }
    $ancestor = $parent.ParentProcessId
}
if ($null -eq $owner) { throw 'Dashboard SSH owner not found' }
Add-Type -TypeDefinition @'
using System;
using System.Diagnostics;
using System.Threading;
public static class CxyDeviceStreamLease {
    private static Timer timer;
    public static void Start(int owner, long started) {
        timer = new Timer(_ => {
            try {
                using (var process = Process.GetProcessById(owner)) {
                    if (!process.HasExited && process.StartTime.ToUniversalTime().Ticks == started) return;
                }
            } catch { }
            Environment.Exit(0);
        }, null, 3000, 3000);
    }
}
'@
[CxyDeviceStreamLease]::Start($owner.Id, $owner.StartTime.ToUniversalTime().Ticks)
$prev = $null
while ($true) {
    $watch = [Diagnostics.Stopwatch]::StartNew()
    try {
        $now = [Diagnostics.Stopwatch]::GetTimestamp() / [double][Diagnostics.Stopwatch]::Frequency
        $cpu = Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'"
        $memory = Get-CimInstance Win32_OperatingSystem
        $adapters = @(Get-NetAdapter -Physical | Where-Object Status -eq 'Up')
        $stats = @($adapters | Get-NetAdapterStatistics)
        $rx = ($stats | Measure-Object ReceivedBytes -Sum).Sum
        $tx = ($stats | Measure-Object SentBytes -Sum).Sum
        $gpu = $null; $gpuMemory = $null; $gpuTotal = $null
        $nvidia = Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue
        if ($nvidia) {
            $line = & $nvidia.Source --query-gpu=utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits
            if ($LASTEXITCODE -eq 0 -and $line) {
                $fields = @($line)[0].Split(',')
                $gpu = [double]$fields[0].Trim(); $gpuMemory = [double]$fields[1].Trim()*1MB; $gpuTotal = [double]$fields[2].Trim()*1MB
            }
        }
        $disks = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object { @{ name=$_.DeviceID; total=[double]$_.Size; used=([double]$_.Size-[double]$_.FreeSpace) } })
        $down = $null; $up = $null
        if ($prev) { $elapsed=$now-$prev.time; $down=[Math]::Max(0,($rx-$prev.rx)/$elapsed); $up=[Math]::Max(0,($tx-$prev.tx)/$elapsed) }
        $result = @{ id='winpc'; host=$env:COMPUTERNAME; cpu=[double]$cpu.PercentProcessorTime; gpu=$gpu; gpuMemoryUsed=$gpuMemory; gpuMemoryTotal=$gpuTotal; memoryTotal=([double]$memory.TotalVisibleMemorySize*1KB); memoryUsed=(([double]$memory.TotalVisibleMemorySize-[double]$memory.FreePhysicalMemory)*1KB); download=$down; upload=$up; interfaces=($adapters.Name -join ','); disks=$disks; services=@(); uptime=((Get-Date)-$memory.LastBootUpTime).TotalSeconds }
        [Console]::Out.WriteLine(($result | ConvertTo-Json -Compress -Depth 5))
        [Console]::Out.Flush()
        $prev=@{ time=$now; rx=$rx; tx=$tx }
    } catch {
        [Console]::Out.WriteLine((@{ id='winpc'; host=$env:COMPUTERNAME; error=$_.Exception.GetType().Name } | ConvertTo-Json -Compress))
        [Console]::Out.Flush()
    }
    Start-Sleep -Milliseconds ([Math]::Max(20,1000-$watch.ElapsedMilliseconds))
}
