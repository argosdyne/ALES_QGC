@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem Download and verify GStreamer Android Universal package for QGC Android build.
rem This does NOT install anything directly on the Android device.
rem It prepares the GStreamer SDK on the Windows build host so QGC can package
rem the required libraries/plugins into the APK.
rem
rem Usage:
rem   tools\setup_gstreamer_android_universal.bat [version] [install_dir]
rem
rem Examples:
rem   tools\setup_gstreamer_android_universal.bat
rem   tools\setup_gstreamer_android_universal.bat 1.28.3 D:\2026\gstreamer-android
rem   tools\setup_gstreamer_android_universal.bat 1.26.11 D:\2026\gstreamer-android

set "VERSION=%~1"
if "%VERSION%"=="" set "VERSION=1.28.3"

set "INSTALL_ROOT=%~2"
if "%INSTALL_ROOT%"=="" set "INSTALL_ROOT=D:\2026\gstreamer-android"

set "PKG_NAME=gstreamer-1.0-android-universal-%VERSION%.tar.xz"
set "URL=https://gstreamer.freedesktop.org/data/pkg/android/%VERSION%/%PKG_NAME%"
set "OUTDIR=%INSTALL_ROOT%\%VERSION%"
set "PKG_PATH=%OUTDIR%\%PKG_NAME%"
set "LOG=%OUTDIR%\setup_gstreamer_android_%VERSION%.log"
set "RESULTS=%OUTDIR%\actual_results_gstreamer_build.tsv"

echo GStreamer Android Universal setup
echo Version: %VERSION%
echo Install root: %INSTALL_ROOT%
echo Output: %OUTDIR%
echo URL: %URL%
echo.

mkdir "%OUTDIR%" >nul 2>&1

echo GStreamer Android Universal setup > "%LOG%"
echo Version=%VERSION%>> "%LOG%"
echo URL=%URL%>> "%LOG%"
echo OUTDIR=%OUTDIR%>> "%LOG%"
echo.>> "%LOG%"

echo Sheet	Item	Command	Expected	Actual Result / Observation	Status	Notes > "%RESULTS%"

echo [1/5] Downloading package...
if not exist "%PKG_PATH%" (
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
      "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri '%URL%' -OutFile '%PKG_PATH%'"
    if errorlevel 1 (
        echo Download failed. See: "%LOG%"
        echo Download failed from %URL%>> "%LOG%"
        call :AddResult "2. GStreamer Build" "Android universal binary downloaded" "Invoke-WebRequest %URL%" "Tarball obtained from official GStreamer site" "Download failed: %URL%" "Fail" "Check version URL or network."
        exit /b 1
    )
) else (
    echo Package already exists: "%PKG_PATH%"
)

for %%F in ("%PKG_PATH%") do set "PKG_SIZE=%%~zF"
call :AddResult "2. GStreamer Build" "Android universal binary downloaded" "Download %PKG_NAME%" "Tarball obtained from official GStreamer site" "%PKG_NAME% downloaded, size=%PKG_SIZE% bytes" "Pass" "%URL%"

echo [2/5] Downloading sha256 if available...
set "SHA_PATH=%PKG_PATH%.sha256sum"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ProgressPreference='SilentlyContinue'; try { Invoke-WebRequest -Uri '%URL%.sha256sum' -OutFile '%SHA_PATH%' } catch { exit 2 }"
if exist "%SHA_PATH%" (
    echo SHA256 file downloaded: "%SHA_PATH%">> "%LOG%"
    call :AddResult "2. GStreamer Build" "Package checksum file downloaded" "Download %PKG_NAME%.sha256sum" "sha256sum file obtained" "%PKG_NAME%.sha256sum downloaded" "Pass" "Optional integrity file."
) else (
    call :AddResult "2. GStreamer Build" "Package checksum file downloaded" "Download %PKG_NAME%.sha256sum" "sha256sum file obtained" "sha256sum not downloaded" "Pending" "Optional; not required for extraction."
)

