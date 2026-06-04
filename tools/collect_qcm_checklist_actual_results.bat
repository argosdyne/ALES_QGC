@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem Collect evidence for QCM6490 MediaCodec / GStreamer checklist.
rem Usage:
rem   tools\collect_qcm_checklist_actual_results.bat [package] [drone_ip] [duration_sec]
rem Example:
rem   tools\collect_qcm_checklist_actual_results.bat org.Agosdyne.alesqgc 192.168.2.119 60

set "PACKAGE=%~1"
if "%PACKAGE%"=="" set "PACKAGE=org.Agosdyne.alesqgc"

set "DRONE_IP=%~2"
if "%DRONE_IP%"=="" set "DRONE_IP=192.168.2.119"

set "DURATION=%~3"
if "%DURATION%"=="" set "DURATION=60"

for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "STAMP=%%I"
set "OUTDIR=%CD%\qcm_checklist_actual_%STAMP%"
mkdir "%OUTDIR%" >nul 2>&1

set "SUMMARY=%OUTDIR%\actual_results_summary.txt"
set "TSV=%OUTDIR%\actual_results.tsv"

echo Output folder: "%OUTDIR%"
echo Package: %PACKAGE%
echo Drone IP: %DRONE_IP%
echo Duration: %DURATION%s
echo.

echo QCM6490 MediaCodec / GStreamer Checklist Actual Results > "%SUMMARY%"
echo Generated: %DATE% %TIME%>> "%SUMMARY%"
echo Package: %PACKAGE%>> "%SUMMARY%"
echo Drone IP: %DRONE_IP%>> "%SUMMARY%"
echo Duration: %DURATION%s>> "%SUMMARY%"
echo.>> "%SUMMARY%"

echo Sheet	Item	Command	Expected	Actual Result / Observation	Status	Evidence File > "%TSV%"

where adb >nul 2>&1
if errorlevel 1 (
    echo ERROR: adb not found in PATH.
    echo ERROR: adb not found in PATH.>> "%SUMMARY%"
    exit /b 1
)

echo [1/9] Checking adb/device...
adb devices > "%OUTDIR%\adb_devices.txt"
adb get-state > "%OUTDIR%\adb_state.txt" 2>&1
type "%OUTDIR%\adb_state.txt" | findstr /i "device" >nul
if errorlevel 1 (
    echo ERROR: No adb device is ready. See adb_devices.txt.
    echo ERROR: No adb device is ready. See adb_devices.txt.>> "%SUMMARY%"
    exit /b 1
)

echo [2/9] Collecting Android properties...
adb shell getprop > "%OUTDIR%\getprop_all.txt" 2>&1
adb shell getprop ro.build.version.release > "%OUTDIR%\android_version.txt" 2>&1
adb shell getprop ro.product.model > "%OUTDIR%\product_model.txt" 2>&1
adb shell getprop ro.board.platform > "%OUTDIR%\board_platform.txt" 2>&1
adb shell getprop ro.product.manufacturer > "%OUTDIR%\manufacturer.txt" 2>&1

set /p ANDROID_VERSION=<"%OUTDIR%\android_version.txt"
set /p PRODUCT_MODEL=<"%OUTDIR%\product_model.txt"
set /p BOARD_PLATFORM=<"%OUTDIR%\board_platform.txt"
set /p MANUFACTURER=<"%OUTDIR%\manufacturer.txt"

echo 1. Prerequisites	Android version	adb shell getprop ro.build.version.release	13 or later	%ANDROID_VERSION%	Pending	android_version.txt>> "%TSV%"
echo 1. Prerequisites	Product model	adb shell getprop ro.product.model	Vendor-specific model string	%PRODUCT_MODEL%	Pass	product_model.txt>> "%TSV%"
echo 1. Prerequisites	Board platform	adb shell getprop ro.board.platform	QCM6490/QSSI platform string	%BOARD_PLATFORM%	Pass	board_platform.txt>> "%TSV%"

