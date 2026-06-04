@echo off
setlocal EnableExtensions

set DURATION=%~1
set CAMERA_HOST=%~2
set IFACE=%~3

if "%DURATION%"=="" set DURATION=60
if "%CAMERA_HOST%"=="" set CAMERA_HOST=192.168.2.119
if "%IFACE%"=="" set IFACE=eth0

for /f "tokens=1-4 delims=/ " %%a in ("%date%") do set DATE_PART=%%d%%b%%c
for /f "tokens=1-3 delims=:." %%a in ("%time%") do set TIME_PART=%%a%%b%%c
set TIME_PART=%TIME_PART: =0%

set OUTDIR=%CD%\android_net_compare_%DATE_PART%_%TIME_PART%
mkdir "%OUTDIR%" >nul 2>nul

echo Output directory: %OUTDIR%
echo DurationSeconds=%DURATION%>"%OUTDIR%\summary.txt"
echo CameraHost=%CAMERA_HOST%>>"%OUTDIR%\summary.txt"
echo Interface=%IFACE%>>"%OUTDIR%\summary.txt"
echo.>>"%OUTDIR%\summary.txt"

adb devices > "%OUTDIR%\adb_devices.txt" 2>&1
adb shell getprop ro.product.manufacturer > "%OUTDIR%\device_manufacturer.txt" 2>&1
adb shell getprop ro.product.model > "%OUTDIR%\device_model.txt" 2>&1
adb shell getprop ro.hardware > "%OUTDIR%\ro_hardware.txt" 2>&1
adb shell getprop ro.board.platform > "%OUTDIR%\ro_board_platform.txt" 2>&1
adb shell getprop ro.build.fingerprint > "%OUTDIR%\ro_build_fingerprint.txt" 2>&1

call :collect_static

echo Collecting before counters...
call :collect_snapshot before

echo Capturing traffic if tcpdump is available...
call :capture_pcap

echo Collecting after counters...
call :collect_snapshot after

echo Creating summary...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$out='%OUTDIR%';" ^
  "$summary=Join-Path $out 'summary.txt';" ^
  "function AddFile($title,$file){ Add-Content $summary ('==== '+$title+' ===='); if(Test-Path (Join-Path $out $file)){ Get-Content (Join-Path $out $file) | Add-Content $summary } }" ^
  "AddFile 'device' 'device_manufacturer.txt'; AddFile 'model' 'device_model.txt'; AddFile 'hardware' 'ro_hardware.txt'; AddFile 'board platform' 'ro_board_platform.txt';" ^
  "AddFile 'sysctl net core' 'sysctl_net_core.txt';" ^
  "AddFile 'ethtool -k' 'ethtool_k.txt';" ^
  "AddFile 'ethtool -S' 'ethtool_S.txt';" ^
  "AddFile 'features' 'net_features.txt';" ^
  "AddFile 'before eth stats' 'before_eth_stats.txt'; AddFile 'after eth stats' 'after_eth_stats.txt';" ^
  "AddFile 'before ip -s link' 'before_ip_s_link.txt'; AddFile 'after ip -s link' 'after_ip_s_link.txt';" ^
  "AddFile 'UDP before' 'before_udp_only.txt'; AddFile 'UDP after' 'after_udp_only.txt';" ^
  "AddFile 'tcpdump mode' 'tcpdump_capture.txt'; AddFile 'tcpdump pull' 'tcpdump_pull.txt';"

echo Done.
echo Send this file:
echo %OUTDIR%\summary.txt
if exist "%OUTDIR%\capture_%IFACE%.pcap" (
    echo PCAP captured:
    echo %OUTDIR%\capture_%IFACE%.pcap
)

endlocal
exit /b 0

:collect_static
adb shell cat /proc/sys/net/core/rmem_max > "%OUTDIR%\rmem_max.txt" 2>&1
adb shell cat /proc/sys/net/core/rmem_default > "%OUTDIR%\rmem_default.txt" 2>&1
adb shell cat /proc/sys/net/core/netdev_max_backlog > "%OUTDIR%\netdev_max_backlog.txt" 2>&1
(
    echo rmem_max
    type "%OUTDIR%\rmem_max.txt"
    echo rmem_default
    type "%OUTDIR%\rmem_default.txt"
    echo netdev_max_backlog
    type "%OUTDIR%\netdev_max_backlog.txt"
) > "%OUTDIR%\sysctl_net_core.txt"

adb shell "su 0 sh -c 'ethtool -k %IFACE%'" > "%OUTDIR%\ethtool_k_su0.txt" 2>&1
adb shell "su root sh -c 'ethtool -k %IFACE%'" > "%OUTDIR%\ethtool_k_suroot.txt" 2>&1
adb shell "ethtool -k %IFACE%" > "%OUTDIR%\ethtool_k_shell.txt" 2>&1
copy /y "%OUTDIR%\ethtool_k_shell.txt" "%OUTDIR%\ethtool_k.txt" >nul
findstr /i "rx-checksumming tx-checksumming scatter gather offload" "%OUTDIR%\ethtool_k_su0.txt" >nul 2>nul
if %errorlevel%==0 copy /y "%OUTDIR%\ethtool_k_su0.txt" "%OUTDIR%\ethtool_k.txt" >nul
findstr /i "rx-checksumming tx-checksumming scatter gather offload" "%OUTDIR%\ethtool_k_suroot.txt" >nul 2>nul
if %errorlevel%==0 copy /y "%OUTDIR%\ethtool_k_suroot.txt" "%OUTDIR%\ethtool_k.txt" >nul

