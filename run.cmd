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

REM --- Locate the Qt/MinGW/Ninja toolchain (drive-independent) ---
REM Probe known toolchain roots in order; the first that exists wins.
REM Add your own root to this list if you install Qt elsewhere.
set "QTROOT="
for %%R in ("C:\Qt" "D:\TimeArc\QT") do (
    if not defined QTROOT if exist "%%~R\Tools\mingw1310_64\bin\g++.exe" set "QTROOT=%%~R"
)
if not defined QTROOT (
    echo [run] No Qt toolchain found. Add your toolchain root to the candidate list in run.cmd.
    exit /b 1
)
set "QT="
for /d %%V in ("%QTROOT%\6.*") do if exist "%%~V\mingw_64\bin\qmake.exe" set "QT=%%~V\mingw_64"
if not defined QT (
    echo [run] No Qt mingw_64 build found under "%QTROOT%".
    exit /b 1
)
set "MINGW=%QTROOT%\Tools\mingw1310_64\bin"
set "NINJA=%QTROOT%\Tools\Ninja"
set "CMAKE=%QTROOT%\Tools\CMake_64\bin"
if exist "%CMAKE%\cmake.exe" (set "PATH=%QT%\bin;%MINGW%;%NINJA%;%CMAKE%;%PATH%") else (set "PATH=%QT%\bin;%MINGW%;%NINJA%;%PATH%")

REM Project root = folder this script lives in (no trailing backslash)
set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"

REM --- Configure once (creates build\build.ninja) ---
if not exist "%ROOT%\build\build.ninja" (
    echo [run] First-time configure...
    cmake -S "%ROOT%" -B "%ROOT%\build" -G Ninja ^
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
cmake --build "%ROOT%\build"
if errorlevel 1 (
    echo [run] Build FAILED.
    exit /b 1
)

REM --- Launch ---
echo [run] Launching TimeArc...
start "TimeArc" "%ROOT%\build\TimeArc.exe" %*
echo [run] Done. The TimeArc window should be open.
endlocal
