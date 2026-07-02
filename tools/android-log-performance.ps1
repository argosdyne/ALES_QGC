param(
    [string]$Package = "org.Agosdyne.alesqgc",
    [int]$DurationSec = 120,
    [string]$OutDir = ".\log-perf-results",
    [switch]$ClearLogcat,
    [switch]$AllBuffers,
    [switch]$NoPidFilter,
    [switch]$IncludeVerbose,
    [int]$SampleIntervalSec = 5,
    [string]$Serial = ""
)

$ErrorActionPreference = "Stop"

function Invoke-Adb {
    $adbArgs = @()
    if ($Serial -ne "") {
        $adbArgs += @("-s", $Serial)
    }
    $adbArgs += $args
    & adb @adbArgs
}

function Get-NowStamp {
    return (Get-Date).ToString("yyyyMMdd-HHmmss")
}

function Get-AppPid {
    param([string]$Pkg)

    $pidText = (Invoke-Adb shell pidof $Pkg 2>$null | Out-String).Trim()
    if ($pidText -match "^\d+") {
        return ($pidText -split "\s+")[0]
    }

    $psText = Invoke-Adb shell ps -A 2>$null | Out-String
    foreach ($line in ($psText -split "`r?`n")) {
        if ($line -match [regex]::Escape($Pkg)) {
            $parts = $line.Trim() -split "\s+"
            foreach ($p in $parts) {
                if ($p -match "^\d+$") {
                    return $p
                }
            }
        }
    }

    return $null
}

function Parse-Level {
    param([string]$Line)

    if ($Line -match "\s([VDIWEF])\/") {
        return $Matches[1]
    }
    if ($Line -match "\s([VDIWEF])\s+") {
        return $Matches[1]
    }
    return "?"
}

function Parse-Tag {
    param([string]$Line)

    if ($Line -match "\s[VDIWEF]\/([^(:]+)") {
        return $Matches[1].Trim()
    }
    if ($Line -match "\s[VDIWEF]\s+([^:]+):") {
        return $Matches[1].Trim()
    }
    return "?"
}

function Get-FileBytes {
    param([string]$Path)

    if (Test-Path $Path) {
        return (Get-Item $Path).Length
    }
    return 0
}

function Get-FileLineCount {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return 0
    }

    $count = 0
    Get-Content $Path -ReadCount 1000 | ForEach-Object {
        $count += $_.Count
    }
    return $count
}

function Get-LogcatDroppedSummary {
    $stats = Invoke-Adb shell logcat -S 2>$null | Out-String
    $droppedLines = @()
    foreach ($line in ($stats -split "`r?`n")) {
        if ($line -match "drop|Dropped|dropped|lost|overflow") {
            $droppedLines += $line.Trim()
        }
    }
    if ($droppedLines.Count -eq 0) {
        return ""
    }
    return ($droppedLines -join " | ")
}

function Get-CpuLine {
    param([string]$appPid, [string]$Pkg)

    $top = Invoke-Adb shell top -b -n 1 2>$null | Out-String
    $match = ""
    foreach ($line in ($top -split "`r?`n")) {
        if (($appPid -and $line -match "\b$appPid\b") -or ($line -match [regex]::Escape($Pkg))) {
            $match = $line.Trim()
            break
        }
    }
    return $match
}

function Get-MemSummary {
    param([string]$Pkg)

    $mem = Invoke-Adb shell dumpsys meminfo $Pkg 2>$null | Out-String
    $summary = @{}
    foreach ($line in ($mem -split "`r?`n")) {
        if ($line -match "TOTAL\s+(\d+)") {
            $summary.TotalKb = [int64]$Matches[1]
        }
        if ($line -match "Native Heap\s+(\d+)") {
            $summary.NativeHeapKb = [int64]$Matches[1]
        }
        if ($line -match "Dalvik Heap\s+(\d+)") {
            $summary.DalvikHeapKb = [int64]$Matches[1]
        }
    }
    return $summary
}

