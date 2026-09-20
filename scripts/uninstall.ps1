# LosslessScaling-DLSS5-Preset - uninstaller
# Reverses exactly what install.ps1 recorded in _backup\manifest.json.
[CmdletBinding()]
param(
    [string] $LsPath,
    [switch] $DryRun,
    [switch] $Purge   # also delete the NVIDIA runtime DLLs even if the preset did not add them
)

$ErrorActionPreference = 'Stop'

$RepoRoot  = Split-Path -Parent $PSScriptRoot
$BackupDir = Join-Path $RepoRoot '_backup'
$Manifest  = Join-Path $BackupDir 'manifest.json'
. (Join-Path $PSScriptRoot 'common.ps1')

function Say { param([string]$T, [string]$Tag = '    ') Write-Host ("[{0}] {1}" -f $Tag, $T) }

Write-Host ''
Write-Host ' LosslessScaling-DLSS5-Preset - uninstall ' -ForegroundColor Black -BackgroundColor DarkYellow
Write-Host ''

if (-not (Test-Path -LiteralPath $Manifest)) {
    Write-Host 'No manifest found - this preset was not installed from this folder.' -ForegroundColor Red
    Write-Host "Expected: $Manifest"
    exit 1
}

$doc = Get-Content -LiteralPath $Manifest -Raw -Encoding UTF8 | ConvertFrom-Json
$lsDir = $doc.lsPath
if ($LsPath) { $lsDir = $LsPath.TrimEnd('\') }

if (-not (Test-Path -LiteralPath (Join-Path $lsDir 'LosslessScaling.exe') -ErrorAction SilentlyContinue)) {
    Write-Host ("Lossless Scaling not found at " + $lsDir + " - pass -LsPath.") -ForegroundColor Red
    exit 1
}
if (Get-Process -Name 'LosslessScaling' -ErrorAction SilentlyContinue) {
    Write-Host 'Lossless Scaling is running. Close it and run this again.' -ForegroundColor Red
    exit 1
}
Say ("installed into " + $lsDir + " on " + $doc.installed)

$removed = 0; $restored = 0; $missing = 0

foreach ($rec in $doc.files) {
    $target = Join-Path $lsDir $rec.path

    if ($rec.backup) {
        $src = Join-Path $BackupDir $rec.backup
        if (Test-Path -LiteralPath $src) {
            if (-not $DryRun) { Copy-Item -LiteralPath $src -Destination $target -Force }
            Say ("restored " + $rec.path) 'back'; $restored++
            continue
        }
        Say ("backup gone for " + $rec.path + " - leaving the installed file in place") 'warn'
    }

    # The stock DLL we renamed on the way in.
    if ($rec.path -eq 'Lossless_original.dll') {
        $proxy = Join-Path $lsDir 'Lossless.dll'
        if (Test-Path -LiteralPath $target) {
            if (-not $DryRun) {
                if (Test-Path -LiteralPath $proxy) { Remove-Item -LiteralPath $proxy -Force }
                Move-Item -LiteralPath $target -Destination $proxy -Force
            }
            Say 'Lossless_original.dll -> Lossless.dll (proxy removed)'; $removed++
        }
        continue
    }

    # Files this preset added that were not there before: take them back out.
    if ($rec.action -eq 'added') {
        if (Test-Path -LiteralPath $target) {
            if (-not $DryRun) { Remove-Item -LiteralPath $target -Force }
            Say ("removed " + $rec.path); $removed++
        } else { $missing++ }
        continue
    }

    # replaced but the backup is gone: leave it alone, say so.
    Say ("kept " + $rec.path + " (was replaced, no backup left to restore)") 'warn'
}

# Folders this preset created.
foreach ($dir in @('addons\LSP-Windowed')) {
    $d = Join-Path $lsDir $dir
    if (Test-Path -LiteralPath $d) {
        $left = @(Get-ChildItem -LiteralPath $d -File -ErrorAction SilentlyContinue)
        if ($left.Count -eq 0) { if (-not $DryRun) { Remove-Item -LiteralPath $d -Force }; Say ("removed empty folder " + $dir) }
        else { Say ($dir + " still has " + $left.Count + " file(s) - left in place") 'warn' }
    }
}

if ($Purge) {
    foreach ($name in @('nvngx_dlss.dll', 'nvngx_dlssd.dll', 'nvngx_dlssg.dll', 'nvngx_dlssnr.dll')) {
        $p = Join-Path $lsDir $name
        if (Test-Path -LiteralPath $p) { if (-not $DryRun) { Remove-Item -LiteralPath $p -Force }; Say ("purged " + $name) }
    }
    Get-ChildItem -LiteralPath $lsDir -Filter 'sl.*.dll' -File -ErrorAction SilentlyContinue | ForEach-Object {
        if (-not $DryRun) { Remove-Item -LiteralPath $_.FullName -Force }
        Say ("purged " + $_.Name)
    }
}

# Leftovers the runtime leaves behind that are not worth keeping.
foreach ($junk in @('ReShade.log', 'LosslessProxy.log', 'DX11Hook.log', 'ShaderHook.log')) {
    $p = Join-Path $lsDir $junk
    if (Test-Path -LiteralPath $p) { if (-not $DryRun) { Remove-Item -LiteralPath $p -Force }; Say ("removed log " + $junk) }
}

if (-not $DryRun) { Remove-Item -LiteralPath $BackupDir -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host ''
Write-Host ("  restored $restored | removed $removed | already gone $missing")
Write-Host ''
Write-Host 'Lossless Scaling is back to stock. Re-verify the game files in Steam if anything looks off.'
exit 0
