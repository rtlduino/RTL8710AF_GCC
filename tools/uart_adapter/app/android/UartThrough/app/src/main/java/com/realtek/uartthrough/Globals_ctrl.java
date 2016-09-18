package com.realtek.uartthrough;

import android.net.nsd.NsdServiceInfo;
import android.util.Log;

import java.net.InetAddress;
import java.nio.ByteBuffer;
import java.util.Arrays;
import java.util.Objects;
import java.util.Vector;
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReentrantLock;

public class Globals_ctrl {

    private static Globals_ctrl thisGlobal;

    private static String infoDisplay = "";

    private static final String mServiceName = "AMEBA";
    private static final String TAG 		 = "Globals_ctrl";
    private static final String mServiceType = "_uart_control._tcp";



    private static String successRec = "";

    private static String sensorReadings = "";

    private static Vector<NsdServiceInfo> deviceList = new Vector<NsdServiceInfo>();

    private static InetAddress connIP = null;

    private static int connPort=0;

    private static String cmd="continue";


    private static ByteBuffer tx = ByteBuffer.allocate(32);

    private static byte[] recvBuffer = new byte[64];
    private final Lock _mutex_recvBuf = new ReentrantLock(true);
    
    private static OpStates os = OpStates.getInstance();

    public Globals_ctrl(){}

    public void resetRecvBuffer(){
    	Arrays.fill( recvBuffer, (byte) 0 );
    }
    
    public boolean checkRecvBufUpdate(){
    	if(recvBuffer.length>0)
    		return true;
    	else
    		return false;
    }
    
    public void commitRecvBuffer(byte[] info, int len){
    	
    	_mutex_recvBuf.lock();
    	resetRecvBuffer();
    	System.arraycopy(info, 0, recvBuffer, 0, len);

    	_mutex_recvBuf.unlock();
    }
    
    public String pullRecvBuffer(){
    	
    	if(recvBuffer[0]<=0){
    		return "";
    	}else{
    		_mutex_recvBuf.lock();
    		byte [] res = new byte[recvBuffer.length];
    		System.arraycopy(recvBuffer, 0, res, 0, recvBuffer.length);
    		_mutex_recvBuf.unlock();
    		
    		String controlInfo = parseRecvBuf(res);
    		return controlInfo;
    	}
    }
    
    private String parseRecvBuf(byte[] res) {
		
    	String result = "";
    	
    	//check prefix
    	if(checkPrefix(res)){
    		int readbit = 10;

    		//-------- response for setting --------
    		if( convertirOctetEnEntier(res[readbit])==1 ){
    			result = "ok";
    		//-------- response for getting --------
    		}else if( convertirOctetEnEntier(res[readbit])==3 ){
    			
    			readbit++;
        		
        		int type = -1;
        		String str_len = "";
        		String str_HexValue = "";
        		
        		do{
        			type = convertirOctetEnEntier(res[readbit]);
        			str_HexValue = Integer.toHexString(type);
        			
        			if( type==1 ){//baudrate
        				result += "baudrate,";readbit++;
        				str_len = Integer.toHexString(convertirOctetEnEntier(res[readbit]));
        				int len = Integer.valueOf(str_len).intValue();
        				readbit++;
        				
        				int bit = 0;
        				int v_rate = 0;
        				int tmp = 0;
        				for(int b=readbit;b<readbit+len;b++){
        					tmp = (res[b] & 0xFF) << (8*bit);
        					v_rate = v_rate + tmp ;
        					bit++;
        				}
        				result = result + String.valueOf(v_rate) + ";";readbit+=len;
        			}else if( type==2 ){//data
        				result += "data,";readbit++;
        				str_len = Integer.toHexString(convertirOctetEnEntier(res[readbit])) + ",";
        				readbit++;
        				result = result + Integer.toHexString(convertirOctetEnEntier(res[readbit])) + ";";readbit++;
        			}else if( type==4 ){//parity
        				result += "parity,";readbit++;
        				str_len = Integer.toHexString(convertirOctetEnEntier(res[readbit])) + ",";
        				readbit++;
        				result = result + Integer.toHexString(convertirOctetEnEntier(res[readbit])) + ";";readbit++;
        			}else if( type==8 ){//stopbit
        				result += "stopbit,";readbit++;
        				str_len = Integer.toHexString(convertirOctetEnEntier(res[readbit])) + ",";
        				readbit++;
        				result = result + Integer.toHexString(convertirOctetEnEntier(res[readbit])) + ";";readbit++;
        			}else if( type==16 ){//flowcontrol
        				result += "flowcontrol,";readbit++;
        				str_len = Integer.toHexString(convertirOctetEnEntier(res[readbit])) + ",";
        				readbit++;
        				result = result + Integer.toHexString(convertirOctetEnEntier(res[readbit])) + ";";readbit++;
        			}else
        				readbit++;
        			
        		}while(readbit<recvBuffer.length );
    		}
    		
    	}else{
    		Log.e(TAG,"prefix error!!!");
    	}
    	
		return result;
	}

