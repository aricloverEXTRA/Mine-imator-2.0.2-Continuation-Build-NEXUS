<#
.SYNOPSIS
    Cleans all build artifacts and generated files from the Mine-imator workspace.

.DESCRIPTION
    Removes: CppProject/Generated/, CppGen build output, CMake cache, Output/, Logs/,
    temporary files, backup files, and debug dump files.
    Does NOT remove source code, .gitignore files, or project data.

.PARAMETER WhatIf
    Preview which files/folders would be removed without actually deleting.

.PARAMETER Full
    Also removes the entire CMake build directory. Without this, only cache is removed.

.EXAMPLE
    .\cleanup-build.ps1              # normal cleanup
    .\cleanup-build.ps1 -WhatIf     # preview only
    .\cleanup-build.ps1 -Full       # also wipe the CMake build tree
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [switch]$Full
)

$ErrorActionPreference = 'SilentlyContinue'
$root = $PSScriptRoot
$removed = 0
$skipped = 0

function Remove-Path {
    param([string]$Path, [string]$Label)
    if (Test-Path $Path) {
        if ($PSCmdlet.ShouldProcess($Path, "Remove $Label")) {
            Remove-Item $Path -Recurse -Force
            Write-Host "  [REMOVED]  $Label" -ForegroundColor Green
            $script:removed++
        }
    } else {
        Write-Host "  [skip]     $Label (not found)" -ForegroundColor DarkGray
        $script:skipped++
    }
}

function Remove-FileGlob {
    param([string]$Pattern, [string]$Label)
    $files = Get-ChildItem -Path $root -Filter $Pattern -Recurse -File -Force -ErrorAction SilentlyContinue |
             Where-Object { $_.FullName -notmatch '\\(\.git|node_modules)\\' }
    foreach ($f in $files) {
        if ($PSCmdlet.ShouldProcess($f.FullName, "Remove file")) {
            Remove-Item $f.FullName -Force
            Write-Host "  [REMOVED]  $($f.FullName.Substring($root.Length + 1))" -ForegroundColor Green
            $script:removed++
        }
    }
    if ($files.Count -eq 0) {
        Write-Host "  [skip]     $Label (none found)" -ForegroundColor DarkGray
        $script:skipped++
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Mine-imator Nexus Build Cleanup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Workspace: $root"
Write-Host ""

# 1. CppProject/Generated (CppGen output)
Write-Host "[1/8] Generated C++ files (CppProject/Generated/)" -ForegroundColor Yellow
$generatedDir = Join-Path $root "CppProject\Generated"
if (Test-Path $generatedDir) {
    $items = Get-ChildItem $generatedDir -Force | Where-Object { $_.Name -ne '.gitignore' }
    foreach ($item in $items) {
        Remove-Path $item.FullName $item.Name
    }
    if ($items.Count -eq 0) {
        Write-Host "  [skip]     Already clean" -ForegroundColor DarkGray
        $skipped++
    }
} else {
    Write-Host "  [skip]     Directory not found" -ForegroundColor DarkGray
    $skipped++
}

# 2. Generated Sprites
Write-Host "[2/8] Generated sprites (CppProject/Asset/Sprites/)" -ForegroundColor Yellow
$spritesDir = Join-Path $root "CppProject\Asset\Sprites"
if (Test-Path $spritesDir) {
    $spriteItems = Get-ChildItem $spritesDir -Force | Where-Object { $_.Name -ne '.gitignore' }
    foreach ($item in $spriteItems) {
        Remove-Path $item.FullName $item.Name
    }
    if ($spriteItems.Count -eq 0) {
        Write-Host "  [skip]     Already clean" -ForegroundColor DarkGray
        $skipped++
    }
} else {
    Write-Host "  [skip]     Directory not found" -ForegroundColor DarkGray
    $skipped++
}

# 3. Generated Shaders
Write-Host "[3/8] Generated shaders (CppProject/Asset/Shaders/)" -ForegroundColor Yellow
$shadersDir = Join-Path $root "CppProject\Asset\Shaders"
if (Test-Path $shadersDir) {
    $shaderItems = Get-ChildItem $shadersDir -Force | Where-Object { $_.Name -notin @('.gitignore', 'index.qrc') }
    foreach ($item in $shaderItems) {
        Remove-Path $item.FullName $item.Name
    }
    if ($shaderItems.Count -eq 0) {
        Write-Host "  [skip]     Already clean" -ForegroundColor DarkGray
        $skipped++
    }
} else {
    Write-Host "  [skip]     Directory not found" -ForegroundColor DarkGray
    $skipped++
}

# 4. CppGen build output
Write-Host "[4/8] CppGen build output" -ForegroundColor Yellow
Remove-Path (Join-Path $root "CppGen\CppGen\obj") "CppGen/obj/"
Remove-Path (Join-Path $root "CppGen\CppGen\bin") "CppGen/bin/"
Remove-Path (Join-Path $root "CppGen\Logs")        "CppGen/Logs/"

# 5. CMake build directory
Write-Host "[5/8] CMake build artifacts" -ForegroundColor Yellow
$cmakeBuildDir = "C:\Dev\Projects\Mine-imator-build"
if ($Full) {
    Remove-Path $cmakeBuildDir "Full CMake build tree"
} else {
    Remove-Path (Join-Path $cmakeBuildDir "CMakeCache.txt") "CMakeCache.txt"
    Remove-Path (Join-Path $cmakeBuildDir "CMakeFiles")     "CMakeFiles/"
}

# 6. Output and Logs
Write-Host "[6/8] Output and Logs" -ForegroundColor Yellow
Remove-Path (Join-Path $root "Output") "Output/"
Remove-Path (Join-Path $root "Logs")   "Logs/"

# 7. Temporary / runtime files
Write-Host "[7/8] Temporary and runtime files" -ForegroundColor Yellow
Remove-Path (Join-Path $root "tmp.file")         "tmp.file"
Remove-Path (Join-Path $root "tmp.png")          "tmp.png"
Remove-Path (Join-Path $root "download.png")     "download.png"
Remove-Path (Join-Path $root "unzip")            "unzip/"
Remove-Path (Join-Path $root "Minecraft_unzip")  "Minecraft_unzip/"
Remove-FileGlob "*.backup*"   "Backup files"
Remove-FileGlob "*.old"       "Old files"
Remove-FileGlob "*.meshcache" "Mesh cache files"

# 8. Debug dump files
Write-Host "[8/8] Debug dump files" -ForegroundColor Yellow
Remove-Path (Join-Path $root "cppgen_output.txt") "cppgen_output.txt"
Remove-Path (Join-Path $root "build_output.txt")  "build_output.txt"

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Done!  Removed: $removed   Skipped: $skipped" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if (-not $Full) {
    Write-Host ""
    Write-Host "Tip: Use -Full to also remove the entire CMake build directory." -ForegroundColor DarkYellow
}
