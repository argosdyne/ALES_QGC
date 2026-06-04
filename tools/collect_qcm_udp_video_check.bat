@echo off
setlocal

set SCRIPT_DIR=%~dp0
set DURATION=%~1

if "%DURATION%"=="" (
    set DURATION=30
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%collect_qcm_udp_video_check.ps1" -DurationSeconds %DURATION%

endlocal
