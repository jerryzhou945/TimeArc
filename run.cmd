@echo off
REM ============================================================
REM  TimeArc one-shot dev runner
REM  Sets up the Qt/MinGW toolchain on PATH, configures the build
REM  if needed, builds incrementally, then launches the app.
REM  Usage:  run                      (desktop, from cmd)
REM          .\run                    (desktop, from PowerShell)
REM          .\run --mobile-preview   (mobile preview)
REM  Any arguments are forwarded to TimeArc.exe.
REM ============================================================
setlocal

set "QT=D:\TimeArc\QT\6.11.0\mingw_64"
set "MINGW=D:\TimeArc\QT\Tools\mingw1310_64\bin"
set "NINJA=D:\TimeArc\QT\Tools\Ninja"
set "CMAKE=D:\TimeArc\QT\Tools\CMake_64\bin"
set "PATH=%QT%\bin;%MINGW%;%NINJA%;%CMAKE%;%PATH%"

REM Project root = folder this script lives in (no trailing backslash)
set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"

REM --- Configure once (creates build\build.ninja) ---
if not exist "%ROOT%\build\build.ninja" (
    echo [run] First-time configure...
    "%CMAKE%\cmake.exe" -S "%ROOT%" -B "%ROOT%\build" -G Ninja ^
        -DCMAKE_BUILD_TYPE=Release ^
        -DCMAKE_PREFIX_PATH="%QT%" ^
        -DCMAKE_C_COMPILER="%MINGW%\gcc.exe" ^
        -DCMAKE_CXX_COMPILER="%MINGW%\g++.exe"
    if errorlevel 1 (
        echo [run] Configure FAILED.
        exit /b 1
    )
)

REM --- Close any running instance so the linker can overwrite the exes ---
REM (Windows refuses to relink an .exe that is currently running.)
taskkill /IM TimeArc.exe /F >nul 2>&1
taskkill /IM time-arc-service.exe /F >nul 2>&1

REM --- Build (incremental; no-op when up to date) ---
echo [run] Building...
"%CMAKE%\cmake.exe" --build "%ROOT%\build"
if errorlevel 1 (
    echo [run] Build FAILED.
    exit /b 1
)

REM --- Launch ---
echo [run] Launching TimeArc...
start "TimeArc" "%ROOT%\build\TimeArc.exe" %*
echo [run] Done. The TimeArc window should be open.
endlocal
