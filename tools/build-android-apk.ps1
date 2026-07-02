<#
Build Android APK:
  powershell -NoProfile -ExecutionPolicy Bypass -File tools\build-android-apk.ps1 -Config debug

Build signed release APK:
  powershell -NoProfile -ExecutionPolicy Bypass -File tools\build-android-apk.ps1 `
    -Config release `
    -Keystore D:\keys\ales-qgc.jks `
    -KeyAlias ales-qgc `
    -StorePass $env:ANDROID_STORE_PASSWORD `
    -KeyPass $env:ANDROID_KEY_PASSWORD

Equivalent environment variables:
  ANDROID_KEYSTORE, ANDROID_KEY_ALIAS, ANDROID_STORE_PASSWORD, ANDROID_KEY_PASSWORD, ANDROID_KEYSTORE_TYPE
#>

param(
    [ValidateSet("debug", "release")]
    [string]$Config = "debug",

    [string]$Abi = "arm64-v8a",
    [string]$BuildDir = "build-android",
    [string]$QtAndroidRoot = $env:QT_ANDROID_ROOT,
    [string]$AndroidSdkRoot = $(if ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } else { $env:ANDROID_SDK }),
    [string]$AndroidNdkRoot = $(if ($env:ANDROID_NDK_ROOT) { $env:ANDROID_NDK_ROOT } else { $env:ANDROID_NDK }),
    [int]$Jobs = 8,
    [int]$AndroidApi = 28,
    [string]$Keystore = $env:ANDROID_KEYSTORE,
    [string]$KeyAlias = $env:ANDROID_KEY_ALIAS,
    [string]$StorePass = $env:ANDROID_STORE_PASSWORD,
    [string]$KeyPass = $env:ANDROID_KEY_PASSWORD,
    [string]$StoreType = $env:ANDROID_KEYSTORE_TYPE,
    [string]$TimestampAuthority = "http://timestamp.digicert.com",

    [switch]$UseCMake,
    [switch]$Clean,
    [switch]$Install,
    [switch]$CheckOnly
)

$ErrorActionPreference = "Stop"

function Resolve-RepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Find-Executable {
    param(
        [string]$Name,
        [string[]]$Hints = @()
    )

    foreach ($hint in $Hints) {
        if ([string]::IsNullOrWhiteSpace($hint)) {
            continue
        }
        $candidate = Join-Path $hint $Name
        if (Test-Path $candidate) {
            return (Resolve-Path $candidate).Path
        }
    }

    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    return $null
}

function Find-QtAndroidRoot {
    param([string]$ExplicitRoot)

    if ($ExplicitRoot -and (Test-Path (Join-Path $ExplicitRoot "bin\qmake.exe"))) {
        return (Resolve-Path $ExplicitRoot).Path
    }

    $qmake = Find-Executable "qmake.exe"
    if ($qmake) {
        return (Resolve-Path (Join-Path (Split-Path $qmake -Parent) "..")).Path
    }

    $candidates = @(
        "D:\Programs\Qt\5.15.2\android",
        "C:\Qt\5.15.2\android",
        "D:\Qt\5.15.2\android",
        "C:\Programs\Qt\5.15.2\android"
    )
    foreach ($candidate in $candidates) {
        if (Test-Path (Join-Path $candidate "bin\qmake.exe")) {
            return (Resolve-Path $candidate).Path
        }
    }

    return $null
}

function Find-AndroidSdkRoot {
    param([string]$ExplicitRoot)

    if ($ExplicitRoot -and (Test-Path $ExplicitRoot)) {
        return (Resolve-Path $ExplicitRoot).Path
    }

    $candidates = @(
        "D:\Programs\Android\SDK",
        "$env:LOCALAPPDATA\Android\Sdk",
        "C:\Android\Sdk"
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) {
            return (Resolve-Path $candidate).Path
        }
    }

    return $null
}

function Find-AndroidNdkRoot {
    param(
        [string]$ExplicitRoot,
        [string]$SdkRoot
    )

    if ($ExplicitRoot -and (Test-Path $ExplicitRoot)) {
        return (Resolve-Path $ExplicitRoot).Path
    }

    if ($SdkRoot) {
        $ndkRoot = Join-Path $SdkRoot "ndk"
        if (Test-Path $ndkRoot) {
            $preferred = Join-Path $ndkRoot "21.3.6528147"
            if (Test-Path $preferred) {
                return (Resolve-Path $preferred).Path
            }

            $versions = Get-ChildItem -Path $ndkRoot -Directory -ErrorAction SilentlyContinue |
                Sort-Object Name -Descending
            if ($versions.Count -gt 0) {
                return $versions[0].FullName
            }
        }
    }

    return $null
}

function Require-Path {
    param(
        [string]$Label,
        [string]$Path
    )

    if (-not $Path -or -not (Test-Path $Path)) {
        throw "$Label not found. Set the matching parameter or environment variable."
    }
    return (Resolve-Path $Path).Path
}

function Invoke-Step {
    param(
        [string]$Title,
        [string]$FilePath,
        [string[]]$Arguments,
        [string]$WorkingDirectory,
        [string[]]$SensitiveValues = @()
    )

    Write-Host ""
    Write-Host "==> $Title"
    $displayArguments = @()
    foreach ($argument in $Arguments) {
        $displayArgument = $argument
        foreach ($sensitiveValue in $SensitiveValues) {
            if (-not [string]::IsNullOrEmpty($sensitiveValue)) {
                $displayArgument = $displayArgument.Replace($sensitiveValue, "********")
            }
        }
        $displayArguments += $displayArgument
    }
    Write-Host "$FilePath $($displayArguments -join ' ')"

    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Title failed with exit code $LASTEXITCODE"
    }
}

$repoRoot = Resolve-RepoRoot
$buildRoot = if ([System.IO.Path]::IsPathRooted($BuildDir)) { $BuildDir } else { Join-Path $repoRoot $BuildDir }
$qtRoot = Find-QtAndroidRoot $QtAndroidRoot
$sdkRoot = Find-AndroidSdkRoot $AndroidSdkRoot
$ndkRoot = Find-AndroidNdkRoot $AndroidNdkRoot $sdkRoot

$qtRoot = Require-Path "Qt for Android root" $qtRoot
$sdkRoot = Require-Path "Android SDK root" $sdkRoot
$ndkRoot = Require-Path "Android NDK root" $ndkRoot

$env:ANDROID_SDK_ROOT = $sdkRoot
$env:ANDROID_SDK = $sdkRoot
$env:ANDROID_NDK_ROOT = $ndkRoot
$env:ANDROID_NDK = $ndkRoot

$qmake = Find-Executable "qmake.exe" @((Join-Path $qtRoot "bin"))
$make = Find-Executable "make.exe" @(
    (Join-Path $ndkRoot "prebuilt\windows-x86_64\bin"),
    (Join-Path $ndkRoot "prebuilt\windows\bin")
)
$cmake = Find-Executable "cmake.exe"
$ninja = Find-Executable "ninja.exe"

Write-Host "Repo:        $repoRoot"
Write-Host "Build:       $buildRoot"
Write-Host "Qt Android:  $qtRoot"
Write-Host "Android SDK: $sdkRoot"
Write-Host "Android NDK: $ndkRoot"
Write-Host "ABI:         $Abi"
Write-Host "Config:      $Config"
if ($Keystore -or $KeyAlias) {
    if (-not $Keystore -or -not $KeyAlias) {
        throw "Keystore signing requires both -Keystore and -KeyAlias."
    }
    $Keystore = Require-Path "Android keystore" $Keystore
    Write-Host "Signing:     $Keystore / $KeyAlias"
    if ($Config -ne "release") {
        Write-Host "Signing note: androiddeployqt signs release APKs; use -Config release for production builds."
    }
}

if ($CheckOnly) {
    Write-Host "qmake:       $qmake"
    Write-Host "make:        $make"
    Write-Host "cmake:       $cmake"
    Write-Host "ninja:       $ninja"
    if ($Keystore -or $KeyAlias) {
        Write-Host "keystore:    $Keystore"
        Write-Host "key alias:   $KeyAlias"
    }
    Write-Host "CheckOnly complete."
    exit 0
}

if ($UseCMake -and $Keystore) {
    throw "Keystore signing is currently supported by this script for the default qmake/androiddeployqt path. Re-run without -UseCMake."
}

if ($Clean -and (Test-Path $buildRoot)) {
    Remove-Item -LiteralPath $buildRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $buildRoot | Out-Null

if ($UseCMake) {
    if (-not $cmake) { throw "cmake.exe not found in PATH." }

    $generator = "Unix Makefiles"
    $buildTool = $make
    if ($ninja) {
        $generator = "Ninja"
        $buildTool = $ninja
    }
    if (-not $buildTool) { throw "Neither ninja.exe nor Android NDK make.exe was found." }

    $qt5Dir = Join-Path $qtRoot "lib\cmake\Qt5"
    $cmakeArgs = @(
        "-S", $repoRoot,
        "-B", $buildRoot,
        "-G", $generator,
        "-DCMAKE_BUILD_TYPE=$Config",
        "-DCMAKE_TOOLCHAIN_FILE=$repoRoot\cmake\android.toolchain.cmake",
        "-DANDROID_ABI=$Abi",
        "-DANDROID_NDK=$ndkRoot",
        "-DANDROID_NATIVE_API_LEVEL=android-$AndroidApi",
        "-DANDROID_STL=c++_shared",
        "-DQT_LIBRARY_HINTS=$qtRoot",
        "-DQt5_DIR=$qt5Dir",
        "-DQT_ANDROID_SDK_ROOT=$sdkRoot",
        "-DQT_ANDROID_NDK_ROOT=$ndkRoot"
    )
    if ($generator -eq "Ninja") {
        $cmakeArgs += "-DCMAKE_MAKE_PROGRAM=$ninja"
    } else {
        $cmakeArgs += "-DCMAKE_MAKE_PROGRAM=$make"
    }

    Invoke-Step "Configure CMake Android" $cmake $cmakeArgs $repoRoot
    Invoke-Step "Build CMake APK target" $cmake @("--build", $buildRoot, "--target", "QGroundControl.apk", "--parallel", "$Jobs") $repoRoot
} else {
    if (-not $qmake) { throw "qmake.exe not found. Set QT_ANDROID_ROOT to the Qt Android root, for example D:\Programs\Qt\5.15.2\android." }
    if (-not $make) { throw "Android NDK make.exe not found under $ndkRoot." }

    Push-Location $buildRoot
    try {
        $qmakeArgs = @(
            (Join-Path $repoRoot "qgroundcontrol.pro"),
            "-spec", "android-clang",
            "CONFIG+=$Config",
            "ANDROID_ABIS=$Abi"
        )
        if ($Config -eq "debug") {
            $qmakeArgs += "CONFIG+=qml_debug"
        }

        Invoke-Step "Configure qmake Android" $qmake $qmakeArgs $buildRoot
        Invoke-Step "Compile native libraries" $make @("-j$Jobs") $buildRoot

        $androidBuildDir = Join-Path $buildRoot "android-build"
        $deploymentJson = Get-ChildItem -Path $buildRoot -Filter "*-deployment-settings.json" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if (-not $deploymentJson) {
            throw "Could not find android deployment settings json under $buildRoot."
        }

        Invoke-Step "Install Android package files" $make @("-f", "Makefile", "INSTALL_ROOT=$androidBuildDir", "install") $buildRoot

        $androidDeployQt = Find-Executable "androiddeployqt.exe" @((Join-Path $qtRoot "bin"))
        if (-not $androidDeployQt) {
            throw "androiddeployqt.exe not found under $qtRoot\bin."
        }

        $signed = -not [string]::IsNullOrWhiteSpace($Keystore)
        $apkName = if ($signed) {
            "AlesQGroundControl-signed.apk"
        } elseif ($Config -eq "release") {
            "AlesQGroundControl-release.apk"
        } else {
            "AlesQGroundControl-debug.apk"
        }
        $apkPath = Join-Path $androidBuildDir $apkName
        $deployArgs = @(
            "--input", $deploymentJson.FullName,
            "--output", $androidBuildDir,
            "--apk", $apkPath,
            "--android-platform", "android-$AndroidApi"
        )
        $sensitiveValues = @()
        if ($signed) {
            $deployArgs += @("--release", "--sign", $Keystore, $KeyAlias)
            if ($StorePass) {
                $deployArgs += @("--storepass", $StorePass)
                $sensitiveValues += $StorePass
            }
            if ($KeyPass) {
                $deployArgs += @("--keypass", $KeyPass)
                $sensitiveValues += $KeyPass
            }
            if ($StoreType) {
                $deployArgs += @("--storetype", $StoreType)
            }
            if ($TimestampAuthority) {
                $deployArgs += @("--tsa", $TimestampAuthority)
            }
        } elseif ($Config -eq "release") {
            $deployArgs += "--release"
        }
        Invoke-Step "Package APK with androiddeployqt" $androidDeployQt $deployArgs $buildRoot $sensitiveValues
    } finally {
        Pop-Location
    }
}

$apkFiles = Get-ChildItem -Path $buildRoot -Recurse -Filter "*.apk" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending

if (-not $apkFiles -or $apkFiles.Count -eq 0) {
    throw "Build finished but no APK was found under $buildRoot."
}

Write-Host ""
Write-Host "APK built:"
Write-Host $apkFiles[0].FullName

if ($Install) {
    $adb = Find-Executable "adb.exe" @((Join-Path $sdkRoot "platform-tools"))
    if (-not $adb) {
        throw "adb.exe not found; APK was built but not installed."
    }
    Invoke-Step "Install APK" $adb @("install", "-r", $apkFiles[0].FullName) $repoRoot
}
