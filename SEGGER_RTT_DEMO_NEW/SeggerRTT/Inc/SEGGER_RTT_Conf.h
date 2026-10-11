/*********************************************************************
*                   (c) SEGGER Microcontroller GmbH                  *
*                        The Embedded Experts                        *
*                           www.segger.com                           *
**********************************************************************
*                                                                    *
*        SEGGER RTT * Real Time Transfer for embedded targets        *
*                  https://github.com/SEGGERMicro/RTT                *
*                                                                    *
**********************************************************************

---------------------------END-OF-HEADER------------------------------
Purpose : User configuration file for RTT.
          For available configuration,
          refer to SEGGER_RTT_ConfDefaults.h.

          Project configuration: STM32H723ZG (Cortex-M7, D-Cache ON),
          GCC (STM32CubeIDE), viewed through OpenOCD + ST-LINK or J-Link.

----------------------------------------------------------------------
*/

#ifndef SEGGER_RTT_CONF_H
#define SEGGER_RTT_CONF_H


/*********************************************************************
*
*       Defines, configurable
*
**********************************************************************
*/

/*
 * Use the portable C implementation of the write routines.
 * The optional SEGGER_RTT_ASM_ARMv7M.S file is NOT part of this project,
 * so the assembly variant must stay disabled (otherwise: undefined
 * reference to SEGGER_RTT_ASM_WriteSkipNoLock at link time).
 */
#define RTT_USE_ASM                         (0)

/*
 * Number of channels. Channel 0 = terminal (printf / LOG_xxx).
 */
#define SEGGER_RTT_MAX_NUM_UP_BUFFERS       (3)     // Target -> host
#define SEGGER_RTT_MAX_NUM_DOWN_BUFFERS     (3)     // Host   -> target

/*
 * Buffer sizes for channel 0.
 * 4 KB up-buffer holds all boot messages until the host connects.
 */
#define BUFFER_SIZE_UP                      (4096)
#define BUFFER_SIZE_DOWN                    (64)

/*
 * Stack buffer used by SEGGER_RTT_printf() (not by newlib printf).
 */
#define SEGGER_RTT_PRINTF_BUFFER_SIZE       (128)

/*
 * Never block the firmware when no host is connected or the host is slow:
 * a message that does not fit completely in the buffer is dropped.
 * For bench debugging where no message may be lost, use
 * SEGGER_RTT_MODE_BLOCK_IF_FIFO_FULL instead (the CPU then WAITS for the
 * host - never use that in production firmware).
 */
#define SEGGER_RTT_MODE_DEFAULT             SEGGER_RTT_MODE_NO_BLOCK_SKIP

/*
 * Interrupt lock used while writing to the RTT buffer (BASEPRI based).
 * STM32H7 implements 4 priority bits, so 0x10 = NVIC priority 1:
 * interrupts with priority 1..15 are masked during an RTT write,
 * priority 0 stays live. Do not log from priority-0 interrupts.
 */
#define SEGGER_RTT_MAX_INTERRUPT_PRIORITY   (0x10)

/*
 * D-Cache is enabled on the Cortex-M7. The debug probe reads RAM directly
 * and would see stale data if the RTT control block lived in cached AXI
 * SRAM (0x24000000). DTCM (0x20000000) is never cached and is reachable by
 * the debugger, so control block AND buffers are placed there.
 * The linker scripts must contain the matching ".rtt_dtcm" output section
 * (NOLOAD, in the region at 0x20000000) - see README / apply-fix.ps1.
 */
#define SEGGER_RTT_SECTION                  ".rtt_dtcm"
#define SEGGER_RTT_BUFFER_SECTION           ".rtt_dtcm"

#endif
/*************************** End of file ****************************/
