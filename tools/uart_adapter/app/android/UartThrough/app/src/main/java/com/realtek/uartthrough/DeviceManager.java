package com.realtek.uartthrough;

//import java.io.Serializable;

public class DeviceManager {

	public static enum CmdType {
		/*SETUP,
		CH_POS,
		REMOVE,
		TIP_G,
		TIP,
		RENAME,
		TODO_FINISH,*/
		DEFAULT
	};
	
	public static class DeviceInfo //implements Serializable
	{
		private static final long serialVersionUID = 1L;
		private int aliveFlag;
		private String name;
		private String name_small;
		private String IP;
		private int port;
		private String macAdrress;
		private int img;
		
		public int getaliveFlag()
		{
			return this.aliveFlag;
		} 
		public void setaliveFlag(int aliveFlag)
		{
			this.aliveFlag = aliveFlag;
		}
		public String getName()
		{
			return this.name;
		}
		public void setName(String name)
		{
			this.name= name;
		}
		public String getName_small()
		{
			return this.name_small;
		}
		public void setName_small(String name)
		{
			this.name_small= name;
		}
		public String getIP()
		{
			return this.IP;
		}
		public void setIP(String IP)
		{
			this.IP= IP;
		}
		public int getPort()
		{
			return this.port;
		}
		public void setPort(int port)
		{
			this.port= port;
		}
		public String getmacAdrress()
		{
			return this.macAdrress;
		}
		public void setmacAdrress(String macAdrress)
		{
			this.macAdrress= macAdrress;
		}
		public int getimg()
		{
			return this.img;
		}
		public void setimg(int speaker)
		{
			this.img= speaker;
		}
	}
	
}