# Verify installed QGC APK contains DPC kiosk Java bridge.
# Usage: connect device via USB, then run:
#   powershell -ExecutionPolicy Bypass -File scripts\verify-qgc-dpc-apk.ps1

$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
if (-not (Test-Path $adb)) {
    Write-Host "adb not found at $adb"
    exit 1
}

Write-Host "Waiting for device..."
& $adb wait-for-device | Out-Null

$pkg = "org.Agosdyne.alesqgc"
$apkPath = & $adb shell pm path $pkg 2>$null
if (-not $apkPath) {
    Write-Host "QGC package not installed: $pkg"
    exit 1
}

$apkPath = ($apkPath -replace "^package:", "").Trim()
$localApk = Join-Path $env:TEMP "alesqgc-verify.apk"
& $adb pull $apkPath $localApk | Out-Null

$aapt = Get-ChildItem -Path "$env:LOCALAPPDATA\Android\Sdk\build-tools" -Recurse -Filter "aapt.exe" |
    Sort-Object FullName -Descending | Select-Object -First 1
if (-not $aapt) {
    Write-Host "aapt not found"
    exit 1
}

Write-Host "=== QGC APK checks ==="
& $aapt.FullName dump badging $localApk | Select-String "package:|targetSdkVersion"

$manifest = & $aapt.FullName dump xmltree $localApk AndroidManifest.xml 2>&1 | Out-String
$checks = @{
    "DpcKioskStateReceiver" = ($manifest -match "DpcKioskStateReceiver")
    "QgcBootReceiver"       = ($manifest -match "QgcBootReceiver")
    "QGCApplication"        = ($manifest -match "QGCApplication")
    "RECEIVE_BOOT_COMPLETED"= ($manifest -match "RECEIVE_BOOT_COMPLETED")
}

foreach ($key in $checks.Keys) {
    $status = if ($checks[$key]) { "OK" } else { "MISSING" }
    Write-Host ("{0,-24} {1}" -f $key, $status)
}

Write-Host ""
Write-Host "=== Live log test (5s) ==="
Write-Host "Send REQUEST_KIOSK_STATE to DPC..."
& $adb logcat -c | Out-Null
& $adb shell am broadcast -a com.easygripper.dpc.action.REQUEST_KIOSK_STATE -n com.easygripper.dpc/.DpcControlReceiver | Out-Null
Start-Sleep -Seconds 2
& $adb logcat -d -s DpcControlReceiver:I QGC_QGCActivity:E QGC_DpcKioskStateReceiver:E QGC_QGCApplication:E | Select-Object -Last 30

Write-Host ""
Write-Host "If receivers are MISSING -> QGC Android Java was not rebuilt into APK."
Write-Host "If DPC receives request but QGC has no logs -> QGC receive path broken."
