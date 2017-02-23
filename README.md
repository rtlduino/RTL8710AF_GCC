# **RTL8710AF_SDK_GCC_VERSION 1.0.0** #

![logo_ex_new.png](docs/img/logo.png "logo")

[![Join the chat at https://gitter.im/iot-tech-now/Lobby?utm_source=share-link&utm_medium=link&utm_campaign=share-link](https://img.shields.io/gitter/room/badges/shields.svg)](https://gitter.im/iot-tech-now/Lobby?utm_source=share-link&utm_medium=link&utm_campaign=share-link)
[![Build Status](https://travis-ci.org/91fiona/gcc_yx.svg?branch=master)](https://travis-ci.org/91fiona/gcc_yx)
[![Documentation Status](https://img.shields.io/badge/docs-latest-yellow.svg?style=flat)](http://rtlduino.iot-tech-now.com/)
> 
> ### A low power consumption, low cost,IOT WIFI solution of the operating system.
>    GCC SDK RTL8710 basic version (including the window platform cygwin installation and Ubuntu platform Linux Installation routines), 
> including cross compilation of the installation, compile, link, run, debug, and so on.
> SDK implementation of the function:
> - WiFi connection settings (including AP mode and STA mode).
> - peripheral resource control (including GPIO, SPI, UART, IIC, etc.).
> - the user uses the sample method
> 
> # Summary
> - 802.11 b/g/n,CMOS MAC,Baseband PHY
> - CPU: Cortex-M3 
> - ROM: 1 MB RAM: 512 KB, FLASH: 1 MB
> - WiFi @ 2.4 GHz，Support WPA/WPA2 Security Mode 
> - Support STA/AP/STA+AP Module
> - SPI,UART,PWM,GPIO 
> - Deep Sleep Current  10 uA，Shutdown Current below 5 uA 
> - Use LWIP network protocol stack
> - Use FreeRTOS operating system
> 
> 
> # Documentation
> - [RTL00 Company web ,The first RTL8710AF WIFI module company](http://www.nb-iot-tech.com)
> - [RTL00, The most complete, most detailed introduce RTL8710 BBS](http://bbs.nb-iot-tech.com)
> - [Realtek AMEBA BBS, all kinds of sample for your reference](http://www.amebaiot.com.cn/en/)

> 
> # Build Options
> | Command       |Usage          | Description  |
> | ------------- |:-------------| :-----|
> |all     | $ make all |Compile project to generate ram_all.bin |
> | clean     | $ make clean      |   Remove compile result (*.bin,*.o,…)|
> | clean_all | $ make clean_all   |   Remove compile result and Toolchains |
> | flash |  $ make flash |  Download  ram_all.bin to flash |
> |setup  | $ make setup GDB_SERVER=server   |  (server=openocd or jlink)	Setup GDB_SERVER |
> | debug |  $ make debug  |  Enter gdb debug |
> | ramdebug | $ make ramdebug   | Write ram_all.bin to RAM then enter gdb debug   |
> 
> 
> # How to buy RTL00 modules
> - [TAOBAO](https://item.taobao.com/item.htm?id=545045896396)
> - [EBAY](http://www.ebay.com/itm/REALTEK-RTL8710-RTL8710AF-WIFI-MODULE-IOT-Low-consumption-High-transmit-powe-/192105487445?hash=item2cba611c55:g:EXsAAOSw32lYo7Rx)
> 