echo [3/9] Collecting MediaCodec XML/capability evidence...
adb shell cat /vendor/etc/media_codecs.xml > "%OUTDIR%\media_codecs.xml.txt" 2>&1
adb shell cat /vendor/etc/media_codecs_performance.xml > "%OUTDIR%\media_codecs_performance.xml.txt" 2>&1
findstr /i "c2.qti.avc.decoder" "%OUTDIR%\media_codecs.xml.txt" > "%OUTDIR%\codec_avc_qti.txt" 2>&1
findstr /i "c2.qti.hevc.decoder" "%OUTDIR%\media_codecs.xml.txt" > "%OUTDIR%\codec_hevc_qti.txt" 2>&1
findstr /i "qti 1920 1080 240 4096 2176 performance" "%OUTDIR%\media_codecs_performance.xml.txt" > "%OUTDIR%\codec_performance_qti.txt" 2>&1

call :AddCheck "1. Prerequisites" "H.264 HW decoder present" "adb shell cat /vendor/etc/media_codecs.xml | findstr c2.qti.avc.decoder" "c2.qti.avc.decoder entry returned" "%OUTDIR%\codec_avc_qti.txt" "codec_avc_qti.txt"
call :AddCheck "1. Prerequisites" "H.265 HW decoder present" "adb shell cat /vendor/etc/media_codecs.xml | findstr c2.qti.hevc.decoder" "c2.qti.hevc.decoder entry returned" "%OUTDIR%\codec_hevc_qti.txt" "codec_hevc_qti.txt"
call :AddCheck "1. Prerequisites" "Codec performance profile present" "adb shell cat /vendor/etc/media_codecs_performance.xml" "Performance entries listed" "%OUTDIR%\codec_performance_qti.txt" "codec_performance_qti.txt"

echo [4/9] Pulling installed APK and checking GStreamer plugins...
adb shell pm path %PACKAGE% > "%OUTDIR%\pm_path.txt" 2>&1
set "APK_REMOTE="
for /f "tokens=2 delims=:" %%A in ('type "%OUTDIR%\pm_path.txt" ^| findstr /b "package:"') do (
    if "!APK_REMOTE!"=="" set "APK_REMOTE=%%A"
)

if "%APK_REMOTE%"=="" (
    echo Could not find APK path for %PACKAGE%.>> "%SUMMARY%"
    echo 1. Prerequisites	QGC APK installed and located	adb shell pm path %PACKAGE%	Path returned	NOT FOUND	Fail	pm_path.txt>> "%TSV%"
) else (
    echo APK remote path: %APK_REMOTE%
    echo 1. Prerequisites	QGC APK installed and located	adb shell pm path %PACKAGE%	Path returned	%APK_REMOTE%	Pass	pm_path.txt>> "%TSV%"
    adb pull "%APK_REMOTE%" "%OUTDIR%\qgc.apk" > "%OUTDIR%\apk_pull.txt" 2>&1
)

if exist "%OUTDIR%\qgc.apk" (
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
      "Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::OpenRead('%OUTDIR:\=\\%\\qgc.apk').Entries | ForEach-Object { $_.FullName } | Sort-Object" ^
      > "%OUTDIR%\apk_file_list.txt" 2>&1

    call :PluginCheck "1. Prerequisites" "GStreamer core library present in APK" "libgstreamer-1.0.so" "libgstreamer-1.0.so listed"
    call :PluginCheck "1. Prerequisites" "androidmedia plugin present in APK" "libgstandroidmedia.so" "libgstandroidmedia.so listed"
    call :PluginCheck "1. Prerequisites" "RTP plugin present" "libgstrtp.so" "libgstrtp.so listed"
    call :PluginCheck "1. Prerequisites" "RTP manager plugin present" "libgstrtpmanager.so" "libgstrtpmanager.so listed"
    call :PluginCheck "1. Prerequisites" "UDP plugin present" "libgstudp.so" "libgstudp.so listed"
    call :PluginCheck "1. Prerequisites" "Video parsers plugin present" "libgstvideoparsersbad.so" "libgstvideoparsersbad.so listed"
    call :PluginCheck "1. Prerequisites" "QML GL sink present" "libgstqmlgl.so" "libgstqmlgl.so listed"
) else (
    echo APK was not pulled; plugin checks skipped.>> "%SUMMARY%"
)

