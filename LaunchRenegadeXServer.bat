@echo off
setlocal EnableExtensions

rem Renegade X dedicated server launcher.
rem Place this file in the Renegade X root folder, next to Binaries and UDKGame.

set "RENX_ROOT=%~dp0"
set "RENX_BIN=%RENX_ROOT%Binaries\Win64\UDK.exe"

if not exist "%RENX_BIN%" (
  echo ERROR: Could not find %RENX_BIN%
  exit /b 1
)

if "%RENX_MAP%"=="" set "RENX_MAP=CNC-Field"
if "%RENX_GAME_CLASS%"=="" set "RENX_GAME_CLASS=RenX_Game.Rx_Game"
if "%RENX_MAX_PLAYERS%"=="" set "RENX_MAX_PLAYERS=40"
if "%RENX_GAME_PORT%"=="" set "RENX_GAME_PORT=7777"
if "%RENX_LOG_FILE%"=="" set "RENX_LOG_FILE=RenegadeXServer.log"

set "RENX_URL=%RENX_MAP%?Game=%RENX_GAME_CLASS%?MaxPlayers=%RENX_MAX_PLAYERS%?Port=%RENX_GAME_PORT%"

if not "%RENX_ADMIN_PASSWORD%"=="" set "RENX_URL=%RENX_URL%?AdminPassword=%RENX_ADMIN_PASSWORD%"
if not "%RENX_SERVER_PASSWORD%"=="" set "RENX_URL=%RENX_URL%?GamePassword=%RENX_SERVER_PASSWORD%"

echo Starting Renegade X dedicated server...
echo Root: %RENX_ROOT%
echo Map: %RENX_MAP%
echo Game class: %RENX_GAME_CLASS%
echo Players: %RENX_MAX_PLAYERS%
echo Game port: %RENX_GAME_PORT%

cd /d "%RENX_ROOT%Binaries\Win64"
"%RENX_BIN%" server %RENX_URL% -log=%RENX_LOG_FILE% -unattended %RENX_EXTRA_ARGS%

exit /b %ERRORLEVEL%
