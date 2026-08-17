<#
.SYNOPSIS
  One-command Windows (64-bit) build for Mine-imator Nexus.
  Runs CppGen (GML -> C++), configures CMake, builds Release, then packages the
  release .zip with make-release.ps1.

.DESCRIPTION
  Everything is wired to the folders this repo expects:
    DEV_DIR      -> C:\Dev   (Qt is expected at <DevDir>\Qt\5.15.9\build)
    BuildDir     -> C:\Dev\Projects\Mine-imator-build
    Release exe  -> <BuildDir>\Release\Mine-imator.exe
    Output zip   -> Builds\Mine-imator <Version>.zip

  On this machine the heavy one-time step (building Qt 5.15.9 from source) is
  already done, so this script is just: CppGen -> cmake configure -> cmake build
  -> zip. That's it.

.EXAMPLE
  .\build-all.ps1                          # default version "2.0.2 Nexus"
  .\build-all.ps1 "2.0.2 Nexus 26.3"       # custom release name
  .\build-all.ps1 -SkipCppGen -SkipBuild -SkipPackage  # dry-run checks only
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Version = "2.0.2 Nexus",
    [string]$DevDir = "",
    [string]$BuildDir = "",
    [switch]$SkipCppGen,
    [switch]$SkipBuild,
    [switch]$SkipPackage
)

$ErrorActionPreference = "Stop"
# $PSScriptRoot is empty when the script is pasted into an interactive console
# (it's only set when a .ps1 runs as a file), so fall back to the working dir.
$root = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }

# ---- 1. DEV_DIR (CMakeLists.txt reads $ENV{DEV_DIR} for the Qt path) -------
if (-not $DevDir) { $DevDir = $env:DEV_DIR }
if (-not $DevDir) { $DevDir = "C:\Dev" }
$env:DEV_DIR = $DevDir
Write-Host "DEV_DIR  = $DevDir"

# ---- 2. Locate CMake (PATH first, else C:\Dev\cmake-*\bin) ----------------
$cmakeCmd = Get-Command cmake -ErrorAction SilentlyContinue
if ($cmakeCmd) {
    $cmake = $cmakeCmd.Source
} else {
    $candidate = Get-ChildItem "$DevDir\cmake-*\bin\cmake.exe" -ErrorAction SilentlyContinue |
                 Sort-Object FullName -Descending | Select-Object -First 1
    if ($candidate) { $cmake = $candidate.FullName }
    else { Write-Error "CMake not found. Install it (https://cmake.org) or re-run with -DevDir." }
}
Write-Host "CMake    = $cmake"

# ---- 3. Build folder -------------------------------------------------------
if (-not $BuildDir) { $BuildDir = Join-Path $DevDir "Projects\Mine-imator-build" }
New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null
Write-Host "BuildDir = $BuildDir"

# ---- 4. CppGen: GML -> C++ -------------------------------------------------
if (-not $SkipCppGen) {
    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        Write-Error ".NET SDK not found - required to run CppGen."
    }
    Write-Host ""
    Write-Host "[1/3] Running CppGen (GML -> C++)..."
    Push-Location $root
    try {
        & dotnet run --project "CppGen\CppGen\CppGen.csproj" -- `
            "GmProject" "CppProject\Generated" "CppProject\Asset\Sprites" `
            "CppProject\Asset\Shaders" "CppGen\gml.json"
        if ($LASTEXITCODE -ne 0) { Write-Error "CppGen failed (exit $LASTEXITCODE)." }
    } finally { Pop-Location }
}

# ---- 5. CMake configure + build Release ------------------------------------
if (-not $SkipBuild) {
    Write-Host ""
    Write-Host "[2/3] Configuring CMake (Visual Studio 17 2022, x64)..."
    & $cmake -S (Join-Path $root "CppProject") -B $BuildDir -G "Visual Studio 17 2022" -A x64
    if ($LASTEXITCODE -ne 0) { Write-Error "CMake configure failed (exit $LASTEXITCODE)." }

    Write-Host ""
    Write-Host "Building Release (this can take a while)..."
    & $cmake --build $BuildDir --config Release --parallel
    if ($LASTEXITCODE -ne 0) { Write-Error "Build failed (exit $LASTEXITCODE)." }

    $exe = Join-Path $BuildDir "Release\Mine-imator.exe"
    if (-not (Test-Path $exe)) { Write-Error "Build finished but $exe was not produced." }
    Write-Host "Built: $exe"
}

# ---- 6. Package the release .zip -------------------------------------------
if (-not $SkipPackage) {
    Write-Host ""
    Write-Host "[3/3] Packaging release with make-release.ps1..."
    & (Join-Path $root "make-release.ps1") $Version -BuildDir $BuildDir
}

Write-Host ""
Write-Host "Done. Release archive(s) are in: $(Join-Path $root 'Builds')"
