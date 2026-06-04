@echo off
setlocal EnableExtensions

set DURATION=%~1
set CAMERA_HOST=%~2

if "%DURATION%"=="" set DURATION=30
if "%CAMERA_HOST%"=="" set CAMERA_HOST=192.168.2.119

for /f "tokens=1-4 delims=/ " %%a in ("%date%") do set DATE_PART=%%d%%b%%c
for /f "tokens=1-3 delims=:." %%a in ("%time%") do set TIME_PART=%%a%%b%%c
set TIME_PART=%TIME_PART: =0%

set OUTDIR=%CD%\qcm_eth_udp_diag_%DATE_PART%_%TIME_PART%
mkdir "%OUTDIR%" >nul 2>nul

echo Output directory: %OUTDIR%
echo DurationSeconds=%DURATION%>"%OUTDIR%\summary.txt"
echo CameraHost=%CAMERA_HOST%>>"%OUTDIR%\summary.txt"
echo.>>"%OUTDIR%\summary.txt"

adb devices > "%OUTDIR%\adb_devices.txt" 2>&1
adb shell getprop ro.product.manufacturer > "%OUTDIR%\device_manufacturer.txt" 2>&1
adb shell getprop ro.product.model > "%OUTDIR%\device_model.txt" 2>&1

echo Collecting before counters...
call :collect before

echo Trying tcpdump capture if root and tcpdump are available...
adb shell "which tcpdump" > "%OUTDIR%\tcpdump_which_shell.txt" 2>&1
adb shell "su 0 sh -c 'which tcpdump'" > "%OUTDIR%\tcpdump_which_su0.txt" 2>&1
adb shell "su root sh -c 'which tcpdump'" > "%OUTDIR%\tcpdump_which_suroot.txt" 2>&1
copy /y "%OUTDIR%\tcpdump_which_shell.txt" "%OUTDIR%\tcpdump_which.txt" >nul

set TCPDUMP_MODE=none
findstr /i "tcpdump" "%OUTDIR%\tcpdump_which_su0.txt" >nul 2>nul
if %errorlevel%==0 set TCPDUMP_MODE=su0
if "%TCPDUMP_MODE%"=="none" (
    findstr /i "tcpdump" "%OUTDIR%\tcpdump_which_suroot.txt" >nul 2>nul
    if %errorlevel%==0 set TCPDUMP_MODE=suroot
)
if "%TCPDUMP_MODE%"=="none" (
    findstr /i "tcpdump" "%OUTDIR%\tcpdump_which_shell.txt" >nul 2>nul
    if %errorlevel%==0 set TCPDUMP_MODE=shell
)

echo TCPDUMP_MODE=%TCPDUMP_MODE% > "%OUTDIR%\tcpdump_capture.txt"
if "%TCPDUMP_MODE%"=="su0" (
    echo tcpdump found via su 0. Capturing %DURATION%s...
    adb shell "su 0 sh -c 'rm -f /sdcard/qcm_rtsp_udp.pcap'" >> "%OUTDIR%\tcpdump_capture.txt" 2>&1
    adb shell "su 0 sh -c 'timeout %DURATION% tcpdump -i eth0 -w /sdcard/qcm_rtsp_udp.pcap host %CAMERA_HOST%'" >> "%OUTDIR%\tcpdump_capture.txt" 2>&1
    adb pull /sdcard/qcm_rtsp_udp.pcap "%OUTDIR%\qcm_rtsp_udp.pcap" > "%OUTDIR%\tcpdump_pull.txt" 2>&1
) else if "%TCPDUMP_MODE%"=="suroot" (
    echo tcpdump found via su root. Capturing %DURATION%s...
    adb shell "su root sh -c 'rm -f /sdcard/qcm_rtsp_udp.pcap'" >> "%OUTDIR%\tcpdump_capture.txt" 2>&1
    adb shell "su root sh -c 'timeout %DURATION% tcpdump -i eth0 -w /sdcard/qcm_rtsp_udp.pcap host %CAMERA_HOST%'" >> "%OUTDIR%\tcpdump_capture.txt" 2>&1
    adb pull /sdcard/qcm_rtsp_udp.pcap "%OUTDIR%\qcm_rtsp_udp.pcap" > "%OUTDIR%\tcpdump_pull.txt" 2>&1
) else if "%TCPDUMP_MODE%"=="shell" (
    echo tcpdump found without su. Capturing %DURATION%s...
    adb shell "rm -f /sdcard/qcm_rtsp_udp.pcap" >> "%OUTDIR%\tcpdump_capture.txt" 2>&1
    adb shell "timeout %DURATION% tcpdump -i eth0 -w /sdcard/qcm_rtsp_udp.pcap host %CAMERA_HOST%" >> "%OUTDIR%\tcpdump_capture.txt" 2>&1
    adb pull /sdcard/qcm_rtsp_udp.pcap "%OUTDIR%\qcm_rtsp_udp.pcap" > "%OUTDIR%\tcpdump_pull.txt" 2>&1
) else (
    echo tcpdump not available or no usable root. Skipping pcap capture. >> "%OUTDIR%\tcpdump_capture.txt"
    timeout /t %DURATION% /nobreak >nul
)