adb shell "su 0 sh -c 'ethtool -S %IFACE%'" > "%OUTDIR%\ethtool_S_su0.txt" 2>&1
adb shell "su root sh -c 'ethtool -S %IFACE%'" > "%OUTDIR%\ethtool_S_suroot.txt" 2>&1
adb shell "ethtool -S %IFACE%" > "%OUTDIR%\ethtool_S_shell.txt" 2>&1
copy /y "%OUTDIR%\ethtool_S_shell.txt" "%OUTDIR%\ethtool_S.txt" >nul
findstr /i "rx tx crc err drop checksum fifo" "%OUTDIR%\ethtool_S_su0.txt" >nul 2>nul
if %errorlevel%==0 copy /y "%OUTDIR%\ethtool_S_su0.txt" "%OUTDIR%\ethtool_S.txt" >nul
findstr /i "rx tx crc err drop checksum fifo" "%OUTDIR%\ethtool_S_suroot.txt" >nul 2>nul
if %errorlevel%==0 copy /y "%OUTDIR%\ethtool_S_suroot.txt" "%OUTDIR%\ethtool_S.txt" >nul

adb shell cat /sys/class/net/%IFACE%/features > "%OUTDIR%\net_features.txt" 2>&1
adb shell cat /sys/class/net/%IFACE%/queues/rx-0/rps_cpus > "%OUTDIR%\rps_cpus.txt" 2>&1
exit /b 0

:collect_snapshot
set PREFIX=%~1
(
    echo rx_packets
    adb shell cat /sys/class/net/%IFACE%/statistics/rx_packets
    echo rx_bytes
    adb shell cat /sys/class/net/%IFACE%/statistics/rx_bytes
    echo rx_errors
    adb shell cat /sys/class/net/%IFACE%/statistics/rx_errors
    echo rx_crc_errors
    adb shell cat /sys/class/net/%IFACE%/statistics/rx_crc_errors
    echo rx_dropped
    adb shell cat /sys/class/net/%IFACE%/statistics/rx_dropped
    echo rx_fifo_errors
    adb shell cat /sys/class/net/%IFACE%/statistics/rx_fifo_errors
    echo rx_frame_errors
    adb shell cat /sys/class/net/%IFACE%/statistics/rx_frame_errors
    echo rx_missed_errors
    adb shell cat /sys/class/net/%IFACE%/statistics/rx_missed_errors
    echo tx_errors
    adb shell cat /sys/class/net/%IFACE%/statistics/tx_errors
) > "%OUTDIR%\%PREFIX%_eth_stats.txt" 2>&1

adb shell ip -s link show %IFACE% > "%OUTDIR%\%PREFIX%_ip_s_link.txt" 2>&1
adb shell cat /proc/net/snmp > "%OUTDIR%\%PREFIX%_proc_net_snmp.txt" 2>&1
adb shell cat /proc/net/snmp | findstr Udp > "%OUTDIR%\%PREFIX%_udp_only.txt" 2>&1
adb shell cat /proc/net/dev > "%OUTDIR%\%PREFIX%_proc_net_dev.txt" 2>&1
adb shell top -b -m 20 -n 1 > "%OUTDIR%\%PREFIX%_top.txt" 2>&1
exit /b 0

:capture_pcap
adb shell "which tcpdump" > "%OUTDIR%\tcpdump_which_shell.txt" 2>&1
adb shell "su 0 sh -c 'which tcpdump'" > "%OUTDIR%\tcpdump_which_su0.txt" 2>&1
adb shell "su root sh -c 'which tcpdump'" > "%OUTDIR%\tcpdump_which_suroot.txt" 2>&1

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
    adb shell "su 0 sh -c 'rm -f /sdcard/android_net_compare.pcap'" >> "%OUTDIR%\tcpdump_capture.txt" 2>&1
    adb shell "su 0 sh -c 'timeout %DURATION% tcpdump -i %IFACE% -w /sdcard/android_net_compare.pcap host %CAMERA_HOST%'" >> "%OUTDIR%\tcpdump_capture.txt" 2>&1
    adb pull /sdcard/android_net_compare.pcap "%OUTDIR%\capture_%IFACE%.pcap" > "%OUTDIR%\tcpdump_pull.txt" 2>&1
) else if "%TCPDUMP_MODE%"=="suroot" (
    adb shell "su root sh -c 'rm -f /sdcard/android_net_compare.pcap'" >> "%OUTDIR%\tcpdump_capture.txt" 2>&1
    adb shell "su root sh -c 'timeout %DURATION% tcpdump -i %IFACE% -w /sdcard/android_net_compare.pcap host %CAMERA_HOST%'" >> "%OUTDIR%\tcpdump_capture.txt" 2>&1
    adb pull /sdcard/android_net_compare.pcap "%OUTDIR%\capture_%IFACE%.pcap" > "%OUTDIR%\tcpdump_pull.txt" 2>&1
) else if "%TCPDUMP_MODE%"=="shell" (
    adb shell "rm -f /sdcard/android_net_compare.pcap" >> "%OUTDIR%\tcpdump_capture.txt" 2>&1
    adb shell "timeout %DURATION% tcpdump -i %IFACE% -w /sdcard/android_net_compare.pcap host %CAMERA_HOST%" >> "%OUTDIR%\tcpdump_capture.txt" 2>&1
    adb pull /sdcard/android_net_compare.pcap "%OUTDIR%\capture_%IFACE%.pcap" > "%OUTDIR%\tcpdump_pull.txt" 2>&1
) else (
    echo tcpdump not available or no usable root. Waiting %DURATION%s without pcap. >> "%OUTDIR%\tcpdump_capture.txt"
    timeout /t %DURATION% /nobreak >nul
)
exit /b 0
