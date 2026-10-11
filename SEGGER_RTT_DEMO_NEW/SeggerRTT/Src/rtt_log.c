/**
 * @file    rtt_log.c
 * @brief   Logging over SEGGER RTT channel 0 + printf retargeting (GCC/newlib).
 *
 * See rtt_log.h for usage.
 */
#include "rtt_log.h"

#include <errno.h>
#include <stdarg.h>
#include <string.h>

/* Longest single LOG_xxx line (prefix + text + colour codes + CRLF).
 * Longer messages are truncated and end with "...". */
#ifndef RTT_LOG_LINE_MAX
#define RTT_LOG_LINE_MAX   256
#endif

/* stdout line buffer (static, so printf never needs malloc for it). */
#ifndef RTT_LOG_STDOUT_BUF
#define RTT_LOG_STDOUT_BUF 256
#endif

static volatile uint8_t s_initDone = 0u;
static char s_stdoutBuf[RTT_LOG_STDOUT_BUF];

/* ------------------------------------------------------------------------ */
/* Initialisation                                                           */
/* ------------------------------------------------------------------------ */

void RTT_Log_Init(void)
{
    if (s_initDone != 0u)
    {
        return;
    }
    s_initDone = 1u;

    SEGGER_RTT_Init();
    SEGGER_RTT_ConfigUpBuffer(RTT_LOG_CHANNEL, NULL, NULL, 0, SEGGER_RTT_MODE_DEFAULT);

    /* Line buffered: printf output is sent at every '\n' (or when 256 bytes
     * are collected). Must be configured before the first output. */
    (void)setvbuf(stdout, s_stdoutBuf, _IOLBF, sizeof(s_stdoutBuf));
    (void)setvbuf(stderr, NULL, _IONBF, 0);
}

/* Runs from __libc_init_array() in the startup code, i.e. after .data/.bss
 * initialisation and BEFORE main(). This guarantees the RTT control block is
 * valid when the debugger halts at main(), so OpenOCD/J-Link can find it. */
__attribute__((constructor))
static void RTT_Log_AutoInit(void)
{
    RTT_Log_Init();
}

/* ------------------------------------------------------------------------ */
/* newlib retargeting (overrides the weak versions in Core/Src/syscalls.c)  */
/* ------------------------------------------------------------------------ */

int _write(int file, char *ptr, int len)
{
    if ((file != 1) && (file != 2))     /* stdout, stderr only */
    {
        errno = EBADF;
        return -1;
    }
    if (len <= 0)
    {
        return 0;
    }

    RTT_Log_Init();
    (void)SEGGER_RTT_Write(RTT_LOG_CHANNEL, ptr, (unsigned)len);

    /* Always report success: in NO_BLOCK_SKIP mode a message that does not
     * fit is dropped, and returning less would make newlib retry forever. */
    return len;
}

/* Blocking read for scanf()/getchar(): waits for keys typed in the terminal. */
int _read(int file, char *ptr, int len)
{
    int n = 0;

    if (file != 0)                      /* stdin only */
    {
        errno = EBADF;
        return -1;
    }

    RTT_Log_Init();
    while (n == 0)
    {
        n = (int)SEGGER_RTT_Read(RTT_LOG_CHANNEL, ptr, (unsigned)len);
    }
    return n;
}

int RTT_Log_GetKey(void)
{
    RTT_Log_Init();
    return SEGGER_RTT_GetKey();
}

/* ------------------------------------------------------------------------ */
/* Time base                                                                */
/* ------------------------------------------------------------------------ */

extern uint32_t HAL_GetTick(void);

__attribute__((weak)) uint32_t RTT_Log_GetTimeMs(void)
{
    return HAL_GetTick();
}

/* ------------------------------------------------------------------------ */
/* Leveled logger                                                           */
/* ------------------------------------------------------------------------ */

#if RTT_LOG_USE_COLOR
#define COL_ERR   RTT_CTRL_TEXT_BRIGHT_RED
#define COL_WRN   RTT_CTRL_TEXT_BRIGHT_YELLOW
#define COL_INF   RTT_CTRL_TEXT_BRIGHT_GREEN
#define COL_DBG   RTT_CTRL_TEXT_BRIGHT_CYAN
#define COL_RST   RTT_CTRL_RESET
#else
#define COL_ERR   ""
#define COL_WRN   ""
#define COL_INF   ""
#define COL_DBG   ""
#define COL_RST   ""
#endif

static const char *const s_levelTag[] = { "", "E", "W", "I", "D" };
static const char *const s_levelCol[] = { "", COL_ERR, COL_WRN, COL_INF, COL_DBG };

void RTT_Log(uint8_t level, const char *fmt, ...)
{
    char    line[RTT_LOG_LINE_MAX];
    int     pos;
    int     n;
    va_list args;

    if ((level == LOG_LEVEL_NONE) || (level > LOG_LEVEL_DEBUG) || (fmt == NULL))
    {
        return;
    }

    RTT_Log_Init();

    /* Keep ordering with plain printf() text that is still in the stdout buffer. */
    (void)fflush(stdout);

#if RTT_LOG_USE_TIMESTAMP
    {
        uint32_t ms = RTT_Log_GetTimeMs();
        pos = snprintf(line, sizeof(line), "%s[%6lu.%03lu] %s: ",
                       s_levelCol[level],
                       (unsigned long)(ms / 1000u), (unsigned long)(ms % 1000u),
                       s_levelTag[level]);
    }
#else
    pos = snprintf(line, sizeof(line), "%s%s: ", s_levelCol[level], s_levelTag[level]);
#endif
    if (pos < 0)
    {
        return;
    }

    /* Reserve room for colour reset + CRLF + terminating NUL. */
    const int tailRoom = (int)sizeof(COL_RST) - 1 + 2 + 1;
    const int textMax  = (int)sizeof(line) - tailRoom;

    va_start(args, fmt);
    n = vsnprintf(&line[pos], (size_t)(textMax - pos), fmt, args);
    va_end(args);

    if (n < 0)
    {
        n = 0;
    }
    if ((pos + n) >= textMax)           /* message truncated */
    {
        pos = textMax - 1;
        line[pos - 3] = '.';
        line[pos - 2] = '.';
        line[pos - 1] = '.';
    }
    else
    {
        pos += n;
    }

    memcpy(&line[pos], COL_RST "\r\n", sizeof(COL_RST "\r\n"));   /* incl. NUL */
    pos += (int)sizeof(COL_RST "\r\n") - 1;

    /* One write per line: in NO_BLOCK_SKIP mode the line appears completely
     * or not at all, never half. */
    (void)SEGGER_RTT_Write(RTT_LOG_CHANNEL, line, (unsigned)pos);
}

void RTT_Log_HexDump(const char *title, const void *data, uint32_t len)
{
    const uint8_t *p = (const uint8_t *)data;
    char  line[16u * 3u + 16u + 16u];
    uint32_t off;

    if (title != NULL)
    {
        LOG_INF("%s (%lu bytes)", title, (unsigned long)len);
    }
    if (p == NULL)
    {
        return;
    }

    for (off = 0u; off < len; off += 16u)
    {
        int pos = snprintf(line, sizeof(line), "%08lX: ", (unsigned long)off);
        uint32_t i;

        for (i = 0u; (i < 16u) && ((off + i) < len); i++)
        {
            pos += snprintf(&line[pos], sizeof(line) - (size_t)pos, "%02X ", p[off + i]);
        }
        (void)snprintf(&line[pos], sizeof(line) - (size_t)pos, "\r\n");
        (void)SEGGER_RTT_WriteString(RTT_LOG_CHANNEL, line);
    }
}
