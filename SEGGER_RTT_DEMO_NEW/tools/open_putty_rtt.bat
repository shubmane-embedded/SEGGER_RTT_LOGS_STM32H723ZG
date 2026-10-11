@echo off
REM Open PuTTY on the RTT stream (Raw TCP, localhost:19021).
REM Start start_rtt_openocd.bat (or a CubeIDE OpenOCD debug session) first.
setlocal
set "PUTTY="
where putty >nul 2>&1 && set "PUTTY=putty"
if not defined PUTTY if exist "%ProgramFiles%\PuTTY\putty.exe" set "PUTTY=%ProgramFiles%\PuTTY\putty.exe"
if not defined PUTTY if exist "%ProgramFiles(x86)%\PuTTY\putty.exe" set "PUTTY=%ProgramFiles(x86)%\PuTTY\putty.exe"
if not defined PUTTY (
    echo [ERROR] putty.exe not found. Install PuTTY or edit this file.
    pause
    exit /b 1
)
start "" "%PUTTY%" -raw -P 19021 127.0.0.1
