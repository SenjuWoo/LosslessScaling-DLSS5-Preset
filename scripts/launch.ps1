# LosslessScaling-DLSS5-Preset - launcher
# Starts Lossless Scaling the way this preset needs it:
#   - HKCU\SOFTWARE\Microsoft\Avalon.Graphics\DisableHWAcceleration = 1 while it runs
#     (LS's own window is WPF; without this the Neural Rendering add-on processes the
#      settings window too, and LS can crash on start)
#   - the previous value is restored when LS exits, and also on the next run if a
#     previous run was killed
[CmdletBinding()]
param(
    [string] $LsPath,
    [switch] $Restore
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

$MarkerDir = Join-Path $env:LOCALAPPDATA 'LosslessScaling-DLSS5-Preset'
$Marker    = Join-Path $MarkerDir 'hwaccel.marker'
$Avalon    = 'HKCU:\SOFTWARE\Microsoft\Avalon.Graphics'

function Get-HwAccel {
    try {
        $p = Get-ItemProperty -Path $Avalon -Name 'DisableHWAcceleration' -ErrorAction SilentlyContinue
        if ($p -and $null -ne $p.DisableHWAcceleration) { return [int]$p.DisableHWAcceleration }
    } catch { }
    return $null   # key was not there at all
}

function Restore-HwAccel {
    if (-not (Test-Path -LiteralPath $Marker)) { return }
    $raw = (Get-Content -LiteralPath $Marker -Raw).Trim()
    if (-not (Test-Path -Path $Avalon)) { New-Item -Path $Avalon -Force | Out-Null }
    if ($raw -eq 'absent') {
        Remove-ItemProperty -Path $Avalon -Name 'DisableHWAcceleration' -ErrorAction SilentlyContinue
        Write-Host '  DisableHWAcceleration removed (it was not set before)'
    } else {
        New-ItemProperty -Path $Avalon -Name 'DisableHWAcceleration' -Value ([int]$raw) -PropertyType DWord -Force | Out-Null
        Write-Host ("  DisableHWAcceleration restored to " + $raw)
    }
    Remove-Item -LiteralPath $Marker -Force
}

if ($Restore) { Restore-HwAccel; exit 0 }

# A marker left behind means the last run was killed before it could clean up.
if (Test-Path -LiteralPath $Marker) {
    Write-Host 'A previous run did not clean up. Restoring first.'
    Restore-HwAccel
}

$lsDir = Find-LsPath -Hint $LsPath
if (-not $lsDir) {
    Write-Host 'LosslessScaling.exe not found. Pass the folder:  LAUNCH-LosslessScaling.bat -LsPath "X:\...\Lossless Scaling"' -ForegroundColor Red
    exit 1
}
$exe = Join-Path $lsDir 'LosslessScaling.exe'

if (Get-Process -Name 'LosslessScaling' -ErrorAction SilentlyContinue) {
    Write-Host 'Lossless Scaling is already running.' -ForegroundColor Yellow
    exit 0
}

if (-not (Test-Path -LiteralPath $MarkerDir)) { New-Item -ItemType Directory -Path $MarkerDir -Force | Out-Null }
$before = Get-HwAccel
if ($null -eq $before) { Set-Content -LiteralPath $Marker -Value 'absent' -Encoding ASCII }
else { Set-Content -LiteralPath $Marker -Value ([string]$before) -Encoding ASCII }

if (-not (Test-Path -Path $Avalon)) { New-Item -Path $Avalon -Force | Out-Null }
New-ItemProperty -Path $Avalon -Name 'DisableHWAcceleration' -Value 1 -PropertyType DWord -Force | Out-Null
Write-Host 'DisableHWAcceleration = 1 (the LS window will not be processed by the add-on)'

Write-Host ("Starting " + $exe)
$proc = Start-Process -FilePath $exe -WorkingDirectory $lsDir -PassThru

try {
    $proc.WaitForExit()
} finally {
    Restore-HwAccel
}
Write-Host 'Lossless Scaling closed.'
exit 0
