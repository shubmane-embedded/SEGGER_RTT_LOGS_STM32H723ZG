/**
 * @file    rtt_log.h
 * @brief   Logging over SEGGER RTT channel 0 (printf + leveled LOG_xxx macros).
 *
 * - printf()/puts()/putchar() are redirected to RTT channel 0 (via _write).
 * - RTT is initialised automatically before main() (GCC constructor), so the
 *   control block already exists when the debugger stops at main().
 * - View the output with PuTTY / Tera Term / CubeIDE Terminal on
 *   localhost:19021 (OpenOCD or J-Link RTT telnet server).
 *
 * Usage:
 *   #include "rtt_log.h"
 *   LOG_INF("Clock = %lu Hz", HAL_RCC_GetSysClockFreq());
 *   LOG_ERR("Init failed, code %d", rc);
 *   printf("plain text\r\n");
 *
 * Do NOT call printf/LOG_xxx from interrupt handlers (newlib printf is not
 * reentrant). In an ISR use RTT_LOG_ISR("text\r\n") instead.
 */
#ifndef RTT_LOG_H
#define RTT_LOG_H

#include <stdio.h>
#include <stdint.h>
#include "SEGGER_RTT.h"

#ifdef __cplusplus
extern "C" {
#endif

/* ------------------------------------------------------------------------ */
/* Configuration (override with -D in Project Properties if needed)         */
/* ------------------------------------------------------------------------ */

#define LOG_LEVEL_NONE   0
#define LOG_LEVEL_ERROR  1
#define LOG_LEVEL_WARN   2
#define LOG_LEVEL_INFO   3
#define LOG_LEVEL_DEBUG  4

/** Compile-time log level: messages above this level are compiled out. */
#ifndef RTT_LOG_LEVEL
#define RTT_LOG_LEVEL    LOG_LEVEL_DEBUG
#endif

/** 1 = ANSI colours (PuTTY, Tera Term and the CubeIDE terminal support them). */
#ifndef RTT_LOG_USE_COLOR
#define RTT_LOG_USE_COLOR 1
#endif

/** 1 = prefix every LOG_xxx line with a [seconds.milliseconds] timestamp. */
#ifndef RTT_LOG_USE_TIMESTAMP
#define RTT_LOG_USE_TIMESTAMP 1
#endif

/** RTT channel used for the terminal. */
#ifndef RTT_LOG_CHANNEL
#define RTT_LOG_CHANNEL  0u
#endif

/* ------------------------------------------------------------------------ */
/* API                                                                      */
/* ------------------------------------------------------------------------ */

/** Initialise RTT + stdout redirection. Safe to call any number of times
 *  (already called automatically before main()). */
void RTT_Log_Init(void);

/** Core leveled logger. Appends "\r\n". Use the LOG_xxx macros instead. */
void RTT_Log(uint8_t level, const char *fmt, ...)
    __attribute__((format(printf, 2, 3)));

/** Print a hex dump of a buffer (16 bytes per line). */
void RTT_Log_HexDump(const char *title, const void *data, uint32_t len);

/** Non-blocking read of one character typed in the terminal.
 *  @return the character (0..255) or -1 if nothing is available. */
int  RTT_Log_GetKey(void);

/** Milliseconds used for the timestamp. Default: HAL_GetTick().
 *  Weak - override if your project has a better time base. */
uint32_t RTT_Log_GetTimeMs(void);

/* ------------------------------------------------------------------------ */
/* Macros                                                                   */
/* ------------------------------------------------------------------------ */

#if RTT_LOG_LEVEL >= LOG_LEVEL_ERROR
#define LOG_ERR(...)   RTT_Log(LOG_LEVEL_ERROR, __VA_ARGS__)
#else
#define LOG_ERR(...)   ((void)0)
#endif

#if RTT_LOG_LEVEL >= LOG_LEVEL_WARN
#define LOG_WRN(...)   RTT_Log(LOG_LEVEL_WARN, __VA_ARGS__)
#else
#define LOG_WRN(...)   ((void)0)
#endif

#if RTT_LOG_LEVEL >= LOG_LEVEL_INFO
#define LOG_INF(...)   RTT_Log(LOG_LEVEL_INFO, __VA_ARGS__)
#else
#define LOG_INF(...)   ((void)0)
#endif

#if RTT_LOG_LEVEL >= LOG_LEVEL_DEBUG
#define LOG_DBG(...)   RTT_Log(LOG_LEVEL_DEBUG, __VA_ARGS__)
#else
#define LOG_DBG(...)   ((void)0)
#endif

/** Interrupt-safe output of a constant string (no formatting, no newlib). */
#define RTT_LOG_ISR(str)  ((void)SEGGER_RTT_WriteString(RTT_LOG_CHANNEL, (str)))

#ifdef __cplusplus
}
#endif

#endif /* RTT_LOG_H */
