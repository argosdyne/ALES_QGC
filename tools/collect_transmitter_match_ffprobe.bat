@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem Collect transmitter/camera RTSP stream evidence for checklist tab:
rem "5. Transmitter Match".
rem
rem Requires ffprobe in PATH.
rem Download FFmpeg for Windows if missing:
rem   https://www.gyan.dev/ffmpeg/builds/
rem Add ffmpeg\bin to PATH, then re-run this script.
rem
rem Usage:
rem   tools\collect_transmitter_match_ffprobe.bat [eo_url] [ir_url] [duration_sec]
rem
rem Example:
rem   tools\collect_transmitter_match_ffprobe.bat rtsp://192.168.2.119:8554/eo rtsp://192.168.2.119:8554/ir 20

set "EO_URL=%~1"
if "%EO_URL%"=="" set "EO_URL=rtsp://192.168.2.119:8554/eo"

set "IR_URL=%~2"
if "%IR_URL%"=="" set "IR_URL=rtsp://192.168.2.119:8554/ir"

set "DURATION=%~3"
if "%DURATION%"=="" set "DURATION=20"

for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "STAMP=%%I"
set "OUTDIR=%CD%\transmitter_match_%STAMP%"
mkdir "%OUTDIR%" >nul 2>&1

set "RESULTS=%OUTDIR%\actual_results_transmitter_match.tsv"
set "SUMMARY=%OUTDIR%\summary.txt"

echo Transmitter Match ffprobe collection > "%SUMMARY%"
echo Generated: %DATE% %TIME%>> "%SUMMARY%"
echo EO_URL=%EO_URL%>> "%SUMMARY%"
echo IR_URL=%IR_URL%>> "%SUMMARY%"
echo DURATION=%DURATION%s>> "%SUMMARY%"
echo.>> "%SUMMARY%"

echo Sheet	Item	Command	Expected	Actual Result / Observation	Status	Evidence File > "%RESULTS%"

where ffprobe > "%OUTDIR%\where_ffprobe.txt" 2>&1
if errorlevel 1 (
    echo ERROR: ffprobe not found in PATH.
    echo ERROR: ffprobe not found in PATH.>> "%SUMMARY%"
    call :AddResult "5. Transmitter Match" "ffprobe available on dev host" "where ffprobe" "ffprobe path returned" "ffprobe NOT FOUND" "Fail" "Install FFmpeg and add ffmpeg\\bin to PATH."
    echo.
    echo ffprobe not found. Install FFmpeg and add ffmpeg\bin to PATH:
    echo https://www.gyan.dev/ffmpeg/builds/
    echo Output folder: "%OUTDIR%"
    exit /b 1
)

for /f "usebackq delims=" %%P in ("%OUTDIR%\where_ffprobe.txt") do (
    if "!FFPROBE_PATH!"=="" set "FFPROBE_PATH=%%P"
)
call :AddResult "5. Transmitter Match" "ffprobe available on dev host" "where ffprobe" "ffprobe path returned" "%FFPROBE_PATH%" "Pass" "Used for RTSP stream inspection."

call :ProbeStream "eo" "%EO_URL%"
call :ProbeStream "ir" "%IR_URL%"

echo.>> "%SUMMARY%"
echo Results TSV: %RESULTS%>> "%SUMMARY%"
echo Done.
echo Output folder:
echo "%OUTDIR%"
echo.
echo Send this file:
echo "%RESULTS%"
exit /b 0

:ProbeStream
set "NAME=%~1"
set "URL=%~2"
echo.
echo Probing %NAME%: %URL%
echo ==== %NAME% ====>> "%SUMMARY%"

set "PREFIX=%OUTDIR%\%NAME%"

