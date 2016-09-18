package com.realtek.uartthrough;

import android.annotation.SuppressLint;
import android.content.Context;
import android.net.nsd.NsdManager;
import android.net.nsd.NsdServiceInfo;
import android.util.Log;
import java.lang.*;


public class NsdCore {

	Globals_ctrl g_ctrl = Globals_ctrl.getInstance();
    Globals_d g_d = Globals_d.getInstance();

    Context mContext;

    NsdManager mNsdManager;
    NsdManager.ResolveListener mResolveListener;
    NsdManager.DiscoveryListener mDiscoveryListener;
    NsdManager.RegistrationListener mRegistrationListener;

    public static final String TAG 	= "NsdCore";
    
    public final String mServiceType_c 	= g_ctrl.getServiceType();
    public final String mServiceType_d 	= g_d.getServiceType();

    public String mServiceName_c 	= g_ctrl.getServiceName();
    public String mServiceName_d 	= g_d.getServiceName();

    NsdServiceInfo mService;


    public NsdCore(Context context) {
        mContext = context;
        mNsdManager = (NsdManager) context.getSystemService(Context.NSD_SERVICE);
    }

    public void initializeNsd() {
        Log.i(TAG, " discovery initializeNsd: " + mServiceType_c +" & "+mServiceType_d);
        initializeDiscoveryListener();
        initializeResolveListener();
        initializeRegistrationListener();

    }


    @SuppressLint("NewApi")
	public void initializeDiscoveryListener() {
        mDiscoveryListener = new NsdManager.DiscoveryListener() {

            @Override
            public void onDiscoveryStarted(String regType) {
                Log.i(TAG, "Service discovery started");
                g_ctrl.addInfo(TAG+" "+regType+" g_ctrl Service Discovering\n");
                g_d.addInfo(TAG+" "+regType+" g_d Service Discovering\n");

            }

            @Override
            public void onServiceFound(NsdServiceInfo service) {
                g_ctrl.addInfo(TAG+"Service discovery success\n " + service);
                g_d.addInfo(TAG+"Service Discovery Success\n " + service);
                Log.i(TAG, "Service discovery success " + service);

                if (service.getServiceType().contains(mServiceType_c)) {
                    if (service.getServiceName().contains(mServiceName_c)){
                    	g_ctrl.addInfo(TAG+ "Resolving service... \n");
                        Log.i(TAG, "G_c Resolving service... ");
                        mNsdManager.resolveService(service, mResolveListener);
                    }
                }else{
                	g_ctrl.addInfo(TAG+ "Unknown Service Type: " + service.getServiceType());
                    Log.e(TAG, "G Unknown Service Type: " + service.getServiceType() );
                }

                if (service.getServiceType().contains(mServiceType_d)) {
                    if (service.getServiceName().contains(mServiceName_d)) {
                        g_d.addInfo(TAG + "Resolving service... \n");
                        Log.i(TAG, "G_d Resolving service... ");
                        mNsdManager.resolveService(service, mResolveListener);
                    }
                }else{
                    g_d.addInfo(TAG+ "Unknown Service Type: " + service.getServiceType());
                    Log.e(TAG, "G_d Unknown Service Type: " + service.getServiceType());
                }

            }

            @Override
            public void onServiceLost(NsdServiceInfo service) {
            	g_ctrl.addInfo(TAG+ "service lost\n" + service);
                g_d.addInfo(TAG+ "service lost\n" + service);
                Log.e(TAG, "service lost" + service);
                if (mService == service) {
                    mService = null;
                }
            }

            @Override
            public void onDiscoveryStopped(String serviceType) {
            	g_ctrl.addInfo(TAG+ "Discovery stopped:\n " + serviceType);
                g_d.addInfo(TAG+ "Discovery stopped:\n " + serviceType);
                Log.e(TAG, "Discovery stopped: " + serviceType);
            }

            @Override
            public void onStartDiscoveryFailed(String serviceType, int errorCode) {
            	g_ctrl.addInfo(TAG+"Discovery failed: Error code:\n" + errorCode);
                g_d.addInfo(TAG+"Discovery failed: Error code:\n" + errorCode);
                Log.e(TAG, "onStartDiscoveryFailed: Error code:" + errorCode);
                mNsdManager.stopServiceDiscovery(this);
            }

            @Override
            public void onStopDiscoveryFailed(String serviceType, int errorCode) {
            	g_ctrl.addInfo(TAG+ "Discovery failed: Error code:\n" + errorCode);
                g_d.addInfo(TAG+ "Discovery failed: Error code:\n" + errorCode);
                Log.e(TAG, "onStopDiscoveryFailed: Error code:" + errorCode);
                mNsdManager.stopServiceDiscovery(this);
            }
        };
    }

