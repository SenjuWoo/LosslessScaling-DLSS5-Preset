@echo off
setlocal
title LosslessScaling-DLSS5-Preset - Launch Lossless Scaling
cd /d "%~dp0"

REM No elevation: the HW-acceleration key is under HKCU and LS runs as you.
if not "%~1"=="" set "PRESET_ARGS=%*"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\launch.ps1" %PRESET_ARGS%
set "RC=%errorlevel%"

if not "%RC%"=="0" (
  echo.
  echo   Launcher exited with code %RC%. Read the lines above.
  pause
)
exit /b %RC%