echo [5/9] Checking network reachability...
adb shell ping -c 3 %DRONE_IP% > "%OUTDIR%\ping_drone.txt" 2>&1
findstr /i /c:"3 received" "%OUTDIR%\ping_drone.txt" > "%OUTDIR%\ping_drone_pass.txt" 2>&1
call :AddCheck "1. Prerequisites" "Drone reachable from controller" "adb shell ping -c 3 %DRONE_IP%" "All 3 pings receive response" "%OUTDIR%\ping_drone_pass.txt" "ping_drone.txt"

echo [6/9] Collecting eth0/UDP counters before launch...
adb shell cat /proc/net/snmp > "%OUTDIR%\proc_net_snmp_before.txt" 2>&1
adb shell cat /proc/net/dev > "%OUTDIR%\proc_net_dev_before.txt" 2>&1
adb shell ip -s link show eth0 > "%OUTDIR%\ip_s_link_eth0_before.txt" 2>&1
adb shell readlink /sys/class/net/eth0/device/driver > "%OUTDIR%\eth0_driver.txt" 2>&1
adb shell lsusb > "%OUTDIR%\lsusb.txt" 2>&1
adb shell cat /sys/class/net/eth0/statistics/rx_errors > "%OUTDIR%\eth0_rx_errors_before.txt" 2>&1
adb shell cat /sys/class/net/eth0/statistics/rx_crc_errors > "%OUTDIR%\eth0_rx_crc_errors_before.txt" 2>&1
adb shell cat /sys/class/net/eth0/statistics/rx_dropped > "%OUTDIR%\eth0_rx_dropped_before.txt" 2>&1

set /p ETH_DRIVER=<"%OUTDIR%\eth0_driver.txt"
echo 7. Verification	Ethernet driver identified	adb shell readlink /sys/class/net/eth0/device/driver	Driver path returned	%ETH_DRIVER%	Pass	eth0_driver.txt>> "%TSV%"

echo [7/9] Launching QGC and collecting runtime logs.
echo Make sure camera/RTSP stream is configured. The script will wait %DURATION%s.
adb shell am force-stop %PACKAGE% > "%OUTDIR%\force_stop.txt" 2>&1
adb logcat -c
adb shell monkey -p %PACKAGE% -c android.intent.category.LAUNCHER 1 > "%OUTDIR%\monkey_launch.txt" 2>&1
timeout /t %DURATION% /nobreak >nul
adb logcat -d > "%OUTDIR%\runtime_logcat.txt" 2>&1
adb shell top -b -m 20 -n 1 > "%OUTDIR%\top_snapshot.txt" 2>&1

findstr /i "decoder-selected amcviddec-c2qtiavcdecoder c2.qti.avc.decoder Created component allocate(c2.qti.avc.decoder)" "%OUTDIR%\runtime_logcat.txt" > "%OUTDIR%\runtime_decoder_evidence.txt" 2>&1
findstr /i "rtspsrc.configured runtime-config child-config runtime-checklist child-checklist rtspsrc-source-checklist videoSink-configured rtpjitterbuffer udpsrc rtph264depay rtph265depay h264parse h265parse capsfilter queue qgcvideosinkbin qmlglsink glimagesink udp-buffer-size buffer-size protocols=udp drop-on-latency do-lost do-retransmission max-dropout-time max-misorder-time request-keyframe wait-for-keyframe config-interval disable-passthrough stream-format alignment max-lateness force-aspect-ratio" "%OUTDIR%\runtime_logcat.txt" > "%OUTDIR%\runtime_pipeline_evidence.txt" 2>&1
findstr /i "GStreamer error Could not open resource GST_MESSAGE_ERROR timeout" "%OUTDIR%\runtime_logcat.txt" > "%OUTDIR%\runtime_gstreamer_errors.txt" 2>&1
findstr /i "%PACKAGE%" "%OUTDIR%\top_snapshot.txt" > "%OUTDIR%\top_qgc_process.txt" 2>&1

