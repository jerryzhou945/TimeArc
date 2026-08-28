@echo off
REM ============================================================
REM  TimeArc build-free launcher
REM  Sets up the Qt/MinGW toolchain on PATH and launches an
REM  ALREADY-BUILT TimeArc.exe. Does NOT kill running instances
REM  and does NOT rebuild -- use this to open extra windows
REM  (e.g. the mobile preview) alongside one started by run.cmd.
REM  Usage:  .\launch                    (desktop window)
REM          .\launch --mobile-preview   (mobile window)
REM  Any arguments are forwarded to TimeArc.exe.
REM ============================================================
setlocal

set "ENV_ROOT=C:\code_env\Qt-6.11.0-MinGW64"
set "QT=%ENV_ROOT%\6.11.0\mingw_64"
set "MINGW=%ENV_ROOT%\Tools\mingw1310_64\bin"
set "NINJA=%ENV_ROOT%\Tools\Ninja"
set "PATH=%QT%\bin;%MINGW%;%NINJA%;%PATH%"

set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"

if not exist "%ROOT%\build\TimeArc.exe" (
    echo [launch] build\TimeArc.exe not found. Run .\run first to build.
    exit /b 1
)

echo [launch] Launching TimeArc %*...
start "TimeArc" "%ROOT%\build\TimeArc.exe" %*
echo [launch] Done.
endlocal