function Start-LogcatCapture {
    param(
        [string]$Path,
        [string]$appPid,
        [bool]$CaptureAllBuffers,
        [bool]$DisablePidFilter,
        [bool]$Verbose
    )

    $args = @()
    if ($Serial -ne "") {
        $args += @("-s", $Serial)
    }
    $args += "logcat"
    if ($CaptureAllBuffers) {
        $args += @("-b", "all")
    }
    if (-not $DisablePidFilter -and $appPid) {
        $args += @("--pid", $appPid)
    }
    $args += @("-v", "threadtime")
    if (-not $Verbose) {
        $args += @("*:I")
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "adb"
    $psi.Arguments = ($args | ForEach-Object {
        if ($_ -match '[\s"]') {
            '"' + ($_ -replace '"', '\"') + '"'
        } else {
            $_
        }
    }) -join " "
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    [void]$proc.Start()

    $writer = [System.IO.StreamWriter]::new($Path, $false, [System.Text.Encoding]::UTF8)
    $copyTask = $proc.StandardOutput.BaseStream.CopyToAsync($writer.BaseStream)

    return @{
        Process = $proc
        Writer = $writer
        CopyTask = $copyTask
        Args = ($args -join " ")
    }
}

function Stop-LogcatCapture {
    param($Capture)

    try {
        if (-not $Capture.Process.HasExited) {
            $Capture.Process.Kill()
        }
    } catch {}

    try {
        $Capture.CopyTask.Wait(3000) | Out-Null
    } catch {}

    try {
        $Capture.Writer.Flush()
        $Capture.Writer.Dispose()
    } catch {}
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$stamp = Get-NowStamp
$rawLog = Join-Path $OutDir "$stamp-logcat.txt"
$sampleCsv = Join-Path $OutDir "$stamp-samples.csv"
$summaryTxt = Join-Path $OutDir "$stamp-summary.txt"
$topTagsCsv = Join-Path $OutDir "$stamp-top-tags.csv"
$topLevelsCsv = Join-Path $OutDir "$stamp-levels.csv"

Write-Host "Package       : $Package"
Write-Host "Duration      : $DurationSec sec"
Write-Host "Output dir    : $OutDir"

$devices = Invoke-Adb devices | Out-String
if ($devices -notmatch "`tdevice") {
    throw "No Android device found via adb. Check: adb devices"
}

$appPid = Get-AppPid -Pkg $Package
if (-not $appPid) {
    Write-Host ""
    Write-Host "Could not find running process for package: $Package"
    Write-Host "Likely QGC/Ales packages installed on device:"
    Invoke-Adb shell pm list packages | Select-String -Pattern "qgc|qground|ales|agos|mavlink" -CaseSensitive:$false
    Write-Host ""
    Write-Host "Likely running processes:"
    Invoke-Adb shell ps -A | Select-String -Pattern "qgc|qground|ales|agos|mavlink" -CaseSensitive:$false
    Write-Host ""
    throw "App process not found. Open the app on device first, or pass the correct -Package value."
}
Write-Host "PID           : $appPid"

$logcatSizeBefore = Invoke-Adb shell logcat -g 2>$null | Out-String
$dropBefore = Get-LogcatDroppedSummary

if ($ClearLogcat) {
    Write-Host "Clear logcat  : yes"
    Invoke-Adb logcat -c | Out-Null
}

$capture = Start-LogcatCapture `
    -Path $rawLog `
    -appPid $appPid `
    -CaptureAllBuffers ([bool]$AllBuffers) `
    -DisablePidFilter ([bool]$NoPidFilter) `
    -Verbose ([bool]$IncludeVerbose)

Write-Host "Logcat cmd    : adb $($capture.Args)"
Write-Host "Capturing..."

"timestamp,elapsed_sec,pid,log_bytes,log_bytes_per_sec,log_lines,cpu_line,total_pss_kb,native_heap_kb,dalvik_heap_kb,dropped_summary" |
    Set-Content -Encoding UTF8 $sampleCsv

$start = Get-Date
$lastTime = $start
$lastBytes = 0
while (((Get-Date) - $start).TotalSeconds -lt $DurationSec) {
    Start-Sleep -Seconds $SampleIntervalSec

    $now = Get-Date
    $elapsed = [int][math]::Round(($now - $start).TotalSeconds)
    $bytes = Get-FileBytes -Path $rawLog
    $deltaSec = [math]::Max(1, ($now - $lastTime).TotalSeconds)
    $bps = [int64](($bytes - $lastBytes) / $deltaSec)
    $lines = 0
    if (Test-Path $rawLog) {
        $lines = Get-FileLineCount -Path $rawLog
    }
    $cpuLine = (Get-CpuLine -appPid $appPid -Pkg $Package) -replace '"', '""'
    $mem = Get-MemSummary -Pkg $Package
    $drop = (Get-LogcatDroppedSummary) -replace '"', '""'

    $row = '"{0}",{1},{2},{3},{4},{5},"{6}",{7},{8},{9},"{10}"' -f `
        $now.ToString("o"), $elapsed, $appPid, $bytes, $bps, $lines, $cpuLine, `
        $mem.TotalKb, $mem.NativeHeapKb, $mem.DalvikHeapKb, $drop
    Add-Content -Encoding UTF8 $sampleCsv $row

    Write-Host ("{0,4}s  {1,10} bytes  {2,8} B/s  {3,8} lines" -f $elapsed, $bytes, $bps, $lines)

    $lastTime = $now
    $lastBytes = $bytes
}

Stop-LogcatCapture -Capture $capture

$finalBytes = Get-FileBytes -Path $rawLog
$finalLines = 0
if (Test-Path $rawLog) {
    $finalLines = Get-FileLineCount -Path $rawLog
}
$avgBps = [int64]($finalBytes / [math]::Max(1, $DurationSec))
$avgLps = [double]($finalLines / [math]::Max(1, $DurationSec))

$levelCounts = @{}
$tagCounts = @{}
if (Test-Path $rawLog) {
    Get-Content $rawLog -ReadCount 1000 | ForEach-Object {
        foreach ($line in $_) {
            $level = Parse-Level -Line $line
            $tag = Parse-Tag -Line $line
            if (-not $levelCounts.ContainsKey($level)) { $levelCounts[$level] = 0 }
            if (-not $tagCounts.ContainsKey($tag)) { $tagCounts[$tag] = 0 }
            $levelCounts[$level]++
            $tagCounts[$tag]++
        }
    }
}

$levelCounts.GetEnumerator() |
    Sort-Object -Property Value -Descending |
    ForEach-Object { [pscustomobject]@{ level = $_.Key; count = $_.Value } } |
    Export-Csv -NoTypeInformation -Encoding UTF8 $topLevelsCsv

$tagCounts.GetEnumerator() |
    Sort-Object -Property Value -Descending |
    Select-Object -First 50 |
    ForEach-Object { [pscustomobject]@{ tag = $_.Key; count = $_.Value } } |
    Export-Csv -NoTypeInformation -Encoding UTF8 $topTagsCsv

$logcatSizeAfter = Invoke-Adb shell logcat -g 2>$null | Out-String
$dropAfter = Get-LogcatDroppedSummary

$summary = @"
Android log performance test
============================
Package              : $Package
PID                  : $appPid
Duration sec         : $DurationSec
PID filter           : $(-not $NoPidFilter)
All buffers          : $AllBuffers
Include verbose      : $IncludeVerbose
Clear logcat first   : $ClearLogcat
Logcat command       : adb $($capture.Args)

Final log bytes      : $finalBytes
Final log lines      : $finalLines
Average bytes/sec    : $avgBps
Average lines/sec    : $("{0:N2}" -f $avgLps)

Raw log              : $rawLog
Samples CSV          : $sampleCsv
Top tags CSV         : $topTagsCsv
Levels CSV           : $topLevelsCsv

Logcat buffer before:
$logcatSizeBefore

Logcat dropped before:
$dropBefore

Logcat buffer after:
$logcatSizeAfter

Logcat dropped after:
$dropAfter
"@

$summary | Set-Content -Encoding UTF8 $summaryTxt

Write-Host ""
Write-Host "Done."
Write-Host "Summary       : $summaryTxt"
Write-Host "Raw log       : $rawLog"
Write-Host "Samples       : $sampleCsv"
Write-Host "Top tags      : $topTagsCsv"
Write-Host "Levels        : $topLevelsCsv"
Write-Host ("Average       : {0} B/s, {1:N2} lines/s" -f $avgBps, $avgLps)
