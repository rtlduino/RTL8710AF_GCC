package com.realtek.uartthrough;

public class OpStates {
    private static OpStates thisOpS;
    ///////////////////////operation states///////////////////////////////
    private static String currState="";

    private static String appStart ="application start";
    private static String discoveringService="discovering service";
    private static String discoveredService ="discovered service";
    private static String resoledService ="resoled service";
    private static String connectedServer="connected to server";
    private static String stoppedConnection="stopped connection to server";
    private static String appQuit="application quit";

    public String getOpState(){
        return currState;
    }

    public void setOpState(String state){
        currState=state;
    }
    public String stateAppStart(){
        return appStart;
    }

    public String stateDiscoveringService(){
        return discoveringService;
    }

    public String stateDiscoveredService(){
        return discoveredService;
    }
    public String stateResoledService(){
        return resoledService;
    }
    public String stateConnectedServer(){
        return connectedServer;
    }
    public String stateStoppedConnection(){
        return stoppedConnection;
    }
    public String stateAppQuit(){
        return appQuit;
    }


    public boolean onOpState(String state){
        if(currState==state){
            return true;
        }
        else {
            return false;
        }
    }
    ////////////////////////operation states end//////////////////////////////
    public OpStates(){}
    public static synchronized OpStates getInstance(){
        if(thisOpS==null){
            thisOpS=new OpStates();
        }
        return thisOpS;
    }
}
