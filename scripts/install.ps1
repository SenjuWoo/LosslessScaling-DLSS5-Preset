# LosslessScaling-DLSS5-Preset - installer
# Windows PowerShell 5.1. No PS7-only syntax.
# Copies the preconfigured DLSS 5 Neural Rendering preset into a Lossless Scaling install.
# Every write is recorded in _backup\manifest.json so uninstall.ps1 can reverse it exactly.
[CmdletBinding()]
param(
    [string] $LsPath,
    [switch] $SkipRuntime,   # do not fetch the ~275 MB NVIDIA runtime archive
    [switch] $Verify,        # check an existing install, change nothing
    [switch] $DryRun,        # print the plan, change nothing
    [switch] $NoLaunch
)

$ErrorActionPreference = 'Stop'

$RepoRoot   = Split-Path -Parent $PSScriptRoot
$PayloadDir = Join-Path $RepoRoot 'payload'
$NvngxDir   = Join-Path $PayloadDir 'nvngx'
$BackupDir  = Join-Path $RepoRoot '_backup'
$Manifest   = Join-Path $BackupDir 'manifest.json'
$RuntimeUrl = 'https://github.com/SenjuWoo/LosslessScaling-DLSS5-Preset/releases/latest/download/nvngx-dlss5-runtime.zip'

$PayloadFiles = @(
    'dxgi.dll',
    'renodx-dlss.addon64',
    'ReShade.ini',
    'addons\LSP-Windowed\LSP_Windowed.dll',
    'addons\LSP-Windowed\icon.png'
)
# Lossless.dll is handled on its own (rename stock -> Lossless_original.dll, then drop the proxy
# in) so that a single manifest record owns undoing it.

# The four runtimes the add-on and the DLSS tool load out of the LS folder.
$RuntimeCore = @('nvngx_dlss.dll', 'nvngx_dlssd.dll', 'nvngx_dlssg.dll', 'nvngx_dlssnr.dll')

# Keys the Neural Rendering add-on needs. Written every run so an RHI reinstall cannot undo them.
$NrKeys = [ordered]@{
    'RENODX-DLSS'         = [ordered]@{
        'DirectNeuralRenderingHookMethod' = '2'
        'DirectNeuralRenderingHookPoint'  = '1'
        'DirectNeuralRenderingRequireDlss' = '0'
    }
    'RENODX-DLSS-preset1' = [ordered]@{
        'DirectNeuralRenderingPassCount'       = '1'
        'DirectNeuralRenderingProcessingScale' = '100'
        'DirectNeuralRenderingStyle'           = '2'
    }
}

$script:Counts = @{ Ok = 0; Add = 0; Replace = 0; Skip = 0; Fail = 0 }

function Say  { param([string]$Text, [string]$Tag = '    ') Write-Host ("[{0}] {1}" -f $Tag, $Text) }
function Ok   { param([string]$Text) $script:Counts.Ok++;      Say $Text ' ok ' }
function Add_ { param([string]$Text) $script:Counts.Add++;     Say $Text 'new ' }
function Repl { param([string]$Text) $script:Counts.Replace++; Say $Text 'repl' }
function Skip { param([string]$Text) $script:Counts.Skip++;    Say $Text 'skip' }
function Warn { param([string]$Text) Say $Text 'warn' }
function Fail { param([string]$Text) $script:Counts.Fail++;    Say $Text 'FAIL' }
function Head { param([string]$Text) Write-Host ''; Write-Host ("== " + $Text) -ForegroundColor Cyan }

# ---------------------------------------------------------------- Lossless Scaling discovery

. (Join-Path $PSScriptRoot 'common.ps1')

# ---------------------------------------------------------------- helpers

