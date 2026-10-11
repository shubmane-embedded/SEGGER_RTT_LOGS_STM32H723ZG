# SEGGER RTT logging for STM32H723 (STM32CubeIDE + OpenOCD/ST-LINK)

`printf()` and `LOG_INF/LOG_WRN/LOG_ERR/LOG_DBG` go out over SEGGER RTT channel 0.
OpenOCD reads them through the ST-LINK and serves them on **localhost:19021**, where
PuTTY, Tera Term or the CubeIDE Terminal display them. No UART is used.

```
printf / LOG_xxx -> RTT buffer in DTCM (0x2000xxxx) -> ST-LINK (SWD) -> OpenOCD -> localhost:19021 -> PuTTY / Tera Term / CubeIDE
```

RTT sources: official SEGGER RTT repository (github.com/SEGGERMicro/RTT, commit 4d8feab, June 2026).

## Package contents

| File | Purpose |
|---|---|
| `SeggerRTT/Inc/SEGGER_RTT.h`, `SEGGER_RTT_ConfDefaults.h` | SEGGER originals (unchanged) |
| `SeggerRTT/Src/SEGGER_RTT.c`, `SEGGER_RTT_printf.c` | SEGGER originals (unchanged) |
| `SeggerRTT/Inc/SEGGER_RTT_Conf.h` | Configuration for H723: C version (no ASM), 4 KB buffer, non-blocking, buffers in DTCM |
| `SeggerRTT/Inc/rtt_log.h`, `SeggerRTT/Src/rtt_log.c` | printf retarget (`_write`/`_read`), auto-init before `main()`, LOG macros with level, colour and timestamp, hex dump |
| `tools/openocd/stm32h723_rtt.cfg` | OpenOCD config: ST-LINK + H723 + RTT server on port 19021 (standalone and CubeIDE) |
| `tools/start_rtt_openocd.bat` | Starts OpenOCD and RTT without the debugger |
| `tools/open_putty_rtt.bat`, `tools/open_teraterm_rtt.bat` | Open the terminal on localhost:19021 |
| `apply-fix.ps1` | Installs everything into the CubeIDE project |

## 1. Install into the project

1. **Close STM32CubeIDE.**
2. Extract the ZIP anywhere, open PowerShell in that folder, and run:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\apply-fix.ps1
   ```
   The default project path is `C:\STM32_NEW_WORKSPACE\SEGGER_RTT_DEMO_NEW`. For another project, add `-ProjectDir "<path>"`.
3. The script:
   - backs up `.cproject`, `*.ld` and `main.c` to `_rtt_backup_<date>`
   - copies the files to `SeggerRTT\Inc` and `SeggerRTT\Src`, and moves `SEGGER_RTT_Syscalls_GCC.c`, `SEGGER_RTT_ASM_ARMv7M.S` and duplicate configs to the backup
   - adds a `.rtt_dtcm` NOLOAD section in the 0x20000000 region of both linker scripts
   - adds `SeggerRTT` as a **source folder** and `../SeggerRTT/Inc` as an **include path** (Debug and Release)
   - enables printf float support if the option exists
   - adds a demo to `main.c`, only inside `USER CODE` blocks: an include, a boot banner, and a 1 s heartbeat
   - copies the tools to `<project>\RTT_Tools`
4. Open CubeIDE, right-click the project, choose **Refresh**, then **Project → Clean…** and **Build**.
5. In `Debug\SEGGER_RTT_DEMO_NEW.map`, search for `_SEGGER_RTT`. It must be at **0x2000xxxx**.

The script can be run again safely; it skips anything already done. CubeMX regeneration does not touch these changes. They are in `USER CODE` blocks, a separate folder and the linker script, which CubeMX does not overwrite once it exists.

## 2a. View the logs while debugging in CubeIDE

1. **Run → Debug Configurations… → STM32 C/C++ Application → SEGGER_RTT_DEMO_NEW Debug**
2. **Debugger** tab:
   - Debug probe: **ST-LINK (OpenOCD)**
   - Configuration Script: **User Defined** → *Browse* → `RTT_Tools\openocd\stm32h723_rtt.cfg`
3. **Startup** tab: leave **Set breakpoint at: main** ticked.
4. Click **Debug**. When it stops at `main`, the OpenOCD console shows
   `RTT: started - connect your terminal to localhost:19021`.
5. Open a terminal (section 3) and press **Resume (F8)**.

`rtt_log.c` initialises RTT in a constructor that runs before `main()`, so the control block already exists at the first halt. RTT then starts automatically.

## 2b. View the logs without the debugger

1. Flash the firmware (CubeIDE **Run**, or STM32CubeProgrammer), then end any debug session. Only one program can use the ST-LINK at a time.
2. Run `RTT_Tools\start_rtt_openocd.bat`, or `start_rtt_openocd.bat reset` to reset the MCU and see the boot messages.
   If `openocd.exe` is not on PATH, set `OPENOCD=` at the top of the .bat file.
3. Leave that window open and open a terminal (section 3).

## 3. Terminal settings

| Terminal | Settings |
|---|---|
| **PuTTY** | Host `127.0.0.1`, Port `19021`, Connection type **Raw**. Terminal → tick *Implicit CR in every LF*. Or run `open_putty_rtt.bat`. |
| **Tera Term** | File → New connection → **TCP/IP**, Host `127.0.0.1`, TCP port `19021`, Service **Other**. Setup → Terminal → New-line Receive **AUTO**. Or run `open_teraterm_rtt.bat`. |
| **CubeIDE** | Window → Show View → Terminal → *Open a Terminal* → **Telnet**, Host `localhost`, Port `19021`. |

Expected output:
```
[     0.012] I: SEGGER RTT demo - STM32H723, SYSCLK = 550 MHz
printf() is redirected to RTT channel 0
[     1.012] I: Heartbeat 0
[     2.012] I: Heartbeat 1
```

## 4. Using it in your code

```c
#include "rtt_log.h"

