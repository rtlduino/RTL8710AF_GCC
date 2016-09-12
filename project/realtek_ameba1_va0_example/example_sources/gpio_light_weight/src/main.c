/*
 *  Routines to access hardware
 *
 *  Copyright (c) 2013 Realtek Semiconductor Corp.
 *
 *  This module is a confidential and proprietary property of RealTek and
 *  possession or use of this module requires written permission of RealTek.
 */

#include "device.h"
#include "gpio_api.h"   // mbed
#include "main.h"

#define GPIO_LED_PIN       PC_5
#define GPIO_PUSHBT_PIN    PC_4

/*  You can improve time cost of gpio write by import source code of
 *  function "gpio_direct_write" based on your needs.
 *  In this example, enable CACHE_WRITE_ACTION as demonstration.
 */
#define CACHE_WRITE_ACTION (0)

#if defined(CACHE_WRITE_ACTION) && (CACHE_WRITE_ACTION == 1)
const u8 _GPIO_SWPORT_DR_TBL[] = {
    GPIO_PORTA_DR,
    GPIO_PORTB_DR,
    GPIO_PORTC_DR
};
#endif

void main(void)
{
    gpio_t gpio_led;
    gpio_t gpio_btn;

    // Init LED control pin
    gpio_init(&gpio_led, GPIO_LED_PIN);
    gpio_dir(&gpio_led, PIN_OUTPUT);    // Direction: Output
    gpio_mode(&gpio_led, PullNone);     // No pull

    // Initial Push Button pin
    gpio_init(&gpio_btn, GPIO_PUSHBT_PIN);
    gpio_dir(&gpio_btn, PIN_INPUT);     // Direction: Input
    gpio_mode(&gpio_btn, PullUp);       // Pull-High

#if defined(CACHE_WRITE_ACTION) && (CACHE_WRITE_ACTION == 1)
    u8 port_num = HAL_GPIO_GET_PORT_BY_NAME(gpio_led.hal_pin.pin_name);;
    u8 pin_num  = HAL_GPIO_GET_PIN_BY_NAME(gpio_led.hal_pin.pin_name);;
    u8 dr_tbl   = _GPIO_SWPORT_DR_TBL[port_num];
    u32 RegValue;
#endif

    while(1){
#if defined(CACHE_WRITE_ACTION) && (CACHE_WRITE_ACTION == 1)
        if (gpio_read(&gpio_btn)) {
            // turn off LED
            RegValue =  HAL_READ32(GPIO_REG_BASE, dr_tbl);
            RegValue &= ~(1 << pin_num);
            HAL_WRITE32(GPIO_REG_BASE, dr_tbl, RegValue);
        } else {
            // turn on LED
            RegValue =  HAL_READ32(GPIO_REG_BASE, dr_tbl);
            RegValue |= (1<< pin_num);
            HAL_WRITE32(GPIO_REG_BASE, dr_tbl, RegValue);
        }
#else
        if (gpio_read(&gpio_btn)) {
            // turn off LED
            gpio_direct_write(&gpio_led, 0);
        } else {
            // turn on LED
            gpio_direct_write(&gpio_led, 1);
        }
#endif
    }
}

