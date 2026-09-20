# Shared Lossless Scaling discovery for install.ps1 / launch.ps1 / uninstall.ps1.
# Dot-source:  . (Join-Path $PSScriptRoot 'common.ps1')
#
# Paths are built with string concatenation, never Join-Path, on any part that could sit on a
# drive that does not exist: Join-Path resolves the drive and throws "Cannot find drive" for
# a missing one, which would kill the whole search.

function Join-NativePath {
    param([string]$Root, [string]$Leaf)
    return ($Root.TrimEnd('\') + '\' + $Leaf.TrimStart('\'))
}

function Test-Writable {
    param([string]$Dir)
    $probe = Join-NativePath $Dir ('.lspreset-write-probe-' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [System.IO.File]::WriteAllText($probe, 'x')
        Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
        return $true
    } catch { return $false }
}

function Show-NotWritable {
    param([string]$Dir, [string]$ScriptName)
    Write-Host ''
    Write-Host ("Cannot write to " + $Dir) -ForegroundColor Red
    Write-Host ''
    Write-Host 'A Steam library under C:\Program Files needs administrator rights. Either:'
    Write-Host '    right-click the .bat  ->  "Run as administrator"'
    Write-Host '  or, from an already-elevated terminal:'
    Write-Host ('    powershell -ExecutionPolicy Bypass -File "' + $ScriptName + '"')
}

function Get-SteamLibraries {
    $libs  = New-Object System.Collections.Generic.List[string]
    $roots = New-Object System.Collections.Generic.List[string]

    foreach ($key in @('HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam', 'HKLM:\SOFTWARE\Valve\Steam')) {
        try {
            $p = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue
            if ($p) {
                foreach ($name in @('SteamPath', 'InstallPath')) {
                    $v = $p.$name
                    if ($v) { $roots.Add(($v -replace '/', '\')) }
                }
            }
        } catch { }
    }
    foreach ($r in @('C:\Program Files (x86)\Steam', 'C:\Program Files\Steam', 'D:\Steam', 'S:\Steam')) { $roots.Add($r) }

    foreach ($root in ($roots | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $root -ErrorAction SilentlyContinue)) { continue }

        $common = Join-NativePath $root 'steamapps\common'
        if (Test-Path -LiteralPath $common -ErrorAction SilentlyContinue) { $libs.Add($common) }

        $vdf = Join-NativePath $root 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $vdf -ErrorAction SilentlyContinue) {
            foreach ($line in (Get-Content -LiteralPath $vdf -ErrorAction SilentlyContinue)) {
                if ($line -match '^\s*"path"\s+"(.+?)"\s*$') {
                    $libRoot = ($matches[1] -replace '\\\\', '\')
                    if (-not (Test-Path -LiteralPath $libRoot -ErrorAction SilentlyContinue)) { continue }
                    $lib = Join-NativePath $libRoot 'steamapps\common'
                    if (Test-Path -LiteralPath $lib -ErrorAction SilentlyContinue) { $libs.Add($lib) }
                }
            }
        }
    }
    return ($libs | Select-Object -Unique)
}

function Find-LsPath {
    param([string]$Hint)

    if ($Hint) {
        $h = $Hint.TrimEnd('\')
        if (Test-Path -LiteralPath (Join-NativePath $h 'LosslessScaling.exe') -ErrorAction SilentlyContinue) { return $h }
        throw "No LosslessScaling.exe in the folder you passed: $h"
    }

    $candidates = New-Object System.Collections.Generic.List[string]
    foreach ($lib in (Get-SteamLibraries)) { $candidates.Add((Join-NativePath $lib 'Lossless Scaling')) }
    foreach ($c in @('C:\Lossless Scaling', 'D:\Lossless Scaling', 'S:\Lossless Scaling')) { $candidates.Add($c) }

    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath (Join-NativePath $c 'LosslessScaling.exe') -ErrorAction SilentlyContinue) { return $c }
    }

    # Last resort: the exe is running, ask the process where it lives.
    $proc = Get-Process -Name 'LosslessScaling' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($proc -and $proc.Path) { return (Split-Path -Parent $proc.Path) }

    return $null
}
