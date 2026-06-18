@echo off
setlocal EnableExtensions

rem Renegade X dedicated server launcher.
rem Place this file in the Renegade X root folder, next to Binaries and UDKGame.

set "RENX_ROOT=%~dp0"
set "RENX_BIN=%RENX_ROOT%Binaries\Win64\UDK.exe"
set "RENX_CONSOLE=%RENX_ROOT%Binaries\Win64\UDK.com"

if not exist "%RENX_BIN%" (
  echo ERROR: Could not find %RENX_BIN%
  exit /b 1
)

if "%RENX_MAP%"=="" set "RENX_MAP=CNC-Field"
if "%RENX_MAX_PLAYERS%"=="" set "RENX_MAX_PLAYERS=40"
if "%RENX_GAME_PORT%"=="" set "RENX_GAME_PORT=7777"
if "%RENX_LOG_FILE%"=="" set "RENX_LOG_FILE=RenegadeXServer.log"

if exist "%RENX_CONSOLE%" (
  set "RENX_RUNNER=%RENX_CONSOLE%"
) else (
  set "RENX_RUNNER=%RENX_BIN%"
)

set "RENX_URL=%RENX_MAP%?maxplayers=%RENX_MAX_PLAYERS%"

if not "%RENX_GAME_CLASS%"=="" set "RENX_URL=%RENX_URL%?Game=%RENX_GAME_CLASS%"
if not "%RENX_MUTATORS%"=="" set "RENX_URL=%RENX_URL%?mutator=%RENX_MUTATORS%"
if not "%RENX_GDI_BOTS%"=="" set "RENX_URL=%RENX_URL%?GDIBotCount=%RENX_GDI_BOTS%"
if not "%RENX_NOD_BOTS%"=="" set "RENX_URL=%RENX_URL%?NODBotCount=%RENX_NOD_BOTS%"

set "RENX_ARGS=server %RENX_URL% -port=%RENX_GAME_PORT% -abslog=%RENX_LOG_FILE% -forcelogflush -unattended -nullrhi -nosound"

if not "%RENX_MULTIHOME%"=="" set "RENX_ARGS=%RENX_ARGS% -MULTIHOME=%RENX_MULTIHOME%"
if not "%RENX_EXTRA_ARGS%"=="" set "RENX_ARGS=%RENX_ARGS% %RENX_EXTRA_ARGS%"

echo Starting Renegade X dedicated server...
echo Root: %RENX_ROOT%
echo Map: %RENX_MAP%
echo Players: %RENX_MAX_PLAYERS%
echo Game port: %RENX_GAME_PORT%
echo Executable: %RENX_RUNNER%
echo Persistent log: %RENX_LOG_FILE%
if not "%RENX_MUTATORS%"=="" echo Mutators: %RENX_MUTATORS%

cd /d "%RENX_ROOT%Binaries\Win64"
"%RENX_RUNNER%" %RENX_ARGS%
set "RENX_EXIT=%ERRORLEVEL%"

echo Renegade X process exited with code %RENX_EXIT%.

exit /b %RENX_EXIT%
