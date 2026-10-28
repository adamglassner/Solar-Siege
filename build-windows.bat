@echo off
setlocal
title Solar Siege - Build Windows Installer
cd /d "%~dp0"

rem ---- Edit these two lines if your tools live somewhere else -------------------
set "GODOT=C:\Godot\Godot_v4.7.2-stable_win64.exe"
set "MAKENSIS=C:\Program Files (x86)\NSIS\makensis.exe"
rem -------------------------------------------------------------------------------

echo.
echo  ===========================================
echo    Solar Siege - Windows installer builder
echo  ===========================================
echo.
if not exist "%GODOT%" (
  echo  Godot was not found at:
  echo    %GODOT%
  echo  Download Godot 4.7.2 from https://godotengine.org/download/windows
  echo  then edit the GODOT line at the top of this file.
  goto :fail
)
if not exist "%MAKENSIS%" (
  echo  NSIS was not found at:
  echo    %MAKENSIS%
  echo  Install NSIS 3 from https://nsis.sourceforge.io/Download
  echo  or edit the MAKENSIS line at the top of this file.
  goto :fail
)

if not exist build\windows mkdir build\windows
echo  [1/2] Exporting the game with Godot...
"%GODOT%" --headless --path . --export-release "Windows Desktop" build/windows/SolarSiege.exe
if not exist build\windows\SolarSiege.exe (
  echo  Export failed. In Godot, open Editor ^> Manage Export Templates and download them, then try again.
  goto :fail
)

echo  [2/2] Building the installer...
"%MAKENSIS%" /V2 installer\solar-siege.nsi
if errorlevel 1 goto :fail

echo.
echo  Done! Your installer is in the "build" folder:
dir /b build\*.exe
start "" "%~dp0build"
echo.
pause
exit /b 0

:fail
echo.
echo  Something went wrong. Scroll up to see the message.
pause
exit /b 1
