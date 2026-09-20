@echo off
setlocal
title LosslessScaling-DLSS5-Preset - Install
cd /d "%~dp0"

REM No elevation here on purpose. If your Steam library sits under C:\Program Files the
REM installer says so and tells you to right-click this file -> "Run as administrator".
REM Elevating from inside this script cannot pass arguments through the Windows UAC hop,
REM so it would silently install into the wrong folder.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\install.ps1" %*
set "RC=%errorlevel%"

if not "%RC%"=="0" (
  echo.
  echo   Installer exited with code %RC%. Read the lines above.
  echo.
  echo   "Cannot write" means the folder needs administrator rights:
  echo     right-click INSTALL.bat  ^>  "Run as administrator"
  echo.
  echo   Full log: %LOCALAPPDATA%\LosslessScaling-DLSS5-Preset\install.log
  pause
)
exit /b %RC%
