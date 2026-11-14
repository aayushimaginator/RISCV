#include "coremark.h"
#include "core_portme.h"
#include <stdarg.h>

void uart_send_char(char c);

static void out_char(char c)
{
    uart_send_char(c);
}

static void out_str(const char *s)
{
    while (*s != 0) {
        out_char(*s);
        s = s + 1;
    }
}

static void out_num(unsigned long v, int base, int width, int pad_zero, int is_signed)
{
    char buf[12];
    int i = 0;
    int neg = 0;
    unsigned long uv;
    const char *digs = "0123456789abcdef";

    if (is_signed != 0) {
        long sv = (long)v;
        if (sv < 0) {
            neg = 1;
            uv = (unsigned long)(-sv);
        }
        else {
            uv = (unsigned long)sv;
        }
    }
    else {
        uv = v;
    }

    if (uv == 0) {
        buf[i] = '0';
        i = i + 1;
    }
    else {
        while (uv > 0) {
            buf[i] = digs[uv % (unsigned long)base];
            i = i + 1;
            uv = uv / (unsigned long)base;
        }
    }

    if (neg != 0) {
        buf[i] = '-';
        i = i + 1;
    }

    while (i < width) {
        buf[i] = (pad_zero != 0) ? '0' : ' ';
        i = i + 1;
    }

    while (i > 0) {
        i = i - 1;
        out_char(buf[i]);
    }
}

int ee_printf(const char *fmt, ...)
{
    va_list ap;
    int pad_zero;
    int width;

    va_start(ap, fmt);

    while (*fmt != 0) {
        if (*fmt != '%') {
            out_char(*fmt);
            fmt = fmt + 1;
            continue;
        }
        fmt = fmt + 1;

        pad_zero = 0;
        if (*fmt == '0') {
            pad_zero = 1;
            fmt = fmt + 1;
        }

        width = 0;
        while (*fmt >= '0' && *fmt <= '9') {
            width = width * 10 + (*fmt - '0');
            fmt = fmt + 1;
        }

        if (*fmt == 'l') {
            fmt = fmt + 1;
        }

        switch (*fmt) {
            case 's': out_str(va_arg(ap, const char *)); break;
            case 'd': out_num((unsigned long)va_arg(ap, int), 10, width, pad_zero, 1); break;
            case 'u': out_num((unsigned long)va_arg(ap, unsigned int), 10, width, pad_zero, 0); break;
            case 'x': out_num((unsigned long)va_arg(ap, unsigned int), 16, width, pad_zero, 0); break;
            case 'c': out_char((char)va_arg(ap, int)); break;
            case '%': out_char('%'); break;
            default:
                out_char('%');
                if (pad_zero != 0) {
                    out_char('0');
                }
                out_char(*fmt);
                break;
        }
        fmt = fmt + 1;
    }

    va_end(ap);
    return 0;
}
