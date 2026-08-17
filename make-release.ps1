<#
.SYNOPSIS
  Builds a Mine-imator Nexus Windows release (.zip) the same way mbanders
  packages their Continuation Build releases.

.DESCRIPTION
  Replicates Installer/Windows/UpdateApp.ps1 (the upstream release flow):
    1. stages the app into the git-ignored folder Installer/Windows/Mine-imator/
    2. zips it into Builds/Mine-imator <Version>.zip (WinRAR if available,
       otherwise the built-in .NET zip - no extra installs required)
    3. optionally compiles the Inno Setup installer (Installer/Windows/setup.iss)

  Nexus additions over upstream:
    - builds Data/ and Particles/ straight from GmProject/datafiles (no
      hand-maintained template folder needed)
    - bundles companion/ (the AI Assistant) + a "Start AI Companion.bat"
    - no WinRAR dependency (falls back to System.IO.Compression)

  NOTE: you must build Mine-imator.exe first (see CppProject/BUILD.md). The
  executable is expected at <BuildDir>\Release\Mine-imator.exe (64-bit) or
  <BuildDir>\Release-Win32\Mine-imator.exe (32-bit).

.PARAMETER Version
  Release name used in the output filename and the top-level folder inside the
  zip. Defaults to "2.0.2 Nexus".

.PARAMETER BuildDir
  Folder that contains the built Mine-imator.exe (the CMake binary directory).
  Defaults to $env:DEV_DIR\Projects\Mine-imator-build, matching upstream.

.PARAMETER Win32
  Package the 32-bit build (Release-Win32\ + vcomp140_x86.dll).

.PARAMETER SkipCompanion
  Do not bundle the AI companion.

.PARAMETER SkipInstaller
  Do not attempt to build the Inno Setup installer.

.PARAMETER UseWinRAR
  Use WinRAR ("C:\Program Files\WinRAR\WinRar.exe") exactly like upstream
  instead of the built-in .NET zip. The .NET zip is the reliable default and
  produces the identical release structure.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File make-release.ps1 "2.0.2 Nexus 1.0.0" -BuildDir C:\Dev\Projects\Mine-imator-build
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Version = "2.0.2 Nexus",
    [string]$BuildDir = "",
    [switch]$Win32,
    [switch]$SkipCompanion,
    [switch]$SkipInstaller,
    [switch]$UseWinRAR
)

$ErrorActionPreference = "Stop"

# $PSScriptRoot is empty when pasted into an interactive console (only set when
# a .ps1 runs as a file), so fall back to the working directory.
$root          = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$buildsDir     = Join-Path $root "Builds"
$installerDir  = Join-Path $root "Installer\Windows"
$staging       = Join-Path $installerDir "Mine-imator"

# Version used in filenames must not contain path-invalid characters.
$archName = "Mine-imator " + ($Version -replace '[\\/:*?"<>|]', '-')

# --- Resolve the built executable -----------------------------------------
if (-not $BuildDir) {
    if ($env:DEV_DIR) {
        $BuildDir = Join-Path $env:DEV_DIR "Projects\Mine-imator-build"
    } else {
        Write-Warning "DEV_DIR is not set and no -BuildDir was given."
        $BuildDir = ""
    }
}
$cfg      = if ($Win32) { "Release-Win32" } else { "Release" }
$exePath  = if ($BuildDir) { Join-Path $BuildDir "$cfg\Mine-imator.exe" } else { "" }
$vcompSrc = Join-Path $installerDir $(if ($Win32) { "vcomp140_x86.dll" } else { "vcomp140_x64.dll" })

if (-not $exePath -or -not (Test-Path $exePath)) {
    Write-Host ""
    Write-Warning "Built executable not found: $exePath"
    Write-Warning "Build Mine-imator.exe first (see CppProject\BUILD.md), then re-run with -BuildDir, e.g.:"
    Write-Warning "  .\make-release.ps1 '$Version' -BuildDir C:\Dev\Projects\Mine-imator-build"
    exit 1
}

# --- Stage the app --------------------------------------------------------
Write-Host "Staging app into: $staging"
if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
New-Item -ItemType Directory -Path $staging | Out-Null

Copy-Item $exePath (Join-Path $staging "Mine-imator.exe")
Copy-Item $vcompSrc (Join-Path $staging "vcomp140.dll") -Force
Write-Host "  + Mine-imator.exe (from $cfg)"

# Datafiles -> Data/ and Particles/ (the app reads Data/ next to the exe)
Copy-Item (Join-Path $root "GmProject\datafiles\*") $staging -Recurse -Force
Write-Host "  + Data/ + Particles/ (from GmProject\datafiles)"

