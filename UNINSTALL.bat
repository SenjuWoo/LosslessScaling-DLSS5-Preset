@echo off
setlocal
title LosslessScaling-DLSS5-Preset - Uninstall
cd /d "%~dp0"

REM Same reasoning as INSTALL.bat: no self-elevation, because arguments do not survive
REM the UAC hop and a half-elevated uninstall is worse than none.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\uninstall.ps1" %*
set "RC=%errorlevel%"

if not "%RC%"=="0" (
  echo.
  echo   Uninstaller exited with code %RC%. Read the lines above.
  echo.
  echo   "Cannot write" means the folder needs administrator rights:
  echo     right-click UNINSTALL.bat  ^>  "Run as administrator"
  echo.
  pause
)
exit /b %RC%