    @SuppressLint("NewApi")
	public void initializeResolveListener() {
        mResolveListener = new NsdManager.ResolveListener() {

            @SuppressLint("NewApi")
			@Override
            public void onResolveFailed(NsdServiceInfo serviceInfo, int errorCode) {
            	g_ctrl.addInfo(TAG+ "Resolve failed\n" + errorCode);
                g_d.addInfo(TAG+ "Resolve failed\n" + errorCode);
                Log.e(TAG, "Resolve failed: " + errorCode);
                Log.e(TAG, "onResolveFailed"+ " " + serviceInfo.getServiceType());
                switch (errorCode) {
                    case NsdManager.FAILURE_ALREADY_ACTIVE:
                        Log.e(TAG, "FAILURE_ALREADY_ACTIVE");
                        // Just try again...
                        try {
                            Thread.sleep(300);
                        } catch (Exception e) {
                            System.out.println(e);
                        }
                        mNsdManager.resolveService( serviceInfo, mResolveListener);
                        break;
                    case NsdManager.FAILURE_INTERNAL_ERROR:
                        Log.e(TAG, "FAILURE_INTERNAL_ERROR");
                        break;
                    case NsdManager.FAILURE_MAX_LIMIT:
                        Log.e(TAG, "FAILURE_MAX_LIMIT");
                    default:
                    	Log.e(TAG,"XXXXXXX onResolveFailed XXXXXXXX");
                        break;
                }
            }

            @Override
            public void onServiceResolved(NsdServiceInfo serviceInfo) {
                Log.e(TAG, "onServiceResolved"+ " " + serviceInfo.getServiceType());
                mService = serviceInfo;
                if (serviceInfo.getServiceType().contains(mServiceType_c)) {
                    //Log.e(TAG, "G onServiceResolved");
                    g_ctrl.opStates().setOpState(g_ctrl.opStates().stateResoledService());
                    g_ctrl.addInfo(TAG + "Resolve Succeeded.\n " + serviceInfo);
                    g_ctrl.setSuccessRec(TAG + "Resolve Succeeded. " + serviceInfo);
                    g_ctrl.getDeviceList().add(mService);//TODO check ip before add to list
                }else  if (serviceInfo.getServiceType().contains(mServiceType_d)) {
                    //Log.e(TAG, "G_D onServiceResolved");
                    g_d.opStates().setOpState(g_d.opStates().stateResoledService());
                    g_d.addInfo(TAG + "Resolve Succeeded. \n" + serviceInfo);
                    g_d.setSuccessRec(TAG + "Resolve Succeeded. " + serviceInfo);
                    g_d.getDeviceList().add(mService);//TODO check ip before add to list
                }
                Log.w(TAG, "Resolve Succeeded. " + serviceInfo);

            }
        };
    }

	@SuppressLint("NewApi")
	public void initializeRegistrationListener() {
        mRegistrationListener = new NsdManager.RegistrationListener() {

            @SuppressLint("NewApi")
			@Override
            public void onServiceRegistered(NsdServiceInfo NsdServiceInfo) {
            	
            	String serviceName = NsdServiceInfo.getServiceName();
            	
            	Log.e(TAG,"NsdServiceInfo.getServiceName(): " + NsdServiceInfo.getServiceName());
            	
            	mServiceName_c = NsdServiceInfo.getServiceName();
                mServiceName_d = mServiceName_c;
            }

            @Override
            public void onRegistrationFailed(NsdServiceInfo arg0, int arg1) {
                Log.e(TAG, "onRegistrationFailed");
            }

            @Override
            public void onServiceUnregistered(NsdServiceInfo arg0) {
                Log.e(TAG, "onServiceUnregistered");
            }

            @Override
            public void onUnregistrationFailed(NsdServiceInfo serviceInfo, int errorCode) {
            	Log.e(TAG, "onServiceUnregistered: " + serviceInfo.getServiceName() + "/" + errorCode);
            }

        };
    }


    @SuppressLint("NewApi")
	public void discoverServices(String serviceType) {
        Log.d(TAG, "discoverServices " +serviceType+ " start!!");
        //mNsdManager.discoverServices(mServiceType, NsdManager.PROTOCOL_DNS_SD, mDiscoveryListener);
        mNsdManager.discoverServices(serviceType, NsdManager.PROTOCOL_DNS_SD, mDiscoveryListener);

    }

    @SuppressLint("NewApi")
	public void stopDiscovery() {
        mNsdManager.stopServiceDiscovery(mDiscoveryListener);
    }

/*    public NsdServiceInfo getChosenServiceInfo() {
        return mService;
    }*/

/*    public void tearDown() {
        mNsdManager.unregisterService(mRegistrationListener);
    }*/
}

