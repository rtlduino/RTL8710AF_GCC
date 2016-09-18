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

#define BUF_SZ (1024*3)

extern void wait_ms(int ms);

char buf[BUF_SZ]="Hello World!!\r\n";;
volatile uint32_t tx_busy=0;
volatile uint32_t rx_busy=0;
log_uart_t uobj;

void uart_tx_done(uint32_t id)
{
    log_uart_t *uobj = (void*)id;
    tx_busy = 0;
}

void uart_rx_done(uint32_t id)
{
    log_uart_t *uobj = (void*)id;
    rx_busy = 0;
}

void main(void)
{
    int ret;
    int i;
    int timeout;

    log_uart_init(&uobj, 38400, 8, ParityNone, 1);

    log_uart_tx_comp_handler(&uobj, (void*)uart_tx_done, (uint32_t) &uobj);
    log_uart_rx_comp_handler(&uobj, (void*)uart_rx_done, (uint32_t) &uobj);

    log_uart_send(&uobj, buf, _strlen(buf), 100);
    
    while (1) {
        rx_busy = 1;
        log_uart_recv_stream(&uobj, buf, BUF_SZ);
        timeout = 2000;
        ret = BUF_SZ;
        while (rx_busy) {
            wait_ms(1);
            timeout--;
            if (timeout == 0) {
                // return value is the bytes received
                ret = log_uart_recv_stream_abort(&uobj);
                rx_busy = 0;
            }
        }
        
        if (ret > 0) {
            buf[ret] = 0;   // end of string
            tx_busy = 1;
            log_uart_send_stream(&uobj, buf, ret);
            timeout = 2000;
            while (tx_busy) {
                wait_ms(1);
                timeout--;
                if (timeout == 0) {
                    tx_busy = 0;
                    // return value is the bytes transmitted
                    ret = log_uart_send_stream_abort(&uobj);
                }
            }
            log_uart_putc(&uobj, 0x0d);
            log_uart_putc(&uobj, 0x0a);
        }
    }
}

