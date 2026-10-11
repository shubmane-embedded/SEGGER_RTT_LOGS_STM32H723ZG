@echo off
REM Open Tera Term on the RTT stream (TCP/IP, non-telnet, localhost:19021).
REM Start start_rtt_openocd.bat (or a CubeIDE OpenOCD debug session) first.
setlocal
set "TT="
if exist "%ProgramFiles%\teraterm5\ttermpro.exe" set "TT=%ProgramFiles%\teraterm5\ttermpro.exe"
if not defined TT if exist "%ProgramFiles(x86)%\teraterm5\ttermpro.exe" set "TT=%ProgramFiles(x86)%\teraterm5\ttermpro.exe"
if not defined TT if exist "%ProgramFiles(x86)%\teraterm\ttermpro.exe" set "TT=%ProgramFiles(x86)%\teraterm\ttermpro.exe"
if not defined TT if exist "%ProgramFiles%\teraterm\ttermpro.exe" set "TT=%ProgramFiles%\teraterm\ttermpro.exe"
if not defined TT (
    echo [ERROR] ttermpro.exe not found. Install Tera Term or edit this file.
    pause
    exit /b 1
)
start "" "%TT%" 127.0.0.1:19021 /nossh /T=0
