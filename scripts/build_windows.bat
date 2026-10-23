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

REM The torrserver_flutter plugin downloads its TorrServer binary from a repo that
REM no longer exists, so a clean build fails at install. Stage the pinned official
REM build from our own release instead, the same way CI does, and point the plugin
REM at it. A checksum mismatch deletes the file and stops the build.
set TS_DIR=%TEMP%\torrserver-stage
set TS_BIN=%TS_DIR%\torrserver-windows-amd64.exe
set TS_SHA=92624fffc72c79d87041f6624850070e466972323ed28f14881a4c0a0c943ee6
set TS_URL=https://github.com/MediaHub-Org/PlayTorrioMov/releases/download/torrserver-MatriX.148/torrserver-windows-amd64.exe
if not exist "%TS_DIR%" mkdir "%TS_DIR%"
if not exist "%TS_BIN%" (
  echo Fetching the pinned TorrServer binary ...
  curl.exe -fsSL -o "%TS_BIN%" "%TS_URL%"
  if errorlevel 1 (
    echo TorrServer download failed.
    exit /b 1
  )
)
set TS_GOT=
for /f "skip=1 delims=" %%h in ('certutil -hashfile "%TS_BIN%" SHA256') do if not defined TS_GOT set TS_GOT=%%h
if /i not "%TS_GOT%"=="%TS_SHA%" (
  echo TorrServer checksum mismatch; removing the file.
  del "%TS_BIN%"
  exit /b 1
)
set TORRSERVER_FLUTTER_LOCAL_BINARIES=%TS_DIR%

echo Building Windows dev build (flutter build windows --release --dart-define=APP_CHANNEL=%CHANNEL%)...
REM `call`, not a bare `flutter`: flutter is a .bat, and running a batch file
REM without `call` hands this script's control to it for good -- everything
REM after the build, the staging included, never ran.
REM The keys in .env (Dropbox, Simkl, ...) are compiled in, as CI does, so a
REM local test build can exercise the sign-in flows.
set ENV_DEFINE=
if exist .env set ENV_DEFINE=--dart-define-from-file=.env
call flutter build windows --release %ENV_DEFINE% --dart-define=APP_CHANNEL=%CHANNEL%
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
