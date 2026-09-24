@echo off
REM Run a staged test build and capture stdout/stderr to playtorrio-console.log.
REM
REM Usage: scripts\run_windows.bat [folder]
REM
REM With no argument the newest %TEMP%\PlayTorrioMov-dev-* folder is used --
REM what scripts\build_windows.bat just produced. Releases live on GitHub and
REM local builds live in temp, so this never looks at build\.

setlocal enabledelayedexpansion

if "%~1"=="" (
  set RELEASE_DIR=
  for /f "delims=" %%d in ('dir /b /ad /o-d "%TEMP%\PlayTorrioMov-dev-*" 2^>nul') do (
    if not defined RELEASE_DIR set RELEASE_DIR=%TEMP%\%%d
  )
) else (
  set RELEASE_DIR=%~1
)

if not defined RELEASE_DIR (
  echo No staged test build found. Run scripts\build_windows.bat first,
  echo or pass the folder explicitly:
  echo   scripts\run_windows.bat ^<folder^>
  exit /b 1
)

if not exist "%RELEASE_DIR%\PlayTorrioMov.exe" (
  echo PlayTorrioMov.exe not found in %RELEASE_DIR%
  exit /b 1
)

echo Running PlayTorrioMov.exe from %RELEASE_DIR%
pushd "%RELEASE_DIR%"
:: One log, both streams. This used to be a Start-Process with
:: -RedirectStandardOutput and -RedirectStandardError pointed at the *same*
:: file, which PowerShell rejects outright ("cannot be run because ... are
:: same"), so the script never launched anything. `cmd` with `2>&1` merges
:: them into the single file that was always the intent.
cmd /c "PlayTorrioMov.exe > playtorrio-console.log 2>&1"
if %ERRORLEVEL% NEQ 0 (
  echo Application exited with code %ERRORLEVEL%
) else (
  echo Application exited normally. Log: %RELEASE_DIR%\playtorrio-console.log
)
popd
exit /b 0
