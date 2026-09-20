@echo off
setlocal
title LosslessScaling-DLSS5-Preset - Install
cd /d "%~dp0"

if not "%~1"=="" set "PRESET_ARGS=%*"

REM Steam usually lives under Program Files, so the copy needs administrator rights.
net session >nul 2>&1
if %errorlevel% neq 0 (
  echo.
  echo   This needs administrator rights to write into the Lossless Scaling folder.
  echo   Approve the Windows prompt. Nothing else on your PC is touched.
  echo.
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  if %errorlevel% neq 0 (
    echo   Elevation was declined or failed. Right-click INSTALL.bat and pick "Run as administrator".
    pause
  )
  exit /b
)

echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\install.ps1" %PRESET_ARGS%
set "RC=%errorlevel%"

if not "%RC%"=="0" (
  echo.
  echo   Installer exited with code %RC%. Read the lines above.
  echo   Full log: %LOCALAPPDATA%\Temp\LosslessScaling-DLSS5-Preset_install.log
  pause
)
exit /b %RC%