# AI companion + launcher (Nexus)
if (-not $SkipCompanion) {
    Copy-Item (Join-Path $root "companion") (Join-Path $staging "companion") -Recurse -Force
    # strip dev artifacts that must not ship
    $comp = Join-Path $staging "companion"
    Remove-Item (Join-Path $comp "__pycache__") -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $comp ".venv") -Recurse -Force -ErrorAction SilentlyContinue
    Get-ChildItem $comp -Recurse -Force -Filter "*.pyc" | Remove-Item -Force -ErrorAction SilentlyContinue
    $bat = @'
@echo off
rem Starts the Mine-imator Nexus AI Companion (Python standard library only).
cd /d "%~dp0"
where python >nul 2>nul
if errorlevel 1 (
    echo Python was not found on PATH. Install Python 3.8+ from https://www.python.org
    pause
    exit /b 1
)
python "companion\main.py"
pause
'@
    Set-Content -Path (Join-Path $staging "Start AI Companion.bat") -Value $bat -Encoding ASCII
    Write-Host "  + companion/ (AI Assistant) + Start AI Companion.bat"
}

# Empty Projects folder (first-run save area) - kept inside the zip like upstream
New-Item -ItemType Directory -Path (Join-Path $staging "Projects") | Out-Null

# --- Zip ------------------------------------------------------------------
New-Item -ItemType Directory -Path $buildsDir -Force | Out-Null
$outZip = Join-Path $buildsDir "$archName.zip"
if (Test-Path $outZip) { Remove-Item $outZip -Force }

if ($UseWinRAR -and (Test-Path "C:\Program Files\WinRAR\WinRar.exe")) {
    # Mirror upstream exactly: run from the parent dir with the relative folder
    # name so the archive stores "Mine-imator/..." entries.
    Write-Host "Zipping with WinRAR (same as upstream)..."
    Push-Location $installerDir
    try {
        & "C:\Program Files\WinRAR\WinRar.exe" a -rzip $outZip "Mine-imator" | Out-Null
        $p = Get-Process -Name WinRar -ErrorAction SilentlyContinue
        if ($p) { $p | Wait-Process -Timeout 120 -ErrorAction SilentlyContinue }
        & "C:\Program Files\WinRAR\WinRar.exe" rn $outZip "Mine-imator" $archName | Out-Null
        $p = Get-Process -Name WinRar -ErrorAction SilentlyContinue
        if ($p) { $p | Wait-Process -Timeout 120 -ErrorAction SilentlyContinue }
    } finally { Pop-Location }
} else {
    # Built-in .NET zip: synchronous and dependency-free. The staging folder is
    # placed inside a temp folder named "Mine-imator <Version>" so the archive's
    # top-level folder is versioned (same result as upstream's "rn" rename).
    Write-Host "Zipping with built-in .NET zip (no WinRAR needed)..."
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $tmpParent = Join-Path $buildsDir "_staging_$archName"
    if (Test-Path $tmpParent) { Remove-Item $tmpParent -Recurse -Force }
    $tmpRoot = Join-Path $tmpParent $archName
    Copy-Item $staging $tmpRoot -Recurse -Force
    [System.IO.Compression.ZipFile]::CreateFromDirectory($tmpParent, $outZip)
    Remove-Item $tmpParent -Recurse -Force
}
Write-Host "  Zip: $outZip"

# Remove the empty Projects folder from staging before the installer (upstream behavior)
$projDir = Join-Path $staging "Projects"
if (Test-Path $projDir) { Remove-Item $projDir -Force }

# --- Installer (optional) --------------------------------------------------
if (-not $SkipInstaller) {
    $iscc = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
    if (Test-Path $iscc) {
        Write-Host "Building Inno Setup installer..."
        Push-Location $installerDir
        try {
            & $iscc "setup.iss" | Out-Null
            $installerExe = Join-Path $installerDir "installer.exe"
            if (Test-Path $installerExe) {
                $archSuffix = if ($Win32) { " x86" } else { "" }
                $outInstaller = Join-Path $buildsDir "$archName$archSuffix installer.exe"
                Move-Item $installerExe $outInstaller -Force
                Write-Host "  Installer: $outInstaller"
            }
        } finally {
            Pop-Location
        }
    } else {
        Write-Host "Inno Setup not found - skipping installer (zip only)."
    }
}

Write-Host ""
Write-Host "Done! Release archive(s) are in: $buildsDir"