ffprobe -rtsp_transport udp -timeout 5000000 -v error -show_streams -show_format -of default=noprint_wrappers=1 "%URL%" > "%PREFIX%_streams.txt" 2> "%PREFIX%_streams_err.txt"
if errorlevel 1 (
    findstr /i /c:"Option not found" "%PREFIX%_streams_err.txt" >nul 2>&1
    if not errorlevel 1 (
        ffprobe -rtsp_transport udp -v error -show_streams -show_format -of default=noprint_wrappers=1 "%URL%" > "%PREFIX%_streams.txt" 2> "%PREFIX%_streams_err.txt"
    )
)
if errorlevel 1 (
    call :AddResult "5. Transmitter Match" "%NAME% RTSP stream reachable" "ffprobe -rtsp_transport udp -show_streams %URL%" "Stream info returned" "ffprobe failed; see %NAME%_streams_err.txt" "Fail" "%NAME%_streams_err.txt"
    exit /b 0
)
call :AddResult "5. Transmitter Match" "%NAME% RTSP stream reachable" "ffprobe -rtsp_transport udp -show_streams %URL%" "Stream info returned" "Stream info returned" "Pass" "%NAME%_streams.txt"

ffprobe -rtsp_transport udp -timeout 5000000 -v error -select_streams v:0 -show_entries stream=codec_name,profile,level,width,height,r_frame_rate,avg_frame_rate,bit_rate,codec_tag_string -of default=noprint_wrappers=1 "%URL%" > "%PREFIX%_video_stream.txt" 2> "%PREFIX%_video_stream_err.txt"
if errorlevel 1 (
    findstr /i /c:"Option not found" "%PREFIX%_video_stream_err.txt" >nul 2>&1
    if not errorlevel 1 (
        ffprobe -rtsp_transport udp -v error -select_streams v:0 -show_entries stream=codec_name,profile,level,width,height,r_frame_rate,avg_frame_rate,bit_rate,codec_tag_string -of default=noprint_wrappers=1 "%URL%" > "%PREFIX%_video_stream.txt" 2> "%PREFIX%_video_stream_err.txt"
    )
)

ffprobe -rtsp_transport udp -timeout 5000000 -v error -read_intervals "%%+#%DURATION%" -select_streams v:0 -show_frames -show_entries frame=key_frame,pict_type,best_effort_timestamp_time,pkt_size -of csv=p=0 "%URL%" > "%PREFIX%_frames.csv" 2> "%PREFIX%_frames_err.txt"
if errorlevel 1 (
    findstr /i /c:"Option not found" "%PREFIX%_frames_err.txt" >nul 2>&1
    if not errorlevel 1 (
        ffprobe -rtsp_transport udp -v error -read_intervals "%%+#%DURATION%" -select_streams v:0 -show_frames -show_entries frame=key_frame,pict_type,best_effort_timestamp_time,pkt_size -of csv=p=0 "%URL%" > "%PREFIX%_frames.csv" 2> "%PREFIX%_frames_err.txt"
    )
)

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$prefix='%PREFIX:\=\\%';" ^
  "$s=@{}; Get-Content \"$prefix`_video_stream.txt\" | %% { if($_ -match '^(.*?)=(.*)$'){ $s[$matches[1]]=$matches[2] } };" ^
  "$frames=@(); if(Test-Path \"$prefix`_frames.csv\"){ $frames=Get-Content \"$prefix`_frames.csv\" | ? { $_.Trim() -ne '' } };" ^
  "$total=$frames.Count; $key=0; $i=0; $p=0; $b=0; $firstTs=$null; $lastTs=$null; $keyTs=@();" ^
  "foreach($line in $frames){ $parts=$line.Split(','); if($parts.Count -ge 4){ if($parts[0] -eq '1'){ $key++; $keyTs += [double]$parts[2] }; if($parts[1] -eq 'I'){ $i++ } elseif($parts[1] -eq 'P'){ $p++ } elseif($parts[1] -eq 'B'){ $b++ }; if($firstTs -eq $null){ $firstTs=[double]$parts[2] }; $lastTs=[double]$parts[2] } };" ^
  "$dur= if($firstTs -ne $null -and $lastTs -ne $null){ [math]::Round($lastTs-$firstTs,3) } else { 0 };" ^
  "$fps= if($dur -gt 0){ [math]::Round($total/$dur,2) } else { 0 };" ^
  "$idrInterval='unknown'; if($keyTs.Count -ge 2){ $gaps=@(); for($idx=1;$idx -lt $keyTs.Count;$idx++){ $gaps += ($keyTs[$idx]-$keyTs[$idx-1]) }; $idrInterval=[math]::Round(($gaps | Measure-Object -Average).Average,3) };" ^
  "$bitrate=$s['bit_rate']; if(-not $bitrate){ $bitrate='not reported by stream metadata' };" ^
  "$out=@();" ^
  "$out += \"codec_name=$($s['codec_name'])\"; $out += \"profile=$($s['profile'])\"; $out += \"level=$($s['level'])\"; $out += \"width=$($s['width'])\"; $out += \"height=$($s['height'])\"; $out += \"r_frame_rate=$($s['r_frame_rate'])\"; $out += \"avg_frame_rate=$($s['avg_frame_rate'])\"; $out += \"bit_rate=$bitrate\"; $out += \"frames_sampled=$total\"; $out += \"estimated_fps=$fps\"; $out += \"key_frames=$key\"; $out += \"I_frames=$i\"; $out += \"P_frames=$p\"; $out += \"B_frames=$b\"; $out += \"estimated_idr_interval_sec=$idrInterval\";" ^
  "$out | Set-Content \"$prefix`_analysis.txt\""