echo Collecting after counters...
call :collect after

echo Creating summary...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$out='%OUTDIR%';" ^
  "$files=@('before_eth_stats.txt','after_eth_stats.txt','before_ip_s_link_eth0.txt','after_ip_s_link_eth0.txt','before_proc_net_snmp.txt','after_proc_net_snmp.txt','tcpdump_which.txt','tcpdump_capture.txt','tcpdump_pull.txt');" ^
  "Add-Content -Path (Join-Path $out 'summary.txt') -Value '==== eth statistics before/after ====';" ^
  "Get-Content (Join-Path $out 'before_eth_stats.txt') | Add-Content (Join-Path $out 'summary.txt');" ^
  "Add-Content -Path (Join-Path $out 'summary.txt') -Value '---- after ----';" ^
  "Get-Content (Join-Path $out 'after_eth_stats.txt') | Add-Content (Join-Path $out 'summary.txt');" ^
  "Add-Content -Path (Join-Path $out 'summary.txt') -Value '==== ip -s link eth0 before ====';" ^
  "Get-Content (Join-Path $out 'before_ip_s_link_eth0.txt') | Add-Content (Join-Path $out 'summary.txt');" ^
  "Add-Content -Path (Join-Path $out 'summary.txt') -Value '==== ip -s link eth0 after ====';" ^
  "Get-Content (Join-Path $out 'after_ip_s_link_eth0.txt') | Add-Content (Join-Path $out 'summary.txt');" ^
  "Add-Content -Path (Join-Path $out 'summary.txt') -Value '==== UDP before ====';" ^
  "Get-Content (Join-Path $out 'before_proc_net_snmp.txt') | Select-String '^Udp:' | %% { $_.Line } | Add-Content (Join-Path $out 'summary.txt');" ^
  "Add-Content -Path (Join-Path $out 'summary.txt') -Value '==== UDP after ====';" ^
  "Get-Content (Join-Path $out 'after_proc_net_snmp.txt') | Select-String '^Udp:' | %% { $_.Line } | Add-Content (Join-Path $out 'summary.txt');" ^
  "Add-Content -Path (Join-Path $out 'summary.txt') -Value '==== tcpdump ====';" ^
  "Add-Content -Path (Join-Path $out 'summary.txt') -Value '-- shell --';" ^
  "Get-Content (Join-Path $out 'tcpdump_which_shell.txt') -ErrorAction SilentlyContinue | Add-Content (Join-Path $out 'summary.txt');" ^
  "Add-Content -Path (Join-Path $out 'summary.txt') -Value '-- su0 --';" ^
  "Get-Content (Join-Path $out 'tcpdump_which_su0.txt') -ErrorAction SilentlyContinue | Add-Content (Join-Path $out 'summary.txt');" ^
  "Add-Content -Path (Join-Path $out 'summary.txt') -Value '-- suroot --';" ^
  "Get-Content (Join-Path $out 'tcpdump_which_suroot.txt') -ErrorAction SilentlyContinue | Add-Content (Join-Path $out 'summary.txt');" ^
  "Get-Content (Join-Path $out 'tcpdump_capture.txt') | Add-Content (Join-Path $out 'summary.txt');" ^
  "Get-Content (Join-Path $out 'tcpdump_pull.txt') -ErrorAction SilentlyContinue | Add-Content (Join-Path $out 'summary.txt');"

echo Done.
echo Send this file:
echo %OUTDIR%\summary.txt
if exist "%OUTDIR%\qcm_rtsp_udp.pcap" (
    echo PCAP captured:
    echo %OUTDIR%\qcm_rtsp_udp.pcap
)

endlocal
exit /b 0

:collect
set PREFIX=%~1
(
    echo rx_errors
    adb shell cat /sys/class/net/eth0/statistics/rx_errors
    echo rx_crc_errors
    adb shell cat /sys/class/net/eth0/statistics/rx_crc_errors
    echo rx_dropped
    adb shell cat /sys/class/net/eth0/statistics/rx_dropped
    echo rx_fifo_errors
    adb shell cat /sys/class/net/eth0/statistics/rx_fifo_errors
    echo rx_frame_errors
    adb shell cat /sys/class/net/eth0/statistics/rx_frame_errors
    echo rx_missed_errors
    adb shell cat /sys/class/net/eth0/statistics/rx_missed_errors
    echo tx_errors
    adb shell cat /sys/class/net/eth0/statistics/tx_errors
) > "%OUTDIR%\%PREFIX%_eth_stats.txt" 2>&1

adb shell ip -s link show eth0 > "%OUTDIR%\%PREFIX%_ip_s_link_eth0.txt" 2>&1
adb shell cat /proc/net/snmp > "%OUTDIR%\%PREFIX%_proc_net_snmp.txt" 2>&1
adb shell cat /proc/net/dev > "%OUTDIR%\%PREFIX%_proc_net_dev.txt" 2>&1
adb shell top -b -m 20 -n 1 > "%OUTDIR%\%PREFIX%_top.txt" 2>&1
exit /b 0
