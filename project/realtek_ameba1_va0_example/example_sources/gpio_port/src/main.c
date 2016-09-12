/*
 *  Routines to access hardware
 *
 *  Copyright (c) 2013 Realtek Semiconductor Corp.
 *
 *  This module is a confidential and proprietary property of RealTek and
 *  possession or use of this module requires written permission of RealTek.
 */

#include "device.h"
#include "port_api.h"   // mbed
#include "PortNames.h"   // mbed
#include "main.h"

#define PORT_OUTPUT_TEST    1   //1: output test, 0: input test

#define LED_PATTERN_NUM     12

port_t port0;
const uint8_t led_pattern[LED_PATTERN_NUM]={0x81, 0x42, 0x24, 0x18, 0x00, 0x88, 0x44, 0x22, 0x11, 0xff, 0x00};
const uint8_t My_Port_Def[] = {
    PA_6, PA_7, PA_5, PD_4,
    PD_5, PA_4, PA_3, PA_2,

    0xFF    // must end with 0xFF
};


extern void wait_ms(u32);

/**
  * @brief  Main program.
  * @param  None
  * @retval None
  */
#if PORT_OUTPUT_TEST

void main(void)
{
    int i;
    unsigned int pin_mask;

    port_mode(&port0, PullNone);
    // Assign pins to this port 
    port0.pin_def = (uint8_t*)My_Port_Def;
    pin_mask = 0xFF;    // each bit map to 1 pin: 0: pin disable, 1: pin enable
    port_init(&port0, PortA, pin_mask, PIN_OUTPUT);

    while(1){
        for (i=0;i<LED_PATTERN_NUM;i++) {
            port_write(&port0, led_pattern[i]);
            wait_ms(200);
        }
    }
}

#else

void main(void)
{
    int i;
    unsigned int pin_mask;
    int value_new, value_tmp, value_old;
    int stable;

    port_mode(&port0, PullNone);
    // Assign pins to this port 
    port0.pin_def = My_Port_Def;
    pin_mask = 0xFF;    // each bit map to 1 pin: 0: pin disable, 1: pin enable
    port_init(&port0, PortA, pin_mask, PIN_INPUT);

    value_old = port_read(&port0); 
    while(1){
        // De-bonse
        value_new = port_read(&port0); 
        stable = 0;
        while (stable < 3){
            value_tmp = port_read(&port0); 
            if (value_new != value_tmp) {
                value_new = value_tmp;
                stable = 0;
            }
            else {
                stable++;
            }
        } 

        if (value_old != value_new) {
            DBG_8195A("0x%x\r\n", value_new);
            value_old = value_new;
        }
        wait_ms(50);
    }
}

#endif
