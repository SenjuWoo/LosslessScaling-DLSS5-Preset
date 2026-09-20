@echo off
setlocal
title LosslessScaling-DLSS5-Preset - Uninstall
cd /d "%~dp0"

if not "%~1"=="" set "PRESET_ARGS=%*"

net session >nul 2>&1
if %errorlevel% neq 0 (
  echo.
  echo   Removing files from the Lossless Scaling folder needs administrator rights.
  echo.
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  if %errorlevel% neq 0 (
    echo   Elevation was declined or failed. Right-click UNINSTALL.bat and pick "Run as administrator".
    pause
  )
  exit /b
)

echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\uninstall.ps1" %PRESET_ARGS%
set "RC=%errorlevel%"

if not "%RC%"=="0" (
  echo.
  echo   Uninstaller exited with code %RC%. Read the lines above.
  pause
)
exit /b %RC%
