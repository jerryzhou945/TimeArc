@echo off
REM ============================================================
REM  TimeArc build-free launcher   (FORK-LOCAL -- never contributed upstream)
REM  Configures the Qt/MinGW/Ninja toolchain on PATH and launches an
REM  ALREADY-BUILT TimeArc.exe. Does NOT kill running instances and does NOT
REM  rebuild -- use this to open extra windows (e.g. the mobile preview)
REM  alongside one started by run.cmd.
REM    .\launch                    (desktop window)
REM    .\launch --mobile-preview   (mobile window)
REM  Any arguments are forwarded to TimeArc.exe.
REM
REM  Toolchain ROOT resolution is identical to run.cmd:
REM    1. launch.local.cmd / run.local.cmd  (gitignored, per-machine)
REM    2. %TIMEARC_QT_ROOT%
REM    3. the built-in probe list
REM ============================================================
setlocal

REM Project root = this script's folder, no trailing backslash (path may contain spaces).
set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"

REM --- Resolve QTROOT: (1) per-machine override, (2) env var, (3) probe ---
set "QTROOT="
if exist "%ROOT%\launch.local.cmd" call "%ROOT%\launch.local.cmd"
if not defined QTROOT if exist "%ROOT%\run.local.cmd" call "%ROOT%\run.local.cmd"
if not defined QTROOT if defined TIMEARC_QT_ROOT set "QTROOT=%TIMEARC_QT_ROOT%"
if not defined QTROOT (
    for %%R in ("C:\Qt" "D:\TimeArc\QT" "D:\Qt" "E:\Qt" "C:\TimeArc\QT") do (
        if not defined QTROOT if exist "%%~R\Tools\mingw1310_64\bin\g++.exe" set "QTROOT=%%~R"
    )
)
if not defined QTROOT (
    echo [launch] No Qt toolchain found. Set env TIMEARC_QT_ROOT, or create run.local.cmd
    echo [launch] next to this script containing:  set "QTROOT=C:\Qt"   -- fork-local, do not contribute.
    exit /b 1
)

REM --- Derive Qt 6.x mingw_64 + companion tools from QTROOT ---
set "QT="
for /d %%V in ("%QTROOT%\6.*") do if exist "%%~V\mingw_64\bin\qmake.exe" set "QT=%%~V\mingw_64"
if not defined QT (
    echo [launch] No Qt 6.x mingw_64 build found under "%QTROOT%".
    exit /b 1
)
set "MINGW=%QTROOT%\Tools\mingw1310_64\bin"
set "NINJA=%QTROOT%\Tools\Ninja"
set "CMAKE=%QTROOT%\Tools\CMake_64\bin"

set "PATH=%QT%\bin;%MINGW%;%PATH%"
if exist "%NINJA%\ninja.exe" set "PATH=%NINJA%;%PATH%"
if exist "%CMAKE%\cmake.exe" set "PATH=%CMAKE%;%PATH%"

if not exist "%ROOT%\build\TimeArc.exe" (
    echo [launch] build\TimeArc.exe not found. Run .\run first to build.
    exit /b 1
)

echo [launch] Launching TimeArc %*...
REM First quoted token is the window TITLE (so start does not treat the exe path as a title).
start "TimeArc" "%ROOT%\build\TimeArc.exe" %*
echo [launch] Done.
endlocal
