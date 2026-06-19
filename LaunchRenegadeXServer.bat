@echo off
setlocal EnableExtensions

rem Renegade X dedicated server launcher.
rem Place this file in the Renegade X root folder, next to Binaries and UDKGame.

if "%RENX_BOOTSTRAP_ROOT%"=="" set "RENX_BOOTSTRAP_ROOT=C:\renx-bootstrap"
set "RENX_RUNNER_SCRIPT=%RENX_BOOTSTRAP_ROOT%\RunRenX.ps1"

if not exist "%RENX_RUNNER_SCRIPT%" (
  echo ERROR: Could not find %RENX_RUNNER_SCRIPT%
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%RENX_RUNNER_SCRIPT%"
set "RENX_EXIT=%ERRORLEVEL%"

exit /b %RENX_EXIT%
