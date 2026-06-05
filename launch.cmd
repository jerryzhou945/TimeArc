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

REM --- Locate the Qt/MinGW/Ninja toolchain (drive-independent) ---
REM Probe known toolchain roots in order; the first that exists wins.
REM Add your own root to this list if you install Qt elsewhere.
set "QTROOT="
for %%R in ("C:\Qt" "D:\TimeArc\QT") do (
    if not defined QTROOT if exist "%%~R\Tools\mingw1310_64\bin\g++.exe" set "QTROOT=%%~R"
)
if not defined QTROOT (
    echo [launch] No Qt toolchain found. Add your toolchain root to the candidate list in launch.cmd.
    exit /b 1
)
set "QT="
for /d %%V in ("%QTROOT%\6.*") do if exist "%%~V\mingw_64\bin\qmake.exe" set "QT=%%~V\mingw_64"
if not defined QT (
    echo [launch] No Qt mingw_64 build found under "%QTROOT%".
    exit /b 1
)
set "MINGW=%QTROOT%\Tools\mingw1310_64\bin"
set "NINJA=%QTROOT%\Tools\Ninja"
set "CMAKE=%QTROOT%\Tools\CMake_64\bin"
if exist "%CMAKE%\cmake.exe" (set "PATH=%QT%\bin;%MINGW%;%NINJA%;%CMAKE%;%PATH%") else (set "PATH=%QT%\bin;%MINGW%;%NINJA%;%PATH%")

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