echo [3/5] Extracting package...
set "EXTRACT_MARKER=%OUTDIR%\.extract_done"
if not exist "%EXTRACT_MARKER%" (
    tar -xf "%PKG_PATH%" -C "%OUTDIR%" >> "%LOG%" 2>&1
    if errorlevel 1 (
        echo Extract failed. See: "%LOG%"
        call :AddResult "2. GStreamer Build" "Binary extracted with arm64 folder present" "tar -xf %PKG_NAME%" "arm64 folder with lib/include subfolders" "tar extraction failed" "Fail" "%LOG%"
        exit /b 1
    )
    echo done > "%EXTRACT_MARKER%"
) else (
    echo Package already extracted.
)

echo [4/5] Locating arm64 folder...
set "ARM64_DIR="
for /f "usebackq delims=" %%D in (`powershell -NoProfile -Command "Get-ChildItem -Path '%OUTDIR%' -Recurse -Directory -Filter arm64 | Select-Object -First 1 -ExpandProperty FullName"`) do set "ARM64_DIR=%%D"

if "%ARM64_DIR%"=="" (
    call :AddResult "2. GStreamer Build" "Binary extracted with arm64 folder present" "Find arm64 folder" "arm64 folder with lib/include subfolders" "arm64 folder NOT FOUND under %OUTDIR%" "Fail" "Extraction/package layout issue."
    echo ERROR: arm64 folder not found.
    exit /b 1
)

call :AddResult "2. GStreamer Build" "Binary extracted with arm64 folder present" "Find arm64 folder" "arm64 folder with lib/include subfolders" "%ARM64_DIR%" "Pass" "Use this as GST_ROOT/arm64 reference."

echo [5/5] Checking required plugins...
call :CheckFile "androidmedia plugin in binary (CRITICAL)" "libgstandroidmedia.so" "libgstandroidmedia.so listed"
call :CheckFile "RTP plugin in binary" "libgstrtp.so" "libgstrtp.so listed"
call :CheckFile "RTP manager plugin in binary" "libgstrtpmanager.so" "libgstrtpmanager.so listed"
call :CheckFile "UDP plugin in binary" "libgstudp.so" "libgstudp.so listed"
call :CheckFile "Video parsers plugin in binary" "libgstvideoparsersbad.so" "libgstvideoparsersbad.so listed"
call :CheckFile "QML GL sink plugin in binary" "libgstqmlgl.so" "libgstqmlgl.so listed"
call :CheckFile "OpenGL plugin in binary" "libgstopengl.so" "libgstopengl.so listed"

echo.>> "%LOG%"
echo Suggested checklist values:>> "%LOG%"
echo GStreamer version selected: %VERSION%>> "%LOG%"
echo Android universal binary downloaded: %PKG_PATH%>> "%LOG%"
echo Binary extracted with arm64 folder present: %ARM64_DIR%>> "%LOG%"
echo.
echo Done.
echo Results:
echo "%RESULTS%"
echo.
echo Use this folder for QGC build configuration:
echo "%OUTDIR%"
echo.
echo Important: rebuild QGC APK after pointing the project to this GStreamer SDK.
exit /b 0

:CheckFile
set "ITEM=%~1"
set "FILE=%~2"
set "EXPECTED=%~3"
set "FOUND="
for /f "usebackq delims=" %%F in (`powershell -NoProfile -Command "Get-ChildItem -Path '%OUTDIR%' -Recurse -File -Filter '%FILE%' | Select-Object -First 1 -ExpandProperty FullName"`) do set "FOUND=%%F"
if "%FOUND%"=="" (
    call :AddResult "2. GStreamer Build" "%ITEM%" "Get-ChildItem -Recurse -Filter %FILE%" "%EXPECTED%" "%FILE% NOT FOUND" "Fail" "If missing, use another package or rebuild via Cerbero."
) else (
    call :AddResult "2. GStreamer Build" "%ITEM%" "Get-ChildItem -Recurse -Filter %FILE%" "%EXPECTED%" "%FOUND%" "Pass" "Package contains required plugin."
)
exit /b 0

:AddResult
set "SHEET=%~1"
set "ITEM=%~2"
set "CMD=%~3"
set "EXPECTED=%~4"
set "ACTUAL=%~5"
set "STATUS=%~6"
set "NOTES=%~7"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$line = @($env:SHEET,$env:ITEM,$env:CMD,$env:EXPECTED,$env:ACTUAL,$env:STATUS,$env:NOTES) -join \"`t\"; Add-Content -LiteralPath '%RESULTS%' -Value $line"
exit /b 0
