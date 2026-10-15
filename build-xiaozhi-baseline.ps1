#!/usr/bin/env pwsh
#
# BuddyCore firmware baseline build for Windows hosts.
# Windows counterpart of build-xiaozhi-baseline.sh (same board/Kconfig scheme).
# ASCII-only on purpose: Windows PowerShell 5.1 reads BOM-less .ps1 as ANSI.
#
# One-time prerequisites:
#   1) Install the ESP-IDF tools into dependencies/.espressif:
#        $env:IDF_TOOLS_PATH = "<repo>\dependencies\.espressif"
#        # In China set the mirror first, otherwise crosstool-NG downloads
#        # from github.com time out:
#        $env:IDF_GITHUB_ASSETS = "dl.espressif.com/github_assets"
#        & "<repo>\dependencies\esp-idf\install.ps1" esp32s3
#      Do NOT run the installer with a Python virtualenv active on PATH,
#      ESP-IDF refuses to create its own venv in that case.
#   2) Host needs git and Python 3.9+ (ESP-IDF creates its own venv).
#
# Windows build-path limit: with this many managed components the final compile
# command can exceed the 32 KiB Windows command-line limit ("ninja: fatal:
# CreateProcess: The parameter is incorrect (is the command line too long?)").
# Fix: build from short paths, e.g.
#   $env:BUDDYCORE_XIAOZHI_SHORT_ROOT = "D:\zs"     # source is copied there once
#   $env:BUDDYCORE_XIAOZHI_BUILD_DIR  = "D:\zsz"
# A directory junction is NOT enough: CMake resolves it back to the long path.
#
# Usage from the repository root:
#   $env:BUDDYCORE_XIAOZHI_BOARD_NAME   = "esp32-s3-touch-lcd-1.85c"
#   $env:BUDDYCORE_XIAOZHI_BOARD_CONFIG = "CONFIG_BOARD_TYPE_WAVESHARE_ESP32_S3_TOUCH_LCD_1_85C=y"
#   $env:BUDDYCORE_XIAOZHI_EXTRA_CONFIG = "CONFIG_OTA_URL=`"http://192.168.1.15:8003/xiaozhi/ota/`""
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\build-xiaozhi-baseline.ps1
# Defaults (same as the bash version): bread-compact-wifi.
#

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$IdfPath = Join-Path $Root 'dependencies\esp-idf'
$IdfToolsPath = Join-Path $Root 'dependencies\.espressif'
$Xiaozhi = Join-Path $Root 'dependencies\xiaozhi-esp32'
$ShortRoot = $env:BUDDYCORE_XIAOZHI_SHORT_ROOT
$BoardName = if ($env:BUDDYCORE_XIAOZHI_BOARD_NAME) { $env:BUDDYCORE_XIAOZHI_BOARD_NAME } else { 'bread-compact-wifi' }
$BoardConfig = if ($env:BUDDYCORE_XIAOZHI_BOARD_CONFIG) { $env:BUDDYCORE_XIAOZHI_BOARD_CONFIG } else { 'CONFIG_BOARD_TYPE_BREAD_COMPACT_WIFI=y' }
$ExtraConfig = if ($env:BUDDYCORE_XIAOZHI_EXTRA_CONFIG) { $env:BUDDYCORE_XIAOZHI_EXTRA_CONFIG } else { '' }
$BuildDir = if ($env:BUDDYCORE_XIAOZHI_BUILD_DIR) { $env:BUDDYCORE_XIAOZHI_BUILD_DIR } else { Join-Path $Root "build\xiaozhi-esp32\$BoardName" }
$DefaultsFile = Join-Path $Root "build\xiaozhi-esp32\$BoardName.board.defaults"

if (-not (Test-Path (Join-Path $IdfPath 'export.ps1'))) {
    throw "ESP-IDF source not found: $IdfPath (run: git submodule update --init --recursive)"
}
if (-not (Test-Path (Join-Path $Xiaozhi 'main\Kconfig.projbuild'))) {
    throw "xiaozhi-esp32 source not found: $Xiaozhi"
}

if ($ShortRoot) {
    if (-not (Test-Path (Join-Path $ShortRoot 'main\Kconfig.projbuild'))) {
        Write-Host "Copying source to short path $ShortRoot (one-off, Windows command-line limit workaround)"
        robocopy $Xiaozhi $ShortRoot /E /XD .git /NFL /NDL /NJH /NJS /NP /R:1 /W:1 | Out-Null
    }
    $Xiaozhi = $ShortRoot
}

$env:IDF_TOOLS_PATH = $IdfToolsPath
Remove-Item Env:VIRTUAL_ENV -ErrorAction SilentlyContinue
. (Join-Path $IdfPath 'export.ps1') | Out-Null

New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $DefaultsFile) | Out-Null
$defaultsLines = @($BoardConfig)
if ($ExtraConfig) { $defaultsLines += ($ExtraConfig -split "`n") }
Set-Content -Path $DefaultsFile -Value $defaultsLines -Encoding ascii
$env:SDKCONFIG_DEFAULTS = "$Xiaozhi\sdkconfig.defaults;$DefaultsFile"

Write-Host "ESP-IDF:  $(idf.py --version)"
Write-Host "board:    $BoardName ($BoardConfig)"
Write-Host "builddir: $BuildDir"

idf.py -C $Xiaozhi -B $BuildDir "-DSDKCONFIG=$BuildDir\sdkconfig" -DIDF_TARGET=esp32s3 "-DBOARD_NAME=$BoardName" build
if ($LASTEXITCODE -ne 0) { throw "build failed with exit code $LASTEXITCODE" }

Write-Host "Build finished: $BuildDir"
Write-Host "Flash with: idf.py -C `"$Xiaozhi`" -B `"$BuildDir`" -p COMx flash"