	private boolean checkPrefix(byte[] recvBuf) {
		
		if("41".equals(String.format("0x%20x", recvBuf[0])) )
			return false;
		if("4D".equals(String.format("0x%20x", recvBuf[1])) )
			return false;
		if("45".equals(String.format("0x%20x", recvBuf[2])))
			return false;
		if("42".equals(String.format("0x%20x", recvBuf[3])))
			return false;
		if("41".equals(String.format("0x%20x", recvBuf[4])))
			return false;
		if("5F".equals(String.format("0x%20x", recvBuf[5])))
			return false;
		if("55".equals(String.format("0x%20x", recvBuf[6])))
			return false;
		if("41".equals(String.format("0x%20x", recvBuf[7])))
			return false;
		if("52".equals(String.format("0x%20x", recvBuf[8])))
			return false;
		if("54".equals(String.format("0x%20x", recvBuf[9])))
			return false;
		
		return true;
	}
    
	public String byte2bits(byte b) {
		int z = b; z |= 256;
		String str = Integer.toBinaryString(z);
		int len = str.length();
		return str.substring(len-8, len);
	}
	
	public int convertirOctetEnEntier(byte b){    
	    int MASK = 0xFF;
	    int result = 0;   
	        result = b & MASK;           
	    return result;
	}
	
	public int byteArrayToInt(byte[] bytes) {
        int value= 0;
        for (int i = 0; i < 4; i++) {
            int shift= (4 - 1 - i) * 8;
            value +=(bytes[i] & 0x000000FF) << shift;
        }
        return value;
	}
	
    public void addInfo(String str){
        infoDisplay+=(str+"\n");
    }

    public String getInfo(){
        return infoDisplay;
    }

    public void resetInfo(){
        infoDisplay="";
    }

    public String getServiceName(){
        return mServiceName;
    }

    public String getServiceType(){
        return mServiceType;
    }

    public String getSuccessRec(){
        return successRec;
    }

    public void setSuccessRec(String str){
        successRec=str;
    }

    public void setConnIP(InetAddress address){
        connIP = address;
    }

    public InetAddress getConnIP(){
        return connIP;
    }

    public void setConnPort(int p){
        connPort=p;
    }

    public int getConnPort(){
        return connPort;
    }

    public void setTx(byte bytes[]){
        tx.put(bytes);
    }



    public byte[] getTx(){
        return tx.array();
    }

    public void clearTx(){ tx.clear();}

    public void clearCmd(){
        cmd="";
    }

    public void setCmd(String str){
        cmd=str;
    }

    public String getCmd(){
        return cmd;
    }

    public void clearDeviceList(){
    	deviceList.clear();
    }
    
    public Vector<NsdServiceInfo> getDeviceList(){
        return deviceList;
    }

    public void addSensorReading(String reading){
        sensorReadings = sensorReadings + reading;
    }

    public OpStates opStates(){
        return os;
    }

    public static synchronized Globals_ctrl getInstance(){
        if(thisGlobal==null){
            thisGlobal = new Globals_ctrl();
        }
        return thisGlobal;
    }
}
