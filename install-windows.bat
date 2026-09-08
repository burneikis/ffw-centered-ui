@echo off
setlocal enabledelayedexpansion
rem Copies CenteredHUD into the game's ue4ss\Mods folder.
rem Usage: double click, or  install-windows.bat "D:\Steam\steamapps\common\FarFarWest"

set "SRC=%~dp0Mods"
set "GAME=%~1"

if "%GAME%"=="" (
  for %%D in (
    "C:\Program Files (x86)\Steam\steamapps\common\FarFarWest"
    "C:\SteamLibrary\steamapps\common\FarFarWest"
    "D:\SteamLibrary\steamapps\common\FarFarWest"
    "E:\SteamLibrary\steamapps\common\FarFarWest"
  ) do if exist "%%~D\FarFarWest\Binaries\Win64" set "GAME=%%~D"
)

if "%GAME%"=="" (
  echo Could not find Far Far West.
  echo Run: install-windows.bat "C:\path\to\steamapps\common\FarFarWest"
  pause & exit /b 1
)

set "MODS=%GAME%\FarFarWest\Binaries\Win64\ue4ss\Mods"
if not exist "%MODS%" (
  echo ue4ss\Mods not found in "%GAME%".
  echo Install UE4SS first - see INSTALL-WINDOWS.md
  pause & exit /b 1
)

set "KEEP="
if exist "%MODS%\CenteredHUD\config.ini" (
  copy /y "%MODS%\CenteredHUD\config.ini" "%TEMP%\ffw-config.ini" >nul
  set "KEEP=1"
)

xcopy /e /i /y "%SRC%\CenteredHUD" "%MODS%\CenteredHUD" >nul || (
  echo Copy failed. & pause & exit /b 1
)

if defined KEEP (
  copy /y "%TEMP%\ffw-config.ini" "%MODS%\CenteredHUD\config.ini" >nul
  echo Kept your existing config.ini
)

echo Installed to "%MODS%\CenteredHUD"
echo Start the game. F8 reloads config.ini.
pause
