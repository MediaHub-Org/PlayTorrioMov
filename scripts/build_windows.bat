@echo off
REM Build a Windows dev build and stage it in the temp folder for local QA.
REM
REM Usage: scripts\build_windows.bat [stamp]
REM
REM The output goes to %TEMP%\PlayTorrioMov-dev-<stamp>, never into build\.
REM Releases are built and published by GitHub Actions; a local build is for
REM testing and is disposable. Keeping it out of the repo stops build\ growing
REM a fresh ~140 MB on every run.
REM
REM Pass a stamp to rebuild over an earlier folder (e.g. "nightly"); without
REM one a timestamp is used, so two builds never collide.

setlocal

if "%~1"=="" (
  REM PowerShell, not %DATE%: the plain variable's layout is locale-dependent,
  REM so the substring slicing this used to do produced garbage outside US
  REM formats.
  for /f "delims=" %%t in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set STAMP=%%t
) else (
  set STAMP=%~1
)

set CHANNEL=dev
set DEST=%TEMP%\PlayTorrioMov-dev-%STAMP%

echo Building Windows dev build (flutter build windows --release --dart-define=APP_CHANNEL=%CHANNEL%)...
REM `call`, not a bare `flutter`: flutter is a .bat, and running a batch file
REM without `call` hands this script's control to it for good -- everything
REM after the build, the staging included, never ran.
call flutter build windows --release --dart-define=APP_CHANNEL=%CHANNEL%
if %ERRORLEVEL% NEQ 0 (
  echo Build failed with exit code %ERRORLEVEL%.
  exit /b %ERRORLEVEL%
)

set RELEASE_DIR=build\windows\x64\runner\Release
if not exist "%RELEASE_DIR%\PlayTorrioMov.exe" (
  echo Expected executable not found in %RELEASE_DIR%
  exit /b 1
)

echo Staging to %DEST% ...
if exist "%DEST%" rmdir /s /q "%DEST%"
mkdir "%DEST%"
xcopy /s /e /i /q /y "%RELEASE_DIR%\*" "%DEST%\" >nul
if %ERRORLEVEL% NEQ 0 (
  echo Staging failed.
  exit /b %ERRORLEVEL%
)

echo Done. Test build: %DEST%
exit /b 0