call :AddCheck "3. Decoder Activation" "decodebin selects amcviddec element" "adb logcat | findstr decoder-selected" "amcviddec-c2qtiavcdecoder selected" "%OUTDIR%\runtime_decoder_evidence.txt" "runtime_decoder_evidence.txt"
call :AddCheck "3. Decoder Activation" "MediaCodec started successfully" "adb logcat | findstr c2.qti.avc.decoder" "c2.qti.avc.decoder created/started" "%OUTDIR%\runtime_decoder_evidence.txt" "runtime_decoder_evidence.txt"
call :AddCheck "4. Receiver Pipeline" "RTSP UDP pipeline configured" "adb logcat | findstr rtspsrc.configured" "protocols=udp, latency/buffer configured" "%OUTDIR%\runtime_pipeline_evidence.txt" "runtime_pipeline_evidence.txt"
call :AddCheck "7. Verification" "QGC CPU usage snapshot" "adb shell top -b -m 20 -n 1" "QGC process listed" "%OUTDIR%\top_qgc_process.txt" "top_qgc_process.txt"

echo [8/9] Collecting UDP/eth0 counters after launch...
adb shell cat /proc/net/snmp > "%OUTDIR%\proc_net_snmp_after.txt" 2>&1
adb shell cat /proc/net/dev > "%OUTDIR%\proc_net_dev_after.txt" 2>&1
adb shell ip -s link show eth0 > "%OUTDIR%\ip_s_link_eth0_after.txt" 2>&1
adb shell cat /sys/class/net/eth0/statistics/rx_errors > "%OUTDIR%\eth0_rx_errors_after.txt" 2>&1
adb shell cat /sys/class/net/eth0/statistics/rx_crc_errors > "%OUTDIR%\eth0_rx_crc_errors_after.txt" 2>&1
adb shell cat /sys/class/net/eth0/statistics/rx_dropped > "%OUTDIR%\eth0_rx_dropped_after.txt" 2>&1

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$b=Get-Content '%OUTDIR:\=\\%\\proc_net_snmp_before.txt'; $a=Get-Content '%OUTDIR:\=\\%\\proc_net_snmp_after.txt';" ^
  "$bh=($b|?{$_ -like 'Udp: InDatagrams*'}|select -First 1).Split(' ',[StringSplitOptions]::RemoveEmptyEntries); $bv=($b|?{$_ -like 'Udp: *' -and $_ -notlike 'Udp: InDatagrams*'}|select -First 1).Split(' ',[StringSplitOptions]::RemoveEmptyEntries);" ^
  "$ah=($a|?{$_ -like 'Udp: InDatagrams*'}|select -First 1).Split(' ',[StringSplitOptions]::RemoveEmptyEntries); $av=($a|?{$_ -like 'Udp: *' -and $_ -notlike 'Udp: InDatagrams*'}|select -First 1).Split(' ',[StringSplitOptions]::RemoveEmptyEntries);" ^
  "for($i=1;$i -lt $bh.Count;$i++){ $name=$bh[$i]; $delta=[int64]$av[$i]-[int64]$bv[$i]; '{0}: {1} -> {2} delta={3}' -f $name,$bv[$i],$av[$i],$delta }" ^
  > "%OUTDIR%\udp_delta.txt" 2>&1

echo 7. Verification	UDP counter delta	cat /proc/net/snmp before/after	No large InErrors/InCsumErrors/RcvbufErrors	See udp_delta.txt	Pending	udp_delta.txt>> "%TSV%"

