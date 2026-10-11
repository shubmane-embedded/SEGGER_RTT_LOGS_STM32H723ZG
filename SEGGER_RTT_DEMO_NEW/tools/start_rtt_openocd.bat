@echo off
REM ===========================================================================
REM  Start OpenOCD (ST-LINK) and serve SEGGER RTT channel 0 on localhost:19021
REM
REM    start_rtt_openocd.bat          attach to the running firmware
REM    start_rtt_openocd.bat reset    reset the MCU first (shows boot messages)
REM
REM  Do NOT run this while a CubeIDE debug session is using the ST-LINK.
REM  Keep this window open, then run open_putty_rtt.bat / open_teraterm_rtt.bat
REM ===========================================================================
setlocal

REM ---- Path to openocd.exe -------------------------------------------------
REM  Empty = use the OpenOCD bundled with STM32CubeIDE (C:\ST\STM32CubeIDE_*),
REM  falling back to "openocd" on PATH. The project's "<project> Debug.cfg" is
REM  generated for ST's OpenOCD build, so the bundled one is preferred.
set "OPENOCD="
set "OCD_SCRIPTS="

if not defined OPENOCD (
    for /d %%I in ("C:\ST\STM32CubeIDE_*") do (
        for /d %%P in ("%%I\STM32CubeIDE\plugins\com.st.stm32cube.ide.mcu.externaltools.openocd.win32_*") do (
            if exist "%%P\tools\bin\openocd.exe" set "OPENOCD=%%P\tools\bin\openocd.exe"
        )
        for /d %%P in ("%%I\STM32CubeIDE\plugins\com.st.stm32cube.ide.mcu.debug.openocd_*") do (
            if exist "%%P\resources\openocd\st_scripts" set "OCD_SCRIPTS=%%P\resources\openocd\st_scripts"
        )
    )
)
if not defined OPENOCD set "OPENOCD=openocd"

where "%OPENOCD%" >nul 2>&1
if errorlevel 1 (
    if not exist "%OPENOCD%" (
        echo [ERROR] openocd.exe not found.
        echo         Add its "bin" folder to PATH, or edit OPENOCD= in this file,
        echo         e.g.  set "OPENOCD=C:\xpack-openocd-0.12.0-7\bin\openocd.exe"
        pause
        exit /b 1
    )
)

set "SCRIPTARG="
if defined OCD_SCRIPTS set SCRIPTARG=-s "%OCD_SCRIPTS%"

set "RESETCMD="
if /I "%~1"=="reset" set RESETCMD=-c "reset run"

echo Using: %OPENOCD%
echo Starting OpenOCD... RTT will be on localhost:19021
"%OPENOCD%" %SCRIPTARG% -c "set RTT_STANDALONE 1" -f "%~dp0openocd\stm32h723_rtt.cfg" -c "init" %RESETCMD% -c "rtt_wait_start"

echo.
echo OpenOCD exited.
pause
