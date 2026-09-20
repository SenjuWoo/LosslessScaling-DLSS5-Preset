# End-to-end check for install.ps1 / uninstall.ps1.
# Builds a throwaway repo copy and a fake Lossless Scaling folder, runs the real scripts
# as child processes, and asserts the resulting folder state. No network, no real game files.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\test-install.ps1
$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
$tmp  = Join-Path $env:TEMP ('lspreset-test-' + [guid]::NewGuid().ToString('N'))
$script:pass = 0
$script:fail = 0

function Check {
    param([string]$Name, [bool]$Condition)
    if ($Condition) { Write-Host ("  PASS  " + $Name) -ForegroundColor Green; $script:pass++ }
    else            { Write-Host ("  FAIL  " + $Name) -ForegroundColor Red;   $script:fail++ }
}
function Text { param([string]$Path) if (Test-Path -LiteralPath $Path) { return (Get-Content -LiteralPath $Path -Raw).Trim() } return $null }
function Run  {
    param([string]$Script, [string[]]$ScriptArgs)
    # NOTE: never name this parameter $Args - it collides with PowerShell's reserved automatic
    # variable and the splat silently expands to nothing, so the child runs with no arguments.
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tmp ('repo\scripts\' + $Script)) @ScriptArgs 2>&1
    return @{ code = $LASTEXITCODE; out = ($out | Out-String) }
}

try {
    Write-Host ''
    Write-Host 'Building sandbox...'
    $sandRepo = Join-Path $tmp 'repo'
    New-Item -ItemType Directory -Path $sandRepo -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $repo 'scripts') -Destination $sandRepo -Recurse -Force
    Copy-Item -LiteralPath (Join-Path $repo 'payload') -Destination $sandRepo -Recurse -Force

    # Stand-ins for the 275 MB runtime, so -SkipRuntime still satisfies verification.
    foreach ($n in @('nvngx_dlss.dll', 'nvngx_dlssd.dll', 'nvngx_dlssg.dll', 'nvngx_dlssnr.dll', 'sl.common.dll')) {
        Set-Content -LiteralPath (Join-Path $sandRepo ('payload\nvngx\' + $n)) -Value 'fake-runtime' -Encoding ASCII
    }

    $ls = Join-Path $tmp 'ls'
    New-Item -ItemType Directory -Path $ls -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $ls 'LosslessScaling.exe') -Value 'fake-exe' -Encoding ASCII
    Set-Content -LiteralPath (Join-Path $ls 'Lossless.dll')         -Value 'STOCK-DLL' -Encoding ASCII
    Set-Content -LiteralPath (Join-Path $ls 'config.ini')           -Value '[rendering]' -Encoding ASCII
    $userIni = "[ADDON]`r`nDisabledAddons=`r`n`r`n[OVERLAY]`r`nShowFPS=0`r`n"
    Set-Content -LiteralPath (Join-Path $ls 'ReShade.ini') -Value $userIni -Encoding ASCII

    Write-Host 'Running install.ps1...'
    $r = Run 'install.ps1' @('-LsPath', $ls, '-SkipRuntime', '-NoLaunch')
    Check 'installer exits 0' ($r.code -eq 0)
    # Guard against the arguments never reaching the child (a silent arg-loss bug would
    # otherwise install into the machine's real Lossless Scaling folder and still exit 0).
    Check 'installer targeted the sandbox' ($r.out -like ('*' + $ls + '*'))
    if ($r.code -ne 0 -or -not ($r.out -like ('*' + $ls + '*'))) { Write-Host $r.out }

    Check 'proxy Lossless.dll installed'      ((Text (Join-Path $ls 'Lossless.dll')) -ne 'STOCK-DLL')
    Check 'stock DLL kept as _original'       ((Text (Join-Path $ls 'Lossless_original.dll')) -eq 'STOCK-DLL')
    Check 'dxgi.dll (ReShade) installed'      ((Get-Item (Join-Path $ls 'dxgi.dll')).Length -gt 1000000)
    Check 'renodx-dlss.addon64 installed'     ((Get-Item (Join-Path $ls 'renodx-dlss.addon64')).Length -gt 1000000)
    Check 'LSP-Windowed addon installed'      (Test-Path -LiteralPath (Join-Path $ls 'addons\LSP-Windowed\LSP_Windowed.dll'))
    Check 'runtime DLLs copied'               ((Text (Join-Path $ls 'nvngx_dlssnr.dll')) -eq 'fake-runtime')
    Check 'manifest written'                  (Test-Path -LiteralPath (Join-Path $tmp 'repo\_backup\manifest.json'))
    Check 'user ReShade.ini backed up'        ((Text (Join-Path $tmp 'repo\_backup\files\ReShade.ini')) -eq $userIni.Trim())

    $ini = Text (Join-Path $ls 'ReShade.ini')
    # \s* before $ because the ini is CRLF: a bare $ never matches before the \r.
    Check 'NR hook method written'            ($ini -match '(?m)^DirectNeuralRenderingHookMethod=2\s*$')
    Check 'NR hook point written'             ($ini -match '(?m)^DirectNeuralRenderingHookPoint=1\s*$')
    Check 'NR require-dlss written'           ($ini -match '(?m)^DirectNeuralRenderingRequireDlss=0\s*$')
    Check 'preset1 pass count written'        ($ini -match '(?m)^DirectNeuralRenderingPassCount=1\s*$')
    Check 'no hardcoded user temp path'       (-not ($ini -match 'C:\\Users\\'))
    Check 'ini has no UTF-8 BOM'              ((Get-Content -LiteralPath (Join-Path $ls 'ReShade.ini') -Encoding Byte -TotalCount 3) -join ',' -ne '239,187,191')

    Write-Host 'Running install.ps1 again (idempotency)...'
    $r2 = Run 'install.ps1' @('-LsPath', $ls, '-SkipRuntime', '-NoLaunch')
    Check 're-install exits 0' ($r2.code -eq 0)
    Check 'stock DLL still intact after re-install'  ((Text (Join-Path $ls 'Lossless_original.dll')) -eq 'STOCK-DLL')
    # keep-first rule: the backup must still hold the user's ORIGINAL ini, not our own copy.
    Check 'original ini backup not clobbered'        ((Text (Join-Path $tmp 'repo\_backup\files\ReShade.ini')) -eq $userIni.Trim())

    Write-Host 'Running -Verify...'
    $rv = Run 'install.ps1' @('-LsPath', $ls, '-Verify')
    Check 'verify exits 0 on a good install' ($rv.code -eq 0)

    Write-Host 'Running uninstall.ps1...'
    $ru = Run 'uninstall.ps1' @('-LsPath', $ls)
    Check 'uninstall exits 0' ($ru.code -eq 0)
    Check 'stock Lossless.dll restored'   ((Text (Join-Path $ls 'Lossless.dll')) -eq 'STOCK-DLL')
    Check 'proxy copy removed'            (-not (Test-Path -LiteralPath (Join-Path $ls 'Lossless_original.dll')))
    Check 'added dxgi.dll removed'        (-not (Test-Path -LiteralPath (Join-Path $ls 'dxgi.dll')))
    Check 'added runtime removed'         (-not (Test-Path -LiteralPath (Join-Path $ls 'nvngx_dlssnr.dll')))
    Check 'user ReShade.ini restored'     ((Text (Join-Path $ls 'ReShade.ini')) -eq $userIni.Trim())
    Check 'LSP-Windowed folder removed'   (-not (Test-Path -LiteralPath (Join-Path $ls 'addons\LSP-Windowed')))
    Check 'backup dir cleaned up'         (-not (Test-Path -LiteralPath (Join-Path $tmp 'repo\_backup')))

    Write-Host ''
    Write-Host ("  $script:pass passed, $script:fail failed")
    Write-Host ''
    exit $(if ($script:fail -gt 0) { 1 } else { 0 })
}
finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