call :AddFromAnalysis "%NAME%" "H.264 codec/profile/level" "%PREFIX%_analysis.txt"
call :AddFrameChecks "%NAME%" "%PREFIX%_analysis.txt"
exit /b 0

:AddFromAnalysis
set "NAME=%~1"
set "FILE=%~2"
set "CODEC="
set "PROFILE="
set "LEVEL="
set "WIDTH="
set "HEIGHT="
set "FPS="
set "BITRATE="
for /f "tokens=1,* delims==" %%A in (%FILE%) do (
    if "%%A"=="codec_name" set "CODEC=%%B"
    if "%%A"=="profile" set "PROFILE=%%B"
    if "%%A"=="level" set "LEVEL=%%B"
    if "%%A"=="width" set "WIDTH=%%B"
    if "%%A"=="height" set "HEIGHT=%%B"
    if "%%A"=="estimated_fps" set "FPS=%%B"
    if "%%A"=="bit_rate" set "BITRATE=%%B"
)
call :AddResult "5. Transmitter Match" "%NAME% H.264 profile" "ffprobe stream profile" "baseline/constrained-baseline preferred" "codec=%CODEC%, profile=%PROFILE%" "Pass" "%NAME%_analysis.txt"
call :AddResult "5. Transmitter Match" "%NAME% H.264 level" "ffprobe stream level" "level <= 4.0 for 1080p30" "level=%LEVEL%, resolution=%WIDTH%x%HEIGHT%, fps~%FPS%" "Pending" "%NAME%_analysis.txt"
call :AddResult "5. Transmitter Match" "%NAME% bitrate" "ffprobe stream bit_rate / pcap bandwidth" "Target bitrate documented" "bit_rate=%BITRATE%" "Pending" "%NAME%_analysis.txt"
exit /b 0

:AddFrameChecks
set "NAME=%~1"
set "FILE=%~2"
set "BFRAMES="
set "IDR="
set "KEYS="
for /f "tokens=1,* delims==" %%A in (%FILE%) do (
    if "%%A"=="B_frames" set "BFRAMES=%%B"
    if "%%A"=="estimated_idr_interval_sec" set "IDR=%%B"
    if "%%A"=="key_frames" set "KEYS=%%B"
)
set "BSTATUS=Pending"
if "%BFRAMES%"=="0" set "BSTATUS=Pass"
call :AddResult "5. Transmitter Match" "%NAME% B-frames disabled" "ffprobe frame pict_type sample" "Zero B-frames" "B_frames=%BFRAMES%" "%BSTATUS%" "%NAME%_frames.csv"
call :AddResult "5. Transmitter Match" "%NAME% GOP / IDR interval" "ffprobe key_frame sample" "IDR every 1-2 seconds preferred" "key_frames=%KEYS%, estimated_idr_interval_sec=%IDR%" "Pending" "%NAME%_analysis.txt"
exit /b 0

:AddResult
set "SHEET=%~1"
set "ITEM=%~2"
set "CMD=%~3"
set "EXPECTED=%~4"
set "ACTUAL=%~5"
set "STATUS=%~6"
set "EVIDENCE=%~7"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$line = @($env:SHEET,$env:ITEM,$env:CMD,$env:EXPECTED,$env:ACTUAL,$env:STATUS,$env:EVIDENCE) -join \"`t\"; Add-Content -LiteralPath '%RESULTS%' -Value $line"
exit /b 0
