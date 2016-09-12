package com.realtek.uartthrough;

public class UARTCmd {
	
	//cmd_c : AMEBA_UART 0x02, 0x01
    //public char cmd_c[] ={0x41, 0x4D, 0x45, 0x42, 0x41, 0x5F, 0x55, 0x41, 0x52, 0x54, 0x02, 0x01};
	public char cmd_c[] ={0x41, 0x4D, 0x45, 0x42, 0x41, 0x5F, 0x55, 0x41, 0x52, 0x54};
	
	public static enum UART_Setting_Type {
		UART_BaudRate,
		UART_Data,
		UART_Parity,
		UART_Stop,
		UART_FlowControl,
		DEFAULT
	};

	public char[] getReqSettingCmd(UART_Setting_Type uartType){
		
		char[] result = cmd_c;
		
		switch(uartType){
		case UART_BaudRate:{
			break;
		}
		}
		return cmd_c;
		
	}
	
}
