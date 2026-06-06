@echo off
REM ============================================================
REM  TimeArc one-shot dev runner   (FORK-LOCAL -- never contributed upstream)
REM  Configures the Qt/MinGW/Ninja toolchain on PATH, configures the build
REM  if needed, closes any running instance, builds incrementally, launches.
REM    run                      (desktop, from cmd)
REM    .\run                    (desktop, from PowerShell)
REM    .\run --mobile-preview   (mobile preview)
REM  Any arguments are forwarded to TimeArc.exe.
REM
REM  Toolchain ROOT resolution (first hit wins):
REM    1. run.local.cmd   (gitignored, per-machine; e.g.  set "QTROOT=C:\Qt")
REM    2. %TIMEARC_QT_ROOT% environment variable
REM    3. the built-in probe list below
REM  Everything else (Qt 6.x, MinGW, Ninja, CMake) is derived from QTROOT,
REM  so a per-machine install only ever needs to set QTROOT -- never edit this file.
REM ============================================================
setlocal

REM Project root = this script's folder, no trailing backslash (path may contain spaces).
set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"

REM --- Resolve QTROOT: (1) per-machine override, (2) env var, (3) probe ---
set "QTROOT="
if exist "%ROOT%\run.local.cmd" call "%ROOT%\run.local.cmd"
if not defined QTROOT if defined TIMEARC_QT_ROOT set "QTROOT=%TIMEARC_QT_ROOT%"
if not defined QTROOT (
    for %%R in ("C:\Qt" "D:\TimeArc\QT" "D:\Qt" "E:\Qt" "C:\TimeArc\QT") do (
        if not defined QTROOT if exist "%%~R\Tools\mingw1310_64\bin\g++.exe" set "QTROOT=%%~R"
    )
)
if not defined QTROOT (
    echo [run] No Qt toolchain found. Set env TIMEARC_QT_ROOT, or create run.local.cmd
    echo [run] next to this script containing:  set "QTROOT=C:\Qt"   -- fork-local, do not contribute.
    exit /b 1
)

REM --- Derive Qt 6.x mingw_64 + companion tools from QTROOT ---
set "QT="
for /d %%V in ("%QTROOT%\6.*") do if exist "%%~V\mingw_64\bin\qmake.exe" set "QT=%%~V\mingw_64"
if not defined QT (
    echo [run] No Qt 6.x mingw_64 build found under "%QTROOT%".
    exit /b 1
)
set "MINGW=%QTROOT%\Tools\mingw1310_64\bin"
set "NINJA=%QTROOT%\Tools\Ninja"
set "CMAKE=%QTROOT%\Tools\CMake_64\bin"

set "PATH=%QT%\bin;%MINGW%;%PATH%"
if exist "%NINJA%\ninja.exe" set "PATH=%NINJA%;%PATH%"
if exist "%CMAKE%\cmake.exe" set "PATH=%CMAKE%;%PATH%"

REM Prefer the Qt-bundled CMake; fall back to whatever cmake is already on PATH.
set "CMAKE_EXE=cmake"
if exist "%CMAKE%\cmake.exe" set "CMAKE_EXE=%CMAKE%\cmake.exe"

echo [run] Toolchain: "%QT%"

REM --- Configure once (creates build\build.ninja) ---
if not exist "%ROOT%\build\build.ninja" (
    echo [run] First-time configure...
    "%CMAKE_EXE%" -S "%ROOT%" -B "%ROOT%\build" -G Ninja ^
        -DCMAKE_BUILD_TYPE=Release ^
        -DCMAKE_PREFIX_PATH="%QT%" ^
        -DCMAKE_C_COMPILER="%MINGW%\gcc.exe" ^
        -DCMAKE_CXX_COMPILER="%MINGW%\g++.exe"
    if errorlevel 1 ( echo [run] Configure FAILED. & exit /b 1 )
)

REM --- Close any running instance so the linker can overwrite the exes ---
REM (Windows refuses to relink an .exe that is currently running.)
REM taskkill sets errorlevel 128 when nothing is running -- do NOT test errorlevel here.
taskkill /IM TimeArc.exe /F >nul 2>&1
taskkill /IM time-arc-service.exe /F >nul 2>&1

REM --- Build (incremental; no-op when up to date) ---
echo [run] Building...
"%CMAKE_EXE%" --build "%ROOT%\build"
if errorlevel 1 ( echo [run] Build FAILED. & exit /b 1 )

REM --- Launch ---
echo [run] Launching TimeArc...
REM First quoted token is the window TITLE (so start does not treat the exe path as a title).
start "TimeArc" "%ROOT%\build\TimeArc.exe" %*
echo [run] Done. The TimeArc window should be open.
endlocal