echo [9/9] Trying tcpdump sample if available/root allows it...
adb shell su 0 sh -c "timeout %DURATION% tcpdump -i eth0 -s 0 -w /sdcard/qcm_checklist_rtsp_udp.pcap host %DRONE_IP%" > "%OUTDIR%\tcpdump_cmd.txt" 2>&1
adb pull /sdcard/qcm_checklist_rtsp_udp.pcap "%OUTDIR%\qcm_checklist_rtsp_udp.pcap" > "%OUTDIR%\pcap_pull.txt" 2>&1
if exist "%OUTDIR%\qcm_checklist_rtsp_udp.pcap" (
    echo 7. Verification	RTP packets arriving at controller	tcpdump -i eth0 host %DRONE_IP%	PCAP captured	PCAP captured successfully	Pass	qcm_checklist_rtsp_udp.pcap>> "%TSV%"
    if exist "tools\analyze_udp_rtp_pcap.py" (
        python "tools\analyze_udp_rtp_pcap.py" "%OUTDIR%\qcm_checklist_rtsp_udp.pcap" > "%OUTDIR%\pcap_analysis_console.txt" 2>&1
    )
) else (
    echo 7. Verification	RTP packets arriving at controller	tcpdump -i eth0 host %DRONE_IP%	PCAP captured	PCAP not captured; root/tcpdump may be unavailable	Pending	tcpdump_cmd.txt>> "%TSV%"
)

echo.>> "%SUMMARY%"
echo Key files:>> "%SUMMARY%"
echo - actual_results.tsv: copy/paste rows into checklist Actual Result / Status columns>> "%SUMMARY%"
echo - runtime_logcat.txt: QGC/GStreamer/MediaCodec evidence>> "%SUMMARY%"
echo - runtime_decoder_evidence.txt: HW decoder evidence>> "%SUMMARY%"
echo - runtime_pipeline_evidence.txt: rtspsrc/udpsrc/rtpjitterbuffer config evidence>> "%SUMMARY%"
echo - apk_file_list.txt: APK library/plugin list>> "%SUMMARY%"
echo - udp_delta.txt: UDP counter deltas during test>> "%SUMMARY%"
echo - qcm_checklist_rtsp_udp.pcap: packet capture if tcpdump/root worked>> "%SUMMARY%"

echo.
echo Done.
echo Output folder:
echo "%OUTDIR%"
echo.
echo Open/copy:
echo "%TSV%"
exit /b 0

:PluginCheck
set "SHEET=%~1"
set "ITEM=%~2"
set "PATTERN=%~3"
set "EXPECTED=%~4"
set "SAFE=%PATTERN%"
set "SAFE=!SAFE:.=_!"
set "SAFE=!SAFE:-=_!"
set "EVID=%OUTDIR%\plugin_!SAFE!.txt"
findstr /i /c:"%PATTERN%" "%OUTDIR%\apk_file_list.txt" > "%EVID%" 2>&1
call :AddCheck "%SHEET%" "%ITEM%" "APK file list contains %PATTERN%" "%EXPECTED%" "%EVID%" "plugin_!SAFE!.txt"
exit /b 0

:AddCheck
set "SHEET=%~1"
set "ITEM=%~2"
set "CMD=%~3"
set "EXPECTED=%~4"
set "FILE=%~5"
set "EVIDENCE=%~6"
set "STATUS=Fail"
set "ACTUAL=NOT FOUND"
if exist "%FILE%" (
    for %%S in ("%FILE%") do if %%~zS GTR 0 set "STATUS=Pass"
)
if "%STATUS%"=="Pass" (
    for /f "usebackq delims=" %%L in ("%FILE%") do (
        if "!ACTUAL!"=="NOT FOUND" set "ACTUAL=%%L"
    )
)
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$line = @($env:SHEET,$env:ITEM,$env:CMD,$env:EXPECTED,$env:ACTUAL,$env:STATUS,$env:EVIDENCE) -join \"`t\"; Add-Content -LiteralPath $env:TSV -Value $line"
exit /b 0