LOG_ERR("ADC timeout, ch=%d", ch);          // red
LOG_WRN("Temp high: %d C", t);              // yellow
LOG_INF("Init done");                       // green
LOG_DBG("reg=0x%08lX", (unsigned long)r);   // cyan
RTT_Log_HexDump("RX frame", buf, len);
printf("plain text\r\n");

int c = RTT_Log_GetKey();                   // key typed in PuTTY, or -1
```

- **Interrupts:** don't call `printf`/`LOG_xxx` from an ISR. Use `RTT_LOG_ISR("text\r\n");`.
- **Log level:** add `RTT_LOG_LEVEL=LOG_LEVEL_INFO` (or `_WARN`, `_ERROR`, `_NONE`) under *Preprocessor → Define symbols*. Lower levels are compiled out completely.
- **No colours:** add `RTT_LOG_USE_COLOR=0`. **No timestamp:** add `RTT_LOG_USE_TIMESTAMP=0`.
- **Floats** (`%f`): Properties → C/C++ Build → Settings → MCU Settings → tick *Use float with printf from newlib-nano*.
- The firmware **never waits** for the PC. If nobody is reading and the 4 KB buffer is full, new lines are dropped. For lossless bench logging, set `SEGGER_RTT_MODE_DEFAULT` to `SEGGER_RTT_MODE_BLOCK_IF_FIFO_FULL` in `SEGGER_RTT_Conf.h`. Don't do this in production.

## 5. Why the buffers are in DTCM

D-Cache is enabled on the Cortex-M7. If the RTT buffer were in AXI SRAM (0x24000000), the CPU would write into the cache while the probe reads RAM, so the logs would be empty or stale. DTCM (0x20000000) is never cached and the debugger can read it. The OpenOCD config also moves OpenOCD's flash-algorithm work area from DTCM to AXI SRAM, so flashing doesn't overwrite the RTT block.

## 6. Troubleshooting

| Symptom | Fix |
|---|---|
| `RTT: control block NOT found` | Firmware not running, or `_SEGGER_RTT` isn't at 0x2000xxxx in the .map: check the linker script patch. |
| PuTTY "Connection refused" | OpenOCD isn't running: start the debug session or `start_rtt_openocd.bat` first. |
| `Failed to read memory at 0x20000000` / `external reset detected` (standalone) | The MCU is held in reset by "connect under reset". `start_rtt_openocd.bat` sets `RTT_STANDALONE=1` so the cfg switches to `connect_deassert_srst`; when calling OpenOCD by hand, pass `-c "set RTT_STANDALONE 1"` before `-f`. |
| PuTTY connects but shows nothing | The CPU is halted: press Resume. In IDE mode RTT starts at the first halt, so check that the breakpoint at `main` is enabled. |
| `multiple definition of '_write'` | An old retarget (from a UART version) is still in the project; delete it. The script warns about this. |
| `undefined reference to SEGGER_RTT_ASM_WriteSkipNoLock` | An old `SEGGER_RTT_Conf.h` is used instead of this one; only `SeggerRTT/Inc` may contain it. |
| `rtt_log.h: No such file` | Include path missing: Properties → C/C++ General → Paths and Symbols → add `../SeggerRTT/Inc`. |
| Files in SeggerRTT aren't compiled | The folder has no "C" icon: right-click SeggerRTT → Resource Configurations → Exclude from Build → untick, or make it a source folder. |
| OpenOCD can't open the ST-LINK | Close CubeIDE debug and STM32CubeProgrammer; update the ST-LINK firmware (STM32CubeProgrammer → Firmware upgrade). |
| `%f` prints nothing | Enable float printf (section 4). |
| Lines stair-step in PuTTY | Use `\r\n`, or tick *Implicit CR in every LF*. |

**Using a J-Link instead:** these firmware files work unchanged. J-Link opens the same port 19021 by itself (J-Link GDB Server or J-Link Commander with device `STM32H723ZG`). Skip the OpenOCD config.
