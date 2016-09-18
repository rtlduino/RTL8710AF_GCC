package com.realtek.uartthrough;

import android.net.nsd.NsdServiceInfo;

import java.net.InetAddress;
import java.util.Vector;

public class Globals_d {

    private static Globals_d thisGlobal;

    private static String infoDisplay_d = "";

    private static boolean readable = false;

    private static final String mServiceName = "AMEBA";

    private static final String mServiceType = "_uart_data._tcp";

    private static String successRec = "";

    private static String sensorReadings = "";

    private static Vector<NsdServiceInfo> deviceList = new Vector<NsdServiceInfo>();

    private static InetAddress connIP = null;

    private static int connPort=0;

    private static String cmd="continue";

    private static String tx="";

    private static OpStates os = OpStates.getInstance();

    public Globals_d(){}

    public boolean isReadable(){
        return readable;
    }

    public void setReadable(boolean val){
        readable = val;
    }

    public void addInfo(String str){
        infoDisplay_d+=(str);
    }

    public String getInfo(){
        return infoDisplay_d;
    }

    public void resetInfo(){
        infoDisplay_d="";
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

    public void setTx(String str){
        tx=str;
    }

    public String getTx(){
        return tx;
    }

    public void clearTx(){
        tx="";
    }

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

    public static synchronized Globals_d getInstance(){
        if(thisGlobal==null){
            thisGlobal = new Globals_d();
        }
        return thisGlobal;
    }
}
