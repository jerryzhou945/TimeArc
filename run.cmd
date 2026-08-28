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

set "ENV_ROOT=%TIMEARC_QT_ROOT%"
if not defined ENV_ROOT if exist "D:\TimeArc\QT\6.11.0\mingw_64\bin" set "ENV_ROOT=D:\TimeArc\QT"
if not defined ENV_ROOT if exist "C:\code_env\Qt-6.11.0-MinGW64\6.11.0\mingw_64\bin" set "ENV_ROOT=C:\code_env\Qt-6.11.0-MinGW64"
if not defined ENV_ROOT if exist "C:\Qt\6.11.0\mingw_64\bin" set "ENV_ROOT=C:\Qt"
if not defined ENV_ROOT (
    echo [run] Qt 6.11.0 toolchain not found. Set TIMEARC_QT_ROOT to its root directory.
    exit /b 1
)
set "QT=%ENV_ROOT%\6.11.0\mingw_64"
set "MINGW=%ENV_ROOT%\Tools\mingw1310_64\bin"
set "NINJA=%ENV_ROOT%\Tools\Ninja"
set "CMAKE=%ENV_ROOT%\Tools\CMake_64\bin"
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
