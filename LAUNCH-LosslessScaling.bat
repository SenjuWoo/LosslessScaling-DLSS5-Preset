@echo off
setlocal
title LosslessScaling-DLSS5-Preset - Launch Lossless Scaling
cd /d "%~dp0"

REM No elevation: the HW-acceleration key is under HKCU and LS runs as you.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\launch.ps1" %*
set "RC=%errorlevel%"

if not "%RC%"=="0" (
  echo.
  echo   Launcher exited with code %RC%. Read the lines above.
  pause
)
exit /b %RC%
