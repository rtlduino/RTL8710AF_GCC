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

log_uart_t uobj;

void uart_send_string(log_uart_t *uobj, char *pstr)
{
    unsigned int i=0;

    while (*(pstr+i) != 0) {
        log_uart_putc(uobj, *(pstr+i));
        i++;
    }
}

void main(void)
{
    // sample text
    char rc;
	// Initial Log UART: BaudRate=115200, 8-bits, No Parity, 1 Stop bit
    log_uart_init(&uobj, 38400, 8, ParityNone, 1);

    uart_send_string(&uobj, "UART API Demo...\r\n");
    uart_send_string(&uobj, "Hello World!!\r\n");
    while(1){
        uart_send_string(&uobj, "\r\n8195a$");
        rc = log_uart_getc(&uobj);
        log_uart_putc(&uobj, rc);
    }
}