function Backup-Target {
    param([string]$LsDir, [string]$Rel)
    $dest = Join-Path $BackupDir ('files\' + $Rel)
    $dir  = Split-Path -Parent $dest
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    # First backup wins: on a re-install the file in the LS folder is already ours,
    # and the point of the backup is to hold the stock file.
    if (-not (Test-Path -LiteralPath $dest)) {
        Copy-Item -LiteralPath (Join-Path $LsDir $Rel) -Destination $dest -Force
    }
    return ('files\' + $Rel)
}

function Copy-Payload {
    param([string]$LsDir, [string]$Rel, [string]$SourceDir, [System.Collections.Generic.List[object]]$Records, [switch]$NoRecord)
    $src = Join-Path $SourceDir $Rel
    $dst = Join-Path $LsDir $Rel

    if (-not (Test-Path -LiteralPath $src)) { Fail "payload missing: $Rel"; return }

    $dstDir = Split-Path -Parent $dst
    if (-not (Test-Path -LiteralPath $dstDir)) { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }

    $existed = Test-Path -LiteralPath $dst -ErrorAction SilentlyContinue
    $backupRel = $null
    if ($existed -and -not $NoRecord -and -not $DryRun) { $backupRel = Backup-Target -LsDir $LsDir -Rel $Rel }

    if (-not $DryRun) { Copy-Item -LiteralPath $src -Destination $dst -Force }
    if (-not $NoRecord) {
        $Records.Add([pscustomobject]@{ path = $Rel; action = $(if ($existed) { 'replaced' } else { 'added' }); backup = $backupRel })
    }
    if ($existed) { Repl $Rel } else { Add_ $Rel }
}

function Set-IniKey {
    param([string]$Path, [string]$Section, [string]$Key, [string]$Value)
    $lines = @(Get-Content -LiteralPath $Path -Encoding UTF8)
    $out = New-Object System.Collections.Generic.List[string]
    $inSection = $false; $done = $false; $sectionFound = $false

    foreach ($line in $lines) {
        $t = $line.Trim()
        if ($t -match '^\[(.+)\]$') {
            if ($inSection -and -not $done) { $out.Add("$Key=$Value"); $done = $true }
            $inSection = ($matches[1].Trim() -eq $Section)
            if ($inSection) { $sectionFound = $true }
            $out.Add($line)
            continue
        }
        if ($inSection -and -not $done -and $t -match '^\s*([^=;#]+?)\s*=') {
            if ($matches[1].Trim() -eq $Key) { $out.Add("$Key=$Value"); $done = $true; continue }
        }
        $out.Add($line)
    }
    if ($inSection -and -not $done) { $out.Add("$Key=$Value"); $done = $true }
    if (-not $sectionFound) {
        if ($out.Count -gt 0 -and $out[$out.Count - 1].Trim() -ne '') { $out.Add('') }
        $out.Add("[$Section]")
        $out.Add("$Key=$Value")
    }
    [System.IO.File]::WriteAllLines($Path, $out, (New-Object System.Text.UTF8Encoding($false)))
}

function Get-Curl {
    $c = Join-Path $env:SystemRoot 'System32\curl.exe'
    if (Test-Path -LiteralPath $c) { return $c }
    $cmd = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Get-RuntimeArchive {
    param([string]$Dest)
    Head 'NVIDIA runtime (nvngx + Streamline)'
    Say ("source: " + $RuntimeUrl)

    if (-not (Test-Path -LiteralPath $Dest)) { New-Item -ItemType Directory -Path $Dest -Force | Out-Null }
    $zip = Join-Path $env:TEMP 'nvngx-dlss5-runtime.zip'

    $curl = Get-Curl
    if ($curl) {
        & $curl -L --fail --retry 3 --progress-bar -o $zip $RuntimeUrl
        if ($LASTEXITCODE -ne 0) { throw "download failed (curl exit $LASTEXITCODE). Get it by hand from the releases page and extract it into payload\nvngx." }
    } else {
        $old = $ProgressPreference; $ProgressPreference = 'Continue'
        try { Invoke-WebRequest -Uri $RuntimeUrl -OutFile $zip -UseBasicParsing } finally { $ProgressPreference = $old }
    }

    $hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
    Say ("sha256 " + $hash)
    if (-not (Test-Path -LiteralPath $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null }
    Set-Content -LiteralPath (Join-Path $BackupDir 'runtime.sha256') -Value "$hash  nvngx-dlss5-runtime.zip" -Encoding ASCII

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $tmp = Join-Path $env:TEMP ('dlss5rt_' + [guid]::NewGuid().ToString('N'))
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $tmp)
    Get-ChildItem -LiteralPath $tmp -Recurse -File | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $Dest $_.Name) -Force
    }
    Remove-Item -LiteralPath $tmp -Recurse -Force
    Remove-Item -LiteralPath $zip -Force
    Ok ("runtime unpacked into payload\nvngx (" + (Get-ChildItem -LiteralPath $Dest -Filter *.dll).Count + " dlls)")
}

# ---------------------------------------------------------------- verify

function Test-Install {
    param([string]$LsDir, [switch]$Quiet)

    $problems = 0
    if (-not $Quiet) { Head 'Verification' }

    foreach ($rel in ($PayloadFiles + $RuntimeCore)) {
        $p = Join-Path $LsDir $rel
        $good = (Test-Path -LiteralPath $p -ErrorAction SilentlyContinue) -and ((Get-Item -LiteralPath $p).Length -gt 0)
        if ($good) { if (-not $Quiet) { Ok $rel } }
        else { Fail ("missing or empty: " + $rel); $problems++ }
    }

    $orig = Join-Path $LsDir 'Lossless_original.dll'
    if (Test-Path -LiteralPath $orig -ErrorAction SilentlyContinue) {
        if (-not $Quiet) { Ok 'Lossless_original.dll (stock DLL kept for uninstall)' }
    } else {
        if (-not $Quiet) { Warn 'Lossless_original.dll not present - the proxy was not installed from a stock Lossless.dll' }
    }

    $ini = Join-Path $LsDir 'ReShade.ini'
    if (Test-Path -LiteralPath $ini -ErrorAction SilentlyContinue) {
        $txt = Get-Content -LiteralPath $ini -Raw -Encoding UTF8
        foreach ($sec in $NrKeys.Keys) {
            foreach ($k in $NrKeys[$sec].Keys) {
                if ($txt -match ('(?m)^\s*' + [regex]::Escape($k) + '\s*=\s*' + [regex]::Escape($NrKeys[$sec][$k]) + '\s*$')) {
                    if (-not $Quiet) { Ok ("ReShade.ini " + $k + "=" + $NrKeys[$sec][$k]) }
                } else {
                    Fail ("ReShade.ini " + $k + " is not " + $NrKeys[$sec][$k]); $problems++
                }
            }
        }
    } else {
        Fail 'ReShade.ini missing'; $problems++
    }

    if (-not $Quiet) {
        Write-Host ''
        if ($problems -eq 0) { Write-Host 'All checks passed. Start Lossless Scaling with LAUNCH-LosslessScaling.bat.' -ForegroundColor Green }
        else { Write-Host ("$problems check(s) failed. Re-run INSTALL.bat and read the output.") -ForegroundColor Yellow }
    }
    return $problems
}

# ---------------------------------------------------------------- main

Write-Host ''
Write-Host ' LosslessScaling-DLSS5-Preset - installer ' -ForegroundColor Black -BackgroundColor DarkCyan
Write-Host ''

$lsDir = Find-LsPath -Hint $LsPath
if (-not $lsDir) {
    Write-Host 'Lossless Scaling was not found in any Steam library on this machine.' -ForegroundColor Red
    Write-Host 'Install it from Steam, or run:  INSTALL.bat -LsPath "X:\path\to\Lossless Scaling"'
    exit 1
}
Ok ("Lossless Scaling: " + $lsDir)

$running = Get-Process -Name 'LosslessScaling' -ErrorAction SilentlyContinue
if ($running) {
    Write-Host ''
    Write-Host 'Lossless Scaling is running. Close it and run this again.' -ForegroundColor Red
    exit 1
}

if ($Verify) { exit (Test-Install -LsDir $lsDir) }

if ($DryRun) { Write-Host ''; Warn 'DRY RUN - nothing will be written' }

$records = New-Object System.Collections.Generic.List[object]

Head 'Proxy and add-on payload'
if (-not $DryRun -and -not (Test-Path -LiteralPath $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null }

# LosslessProxy replaces Lossless.dll. Keep the stock DLL under its upstream name so the
# manual procedure and this script produce the same folder layout.
$stockDll  = Join-Path $lsDir 'Lossless.dll'
$keptDll   = Join-Path $lsDir 'Lossless_original.dll'
if ((Test-Path -LiteralPath $stockDll) -and -not (Test-Path -LiteralPath $keptDll)) {
    if (-not $DryRun) { Move-Item -LiteralPath $stockDll -Destination $keptDll -Force }
    Ok 'Lossless.dll -> Lossless_original.dll (stock DLL kept)'
} elseif (Test-Path -LiteralPath $keptDll) {
    Skip 'Lossless_original.dll already present - proxy already installed once'
}
# Recorded on every run, including re-installs, so uninstall can always put the stock DLL back.
if (Test-Path -LiteralPath $keptDll) {
    $records.Add([pscustomobject]@{ path = 'Lossless_original.dll'; action = 'renamed'; backup = $null })
}
# The proxy itself is not recorded: the rename record above already owns the reversal.
Copy-Payload -LsDir $lsDir -Rel 'Lossless.dll' -SourceDir $PayloadDir -Records $records -NoRecord

foreach ($rel in $PayloadFiles) { Copy-Payload -LsDir $lsDir -Rel $rel -SourceDir $PayloadDir -Records $records }

Head 'NVIDIA runtime'
$haveRuntime = (Test-Path -LiteralPath (Join-Path $NvngxDir 'nvngx_dlssnr.dll') -ErrorAction SilentlyContinue)
if ($SkipRuntime) {
    Skip 'runtime copy skipped (-SkipRuntime)'
} elseif (-not $haveRuntime -and -not $DryRun) {
    Get-RuntimeArchive -Dest $NvngxDir
    $haveRuntime = $true
} elseif ($haveRuntime) {
    Ok 'runtime already in payload\nvngx'
} else {
    Say 'runtime would be downloaded into payload\nvngx'
}

if ($haveRuntime -or $DryRun) {
    $runtimeSrc = @()
    if (Test-Path -LiteralPath $NvngxDir) { $runtimeSrc = @(Get-ChildItem -LiteralPath $NvngxDir -Filter *.dll -File -ErrorAction SilentlyContinue) }
    if ($runtimeSrc.Count -eq 0) {
        Warn 'no runtime DLLs in payload\nvngx - the add-on will not find nvngx_dlssnr.dll'
    } else {
        foreach ($f in $runtimeSrc) {
            Copy-Payload -LsDir $lsDir -Rel $f.Name -SourceDir $NvngxDir -Records $records
        }
    }
}

Head 'Neural Rendering keys in ReShade.ini'
$iniPath = Join-Path $lsDir 'ReShade.ini'
if (-not $DryRun) {
    foreach ($sec in $NrKeys.Keys) {
        foreach ($k in $NrKeys[$sec].Keys) { Set-IniKey -Path $iniPath -Section $sec -Key $k -Value $NrKeys[$sec][$k] }
    }
}
Ok 'DirectNeuralRendering* written (HookMethod=2, HookPoint=1, RequireDlss=0)'
Ok 'preset1 written (1 pass, scale 100, style 2)'

if (-not $DryRun) {
    if (-not (Test-Path -LiteralPath $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null }

    # Merge with any previous manifest for this same folder. The first record of a file is the
    # one that knows whether the preset added it or replaced something, so a re-install must not
    # overwrite it - otherwise uninstall would restore our own files instead of removing them.
    $prev = @{}
    if (Test-Path -LiteralPath $Manifest) {
        try {
            $old = Get-Content -LiteralPath $Manifest -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($old.lsPath -eq $lsDir) {
                foreach ($r in @($old.files)) { if ($r -and $r.path) { $prev[[string]$r.path] = $r } }
            }
        } catch { Warn 'previous manifest unreadable - starting a fresh one' }
    }

    $merged = New-Object System.Collections.Generic.List[object]
    $seen = @{}
    foreach ($r in $records) {
        if ($prev.ContainsKey($r.path)) { $merged.Add($prev[$r.path]) } else { $merged.Add($r) }
        $seen[$r.path] = $true
    }
    foreach ($k in $prev.Keys) { if (-not $seen.ContainsKey($k)) { $merged.Add($prev[$k]) } }

    $doc = [pscustomobject]@{
        preset    = 'LosslessScaling-DLSS5-Preset'
        version   = '1.0.0'
        lsPath    = $lsDir
        installed = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        files     = $merged
    }
    $doc | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $Manifest -Encoding UTF8
    Say ("manifest: " + $Manifest + " (" + $merged.Count + " entries)")
}

$failed = Test-Install -LsDir $lsDir

Write-Host ''
Write-Host ("  added {0} | replaced {1} | skipped {2} | failed {3}" -f $script:Counts.Add, $script:Counts.Replace, $script:Counts.Skip, $script:Counts.Fail)
Write-Host ''

if ($failed -gt 0) { exit 1 }

if (-not $NoLaunch -and -not $DryRun) {
    $answer = Read-Host 'Start Lossless Scaling now? (Y/n)'
    if ($answer -eq '' -or $answer -match '^[Yy]') {
        & (Join-Path $PSScriptRoot 'launch.ps1')
    } else {
        Write-Host 'Later: double-click LAUNCH-LosslessScaling.bat (not Steam, and not the exe directly).'
    }
}
exit 0
