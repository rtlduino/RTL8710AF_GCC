/*
 *  Routines to access hardware
 *
 *  Copyright (c) 2013 Realtek Semiconductor Corp.
 *
 *  This module is a confidential and proprietary property of RealTek and
 *  possession or use of this module requires written permission of RealTek.
 */

#include "device.h"
#include "log_uart_api.h"

char buf[100]="Hello World!!\r\n";;
log_uart_t uobj;

int uart_scan (char *buf)
{
    int i;

    for (i=0;i<100;i++) {
        *(buf+i) = log_uart_getc(&uobj);
        if ((*(buf+i) == 0x0A) || (*(buf+i) == 0x0D)) {
            break;
        }
    }

    return i;
}

void main(void)
{
    int ret;

    log_uart_init(&uobj, 38400, 8, ParityNone, 1);
    log_uart_send(&uobj, buf, _strlen(buf), 100);
    
    while (1) {
//        ret = log_uart_recv(&uobj, buf, 100, 2000);
        ret = uart_scan(buf);
        log_uart_send(&uobj, buf, ret, 1000);
        log_uart_putc(&uobj, 0x0A);
        log_uart_putc(&uobj, 0x0D);
    }
}


