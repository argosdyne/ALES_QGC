param(
    [int]$DurationSeconds = 30,
    [string]$PackageName = "org.Agosdyne.alesqgc",
    [string]$OutDir = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $OutDir = Join-Path (Get-Location) "qcm_udp_video_check_$timestamp"
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function Run-Adb {
    param(
        [string[]]$Arguments,
        [string]$OutputFile
    )

    $output = & adb @Arguments 2>&1
    $output | Out-File -FilePath (Join-Path $OutDir $OutputFile) -Encoding UTF8
    return $output
}

function Snapshot {
    param([string]$Prefix)

    Run-Adb -Arguments @("shell", "cat", "/proc/net/snmp") -OutputFile "$Prefix`_proc_net_snmp.txt" | Out-Null
    Run-Adb -Arguments @("shell", "cat", "/proc/net/dev") -OutputFile "$Prefix`_proc_net_dev.txt" | Out-Null
    Run-Adb -Arguments @("shell", "top", "-b", "-m", "20", "-n", "1") -OutputFile "$Prefix`_top.txt" | Out-Null
    Run-Adb -Arguments @("shell", "cat", "/proc/sys/net/core/rmem_max") -OutputFile "$Prefix`_rmem_max.txt" | Out-Null
    Run-Adb -Arguments @("shell", "cat", "/proc/sys/net/core/rmem_default") -OutputFile "$Prefix`_rmem_default.txt" | Out-Null
    Run-Adb -Arguments @("shell", "cat", "/proc/sys/net/core/netdev_max_backlog") -OutputFile "$Prefix`_netdev_max_backlog.txt" | Out-Null
}

function Parse-UdpValues {
    param([string]$File)

    $lines = Get-Content $File | Where-Object { $_ -like "Udp:*" }
    if ($lines.Count -lt 2) {
        return $null
    }

    $headers = ($lines[0] -replace "^Udp:\s*", "").Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)
    $values = ($lines[1] -replace "^Udp:\s*", "").Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)
    $map = @{}
    for ($i = 0; $i -lt $headers.Count -and $i -lt $values.Count; $i++) {
        $map[$headers[$i]] = [int64]$values[$i]
    }
    return $map
}

function Write-DeltaSummary {
    $before = Parse-UdpValues (Join-Path $OutDir "before_proc_net_snmp.txt")
    $after = Parse-UdpValues (Join-Path $OutDir "after_proc_net_snmp.txt")

    $summaryPath = Join-Path $OutDir "summary.txt"
    "QCM UDP video check" | Out-File $summaryPath -Encoding UTF8
    "Timestamp: $(Get-Date -Format o)" | Out-File $summaryPath -Append -Encoding UTF8
    "DurationSeconds: $DurationSeconds" | Out-File $summaryPath -Append -Encoding UTF8
    "PackageName: $PackageName" | Out-File $summaryPath -Append -Encoding UTF8
    "" | Out-File $summaryPath -Append -Encoding UTF8

    if ($before -eq $null -or $after -eq $null) {
        "UDP summary: FAILED to parse /proc/net/snmp" | Out-File $summaryPath -Append -Encoding UTF8
        return
    }

    "UDP delta:" | Out-File $summaryPath -Append -Encoding UTF8
    foreach ($key in @("InDatagrams", "NoPorts", "InErrors", "OutDatagrams", "RcvbufErrors", "SndbufErrors", "InCsumErrors", "IgnoredMulti")) {
        if ($before.ContainsKey($key) -and $after.ContainsKey($key)) {
            $delta = $after[$key] - $before[$key]
            ("{0}: {1} -> {2}  delta={3}" -f $key, $before[$key], $after[$key], $delta) | Out-File $summaryPath -Append -Encoding UTF8
        }
    }

    "" | Out-File $summaryPath -Append -Encoding UTF8
    "Relevant log lines:" | Out-File $summaryPath -Append -Encoding UTF8
    Get-Content (Join-Path $OutDir "runtime_logcat.txt") |
        Select-String -Pattern "rtspsrc.configured|rtpjitterbuffer.configured|udpsrc.configured|runtime-config|child-config|protocols=udp|drop-on-latency|buffer-size|decoder-selected|rtsp-runtime-transport|RTP|jitter|lost|drop" |
        ForEach-Object { $_.Line } |
        Out-File $summaryPath -Append -Encoding UTF8
}

"Output directory: $OutDir"

Run-Adb -Arguments @("devices") -OutputFile "adb_devices.txt" | Out-Null
Run-Adb -Arguments @("shell", "getprop", "ro.product.manufacturer") -OutputFile "device_manufacturer.txt" | Out-Null
Run-Adb -Arguments @("shell", "getprop", "ro.product.model") -OutputFile "device_model.txt" | Out-Null
Run-Adb -Arguments @("shell", "pm", "path", $PackageName) -OutputFile "pm_path.txt" | Out-Null

Run-Adb -Arguments @("logcat", "-c") -OutputFile "logcat_clear.txt" | Out-Null

Snapshot -Prefix "before"

Start-Sleep -Seconds $DurationSeconds

Snapshot -Prefix "after"

Run-Adb -Arguments @("logcat", "-d") -OutputFile "runtime_logcat.txt" | Out-Null

Write-DeltaSummary

"Done. Files written to: $OutDir"
"Summary: $(Join-Path $OutDir 'summary.txt')"
