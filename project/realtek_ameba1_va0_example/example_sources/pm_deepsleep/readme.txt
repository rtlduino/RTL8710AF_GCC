Example Description

This example describes how to use deep sleep api.

Requirement Components:
    a LED
    a push button

Pin name PC_4 and PC_5 map to GPIOC_4 and GPIOC_5:
 - PC_4 as input with internal pull-high, connect a push button to this pin and ground.
 - PC_5 as output, connect a LED to this pin and ground.

In this example, LED is turned on after device initialize.
User push the button to turn off LED and trigger device enter deep sleep mode for 10s.
If user press any key before sleep timeout, the system will resume.
LED is turned on again after device initialize.

It can be easily measure power consumption in normal mode and deep sleep mode before/after push the putton.

NOTE: You will see device resume immediately at first time.
It's because the log uart is a wakeup source and it buffered a wakeup event when DAP is used.
The symptom won't appear if you use power source on R43 and only power on module.