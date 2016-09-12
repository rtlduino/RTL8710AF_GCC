package com.realtek.uartthrough;

import java.io.UnsupportedEncodingException;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReentrantLock;

import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
import android.annotation.SuppressLint;
import android.app.ActionBar.LayoutParams;
import android.app.Activity;
import android.app.AlertDialog;
import android.app.ProgressDialog;
import android.content.DialogInterface;
import android.content.Intent;
import android.util.Log;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.Menu;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.view.View.OnClickListener;
import android.widget.AdapterView;
import android.widget.AdapterView.OnItemClickListener;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.GridView;
import android.widget.ImageButton;
import android.widget.PopupWindow;
import android.widget.SimpleAdapter;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import com.realtek.uartthrough.DeviceManager.DeviceInfo;

public class MainActivity extends Activity {

	//TAG
	private final String TAG			= "<uartthrough>";
	private final String TAG_DISCOVER 	= "Discovery";
	private final String TAG_UI_THREAD 	= "Update Ui thread";
	
	//Number
	public final int DEVICE_MAX_NUM = 32;
    private boolean rcvThreadExit = false;
	
	//UI Layout
	private TextView		text_debug;
	private ImageButton 	btn_scanDevices;
	private ImageButton 	btn_setting;
	private ProgressDialog 	pd;
	private GridView 		gridView;
	
	//UI Variable
    private SimpleAdapter adapter_deviceInfo=null;
    private SimpleAdapter adapter_deviceInfo_setting=null;
	
	//Variable
    public static DeviceInfo [] infoDevices;
	public static Globals_d g_d = Globals_d.getInstance();
	public int 	  deviceNumberNow		= 0;
	
	private Globals_ctrl g_ctrl = Globals_ctrl.getInstance();
	private boolean g_discoverEnable = false;
	private List<HashMap<String, Object>> devInfoList = new ArrayList<HashMap<String, Object>>();
    private NsdCore mNSD;
    private String recvBuf = "";
    
    //Thread
    private UpdateUiThread 	uiThread;
    private recvThread rcvThread=null;
    private final Lock _gmutex_recvBuf = new ReentrantLock(true);
    
    //TcpClient
    private TcpClient dataClient;
    private TcpClient ctrlClient;
	
    //serial port Setting
    byte[] cmdPrefix = new byte[]{0x41, 0x4D, 0x45, 0x42, 0x41, 0x5F, 0x55, 0x41, 0x52, 0x54};
    String setting_rate		= "";
	String setting_data		= "";
	String setting_parity	= "";
	String setting_stopbit	= "";
	String setting_flowc	= "";
    
    String[] Setting_baudrate = {"1200", "9600", "14400"
    		   , "19200", "28800", "38400", "57600"
    		   , "76800", "115200", "128000", "153600"
    		   , "230400", "460800", "500000", "921600"};
    String[] Setting_data = {"7", "8"};
    String[] Setting_parity = {"none", "odd", "even"};//0 , 1 , 2
    String[] Setting_stopbit = {"none", "1 bit"};
    String[] Setting_flowc = {"not support"};
    
	Handler handler_pd = new Handler(){
    	@Override
    	public void handleMessage(Message msg) {
    		
    		switch(msg.what){
    		case 0:{
    				if(pd!=null)
    					pd.dismiss();
	    			break;
    			}
    		default:
    			break;
    		}
    	};
    };
	
	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		requestWindowFeature(Window.FEATURE_NO_TITLE);

	}

	@Override
	protected void onStart()
	{
		super.onStart();
		
        getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN, 
                                WindowManager.LayoutParams.FLAG_FULLSCREEN);
		setContentView(R.layout.activity_main);
		
		initData();
		initComponent();
		initComponentAction();

        if(rcvThread == null){
            rcvThreadExit = false;
            Log.i(TAG,"rcvThread create!!");
            rcvThread = new recvThread();
            rcvThread.start();
        }
	}

	@Override
	protected void onStop() {

        rcvThreadExit = true;
	    super.onStop();

	}
	
	@Override
	protected void onDestroy() {
		super.onDestroy();
	}
	
	private void initData() {
		if(infoDevices==null){
			infoDevices = new DeviceInfo[DEVICE_MAX_NUM];
			for(int i=0;i<DEVICE_MAX_NUM;i++)
	        {        	
				infoDevices[i] = new DeviceInfo();
				infoDevices[i].setaliveFlag(0);
				infoDevices[i].setName("");
				infoDevices[i].setName_small("");
				infoDevices[i].setIP("");
				infoDevices[i].setPort(0);
				infoDevices[i].setmacAdrress("");
				infoDevices[i].setimg(R.drawable.device);
	        }
		}
	}


	private void initComponent() {
		btn_scanDevices = null;
		btn_setting = null;
		pd = null;
		
		text_debug		= (TextView) findViewById(R.id.text_debug);
		btn_scanDevices = (ImageButton) findViewById(R.id.btn_scanDevices);
		btn_setting		= (ImageButton) findViewById(R.id.btn_setting);
		gridView        = (GridView)findViewById(R.id.gridview_list);
		
		if(adapter_deviceInfo==null){
			adapter_deviceInfo = new SimpleAdapter(this, devInfoList,
					R.layout.layout_item, new String[] { "item_image", "item_text" },
					new int[] { R.id.item_image, R.id.item_text });
		}
		if(adapter_deviceInfo_setting==null){
			adapter_deviceInfo_setting = new SimpleAdapter(this, devInfoList,
					R.layout.layout_item_setting, new String[] { "item_image", "item_text", "item_text_info" },
					new int[] { R.id.item_image, R.id.item_text, R.id.item_text_info });
		}
		
		gridViewItemComponent();
		
		for(int i=0;i<DEVICE_MAX_NUM;i++){
			if(infoDevices[i].getaliveFlag()>0){
				reloadDeviceInfo();
				break;
			}
		}
	}

	private void initComponentAction() {
		btn_scanDevices.setOnClickListener(new OnClickListener() {

			@Override
			public void onClick(View arg0) {
				pd = new ProgressDialog(MainActivity.this);
				pd.setTitle("Searching...");
				pd.setMessage("Please wait...");
				pd.setIndeterminate(true);
				pd.setCancelable(false);
				pd.setButton(DialogInterface.BUTTON_NEGATIVE, "Cancel", new DialogInterface.OnClickListener() {

					@Override
					public void onClick(DialogInterface dialog, int which) {
						stopDiscover();
						dialog.dismiss();
					}					
				});
				pd.show();
				
				//Thread
				Thread searchThread  = new Thread() {
					@SuppressLint("NewApi")
					@Override
					public void run() {
						
						
						Log.i(TAG,"startDiscover");
						
						try {
							startDiscover();
							Thread.sleep(3000);
						} catch (InterruptedException e) {
							e.printStackTrace();
						}
						
						Message m = new Message();
						m.what = 0;
						handler_pd.sendMessage(m);
						
						stopDiscover();
						Log.i(TAG,"stopDiscover");
						
						deviceNumberNow = g_d.getDeviceList().size();
						
						for(int i=0;i<deviceNumberNow;i++){
							/*Log.d(TAG_DISCOVER,"Name: " + g_d.getDeviceList().elementAt(i).getServiceName() );
							Log.d(TAG_DISCOVER,"Type: " + g_d.getDeviceList().elementAt(i).getServiceType() );
							Log.d(TAG_DISCOVER,"Host: " + g_d.getDeviceList().elementAt(i).getHost() );
							Log.d(TAG_DISCOVER,"Port: " + g_d.getDeviceList().elementAt(i).getPort() );*/
							
							infoDevices[i].setaliveFlag(1);
							infoDevices[i].setName(g_d.getDeviceList().elementAt(i).getServiceName());
							infoDevices[i].setName_small("");
							infoDevices[i].setIP(g_d.getDeviceList().elementAt(i).getHost().getHostAddress());
							infoDevices[i].setPort(g_d.getDeviceList().elementAt(i).getPort());
							infoDevices[i].setmacAdrress("");
						}
						
						runOnUiThread(new Runnable() {
							@Override
							public void run() {
								
								//show scan result
								text_debug.setText("");
								for(int i=0;i<deviceNumberNow;i++){
									text_debug.append("==== " +i+ " ====\n");
									text_debug.append("name: "+infoDevices[i].getName()+"\n");
									text_debug.append("host: "+infoDevices[i].getIP()+"\n");
									text_debug.append("port: "+infoDevices[i].getPort()+"\n");
								}
								
								Toast.makeText(MainActivity.this,
										String.valueOf(deviceNumberNow) + " Ameba Found",
										Toast.LENGTH_SHORT).show();
								
								reloadDeviceInfo();
							}

						});
						
					}
				};
				searchThread.start();
			}
		});
		
		btn_setting.setOnClickListener(new OnClickListener() {
			
			@Override
			public void onClick(View arg0) {

				AlertDialog.Builder setting_builder;
				
				setting_builder=new AlertDialog.Builder(MainActivity.this);
				//speaker_builder.setIcon(R.drawable.ic_dialog_question);
				setting_builder.setTitle("Choose One Ameba");
				setting_builder.setCancelable(false);
				
				setting_builder.setSingleChoiceItems(adapter_deviceInfo_setting, -1, new DialogInterface.OnClickListener(){

					@SuppressLint("NewApi")
					@Override
					public void onClick(DialogInterface dialog, final int index) {
                        //Log.d("!!!!!!!!!!!!!","popupView !!!!");

						g_ctrl.resetInfo();


						//Log.d(TAG,"setting_builder: "+g_ctrl.getDeviceList().elementAt(index).getServiceName());
						//Log.d(TAG,"setting_builder: "+g_ctrl.getDeviceList().elementAt(index).getHost());
						//Log.d(TAG,"setting_builder: "+g_ctrl.getDeviceList().elementAt(index).getPort());
						
						g_ctrl.setConnIP(g_ctrl.getDeviceList().elementAt(0).getHost());
						g_ctrl.setConnPort(g_ctrl.getDeviceList().elementAt(0).getPort());
						
						ctrlClient =  new TcpClient(g_ctrl);
						ctrlClient.executeOnExecutor(TcpClient.THREAD_POOL_EXECUTOR);
						
						//TODO
		                byte[] cmdGet_AllSetting = new byte[]{0x02, 0x1F};

		                ByteBuffer tmp = ByteBuffer.allocate(cmdPrefix.length + cmdGet_AllSetting.length);

		                tmp.put(cmdPrefix);
		                tmp.put(cmdGet_AllSetting);
		                byte[] test = tmp.array();

		                g_ctrl.setTx(test);
						g_ctrl.setCmd("Request");

						pd = new ProgressDialog(MainActivity.this);
						pd.setTitle("Serial port");
						pd.setMessage("Please wait...");
						pd.setIndeterminate(true);
						pd.setCancelable(false);
						pd.setButton(DialogInterface.BUTTON_NEGATIVE, "Cancel", new DialogInterface.OnClickListener() {

							@Override
							public void onClick(DialogInterface dialog, int which) {
								dialog.dismiss();
							}					
						});
						pd.show();
						
						//Thread
						Thread gettingThread  = new Thread() {
							@Override
							public void run() {

								int retry = 20;
								do{
									try {
										Thread.sleep(500);
									} catch (InterruptedException e) {
										e.printStackTrace();
									}
								}while(retry-->0 && recvBuf.length()==0);
								
								Message m = new Message();
								m.what = 0;
								handler_pd.sendMessage(m);

								//show serial port setting
								runOnUiThread(new Runnable() {
									@Override
									public void run() {

										Toast.makeText(MainActivity.this,
												recvBuf,
												Toast.LENGTH_SHORT).show();

										String[] type = recvBuf.split(";");
										String[] info = {};
										if(type.length!=5)
											return;

										for(int index=0;index<type.length;index++){
											info = type[index].split(",");
											if(index==0 ){//rate
												setting_rate = info[1];
											}else if(index==1){//data
												setting_data = info[1];
											}else if(index==2){//parity
												setting_parity = info[1];
											}else if(index==3){//stopbit
												setting_stopbit = info[1];
											}else if(index==4){//flowcontrol
												setting_flowc = info[1];
											}
										}
										recvBuf = "";

										LayoutInflater layoutInflater = (LayoutInflater) getBaseContext()
												.getSystemService(LAYOUT_INFLATER_SERVICE);
										View popupView = layoutInflater.inflate(R.layout.setting_serialport,null);
										final PopupWindow popupWindow = new PopupWindow(
												popupView,
												LayoutParams.WRAP_CONTENT,
												LayoutParams.WRAP_CONTENT);
										
										Button btnApply = (Button)popupView.findViewById(R.id.btn_setting_apply);
										Button btnCancel = (Button)popupView.findViewById(R.id.btn_setting_cancel);
										
										//====== baud rate =======
										final Spinner spinner_baudrate = (Spinner)popupView.findViewById(R.id.spinner_baudrate);
										ArrayAdapter<String> adapter_baudrate = 
											      new ArrayAdapter<String>(MainActivity.this, 
											        android.R.layout.simple_spinner_item, Setting_baudrate);
										adapter_baudrate.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);											    
										spinner_baudrate.setAdapter(adapter_baudrate);
										int spinnerPosition = adapter_baudrate.getPosition(setting_rate);
										spinner_baudrate.setSelection(spinnerPosition);
										
										//====== data =======
										final Spinner spinner_data = (Spinner)popupView.findViewById(R.id.spinner_data);
										ArrayAdapter<String> adapter_data = 
											      new ArrayAdapter<String>(MainActivity.this, 
											        android.R.layout.simple_spinner_item, Setting_data);
										adapter_data.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);											    
										spinner_data.setAdapter(adapter_data);
										spinnerPosition = adapter_data.getPosition(setting_data);
										spinner_data.setSelection(spinnerPosition);
										
										//====== parity =======
										final Spinner spinner_parity = (Spinner)popupView.findViewById(R.id.spinner_parity);
										ArrayAdapter<String> adapter_parity = 
											      new ArrayAdapter<String>(MainActivity.this, 
											        android.R.layout.simple_spinner_item, Setting_parity);
										adapter_parity.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);											    
										spinner_parity.setAdapter(adapter_parity);
										spinnerPosition = Integer.valueOf(setting_parity).intValue();//adapter_parity.getPosition(parity);
										spinner_parity.setSelection(spinnerPosition);
										
										//====== stop bit =======
										final Spinner spinner_stopbit = (Spinner)popupView.findViewById(R.id.spinner_stopbit);
										ArrayAdapter<String> adapter_stopbit = 
											      new ArrayAdapter<String>(MainActivity.this, 
											        android.R.layout.simple_spinner_item, Setting_stopbit);
										adapter_stopbit.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);											    
										spinner_stopbit.setAdapter(adapter_stopbit);
										spinnerPosition = Integer.valueOf(setting_stopbit).intValue();//adapter_stopbit.getPosition(stopbit);
										spinner_stopbit.setSelection(spinnerPosition);
										
										//====== flow control=======
										final Spinner spinner_flowc = (Spinner)popupView.findViewById(R.id.spinner_flowcontrol);
										ArrayAdapter<String> adapter_flowc = 
											      new ArrayAdapter<String>(MainActivity.this, 
											        android.R.layout.simple_spinner_item, Setting_flowc);
										adapter_flowc.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);											    
											    spinner_flowc.setAdapter(adapter_flowc);
										spinnerPosition = adapter_flowc.getPosition(setting_flowc);
										spinner_flowc.setSelection(spinnerPosition);
						                
										btnApply.setOnClickListener(new Button.OnClickListener() {

											@Override
											public void onClick(View v) {
												//TODO
												setting_rate	= spinner_baudrate.getSelectedItem().toString();
												setting_data 	= spinner_data.getSelectedItem().toString(); 
												setting_parity 	= spinner_parity.getSelectedItem().toString();
												setting_stopbit = spinner_stopbit.getSelectedItem().toString();
												setting_flowc 	= spinner_flowc.getSelectedItem().toString();

								                g_ctrl.setTx(combineReqCmd( setting_rate,
                                                        setting_data,
                                                        setting_parity,
                                                        setting_stopbit,
                                                        setting_flowc));

												g_ctrl.setCmd("Request");
												
										//		Log.d(TAG,"requestCmd: " + requestCmd);
												
												pd = new ProgressDialog(MainActivity.this);
												pd.setTitle("Serial port");
												pd.setMessage("Please wait...");
												pd.setIndeterminate(true);
												pd.setCancelable(false);
												pd.setButton(DialogInterface.BUTTON_NEGATIVE, "Cancel", new DialogInterface.OnClickListener() {

													@Override
													public void onClick(DialogInterface dialog, int which) {
														dialog.dismiss();
													}					
												});
												pd.show();
												
												//Thread
												Thread settingThread  = new Thread() {
													@Override
													public void run() {
														
														int retry = 20;
														do{
															try {
																Thread.sleep(500);
															} catch (InterruptedException e) {
																e.printStackTrace();
															}
														}while(retry-->0 && recvBuf.length()==0);
														
														Message m = new Message();
														m.what = 0;
														handler_pd.sendMessage(m);
                                                        g_ctrl.setCmd("stop");
														//show serial port setting
														runOnUiThread(new Runnable() {
															@Override
															public void run() {
																
																Toast.makeText(MainActivity.this,
																		recvBuf,
																		Toast.LENGTH_SHORT).show();
																recvBuf = "";
															};
														});
												}};
												settingThread.start();
												
												popupWindow.dismiss();
											}

											private byte[] combineReqCmd(String setting_rate, String setting_data, String setting_parity, String setting_stopbit, String setting_flowc) {
												String result = "";
												
												//<20150412> So far, flow control no support.
												byte[] cmdSet_rate 		= null;
												byte[] cmdSet_data 		= null;
												byte[] cmdSet_parity 	= null;
												byte[] cmdSet_stopbit 	= null;
												//byte[] cmdSet_flowc 	= new byte[3];
												
												if(setting_rate.equals("1200")){
													cmdSet_rate = new byte[]{ (byte)0x01,(byte)0x04,(byte)0xB0,(byte)0x04,(byte)0x00,(byte)0x00};
												}else if(setting_rate.equals("9600")){
													cmdSet_rate = new byte[]{ (byte)0x01,(byte)0x04,(byte) 0x80,0x25,(byte)0x00,(byte)0x00};
												}else if(setting_rate.equals("14400")){
													cmdSet_rate = new byte[]{ (byte)0x01,(byte)0x04,(byte)0x40,(byte)0x38,(byte)0x00,(byte)0x00};	
												}else if(setting_rate.equals("19200")){
													cmdSet_rate = new byte[]{ (byte)0x01,(byte)0x04,(byte)0x00,(byte)0x4B,(byte)0x00,(byte)0x00};	
												}else if(setting_rate.equals("28800")){
													cmdSet_rate = new byte[]{ (byte)0x01,(byte)0x04,(byte)0x80,(byte)0x70,(byte)0x00,(byte)0x00};	
												}else if(setting_rate.equals("38400")){
													cmdSet_rate = new byte[]{ (byte)0x01,(byte)0x04,(byte)0x00,(byte)0x96,(byte)0x00,(byte)0x00};
												}else if(setting_rate.equals("57600")){
													cmdSet_rate = new byte[]{ (byte)0x01,(byte)0x04,(byte)0x00,(byte)0xE1,(byte)0x00,(byte)0x00};
												}else if(setting_rate.equals("76800")){
													cmdSet_rate = new byte[]{ (byte)0x01,(byte)0x04,(byte)0x00,(byte)0x2C,(byte)0x01,(byte)0x00};
												}else if(setting_rate.equals("115200")){
													cmdSet_rate = new byte[]{ (byte)0x01,(byte)0x04,(byte)0x00,(byte)0xC2,(byte)0x01,(byte)0x00};
												}else if(setting_rate.equals("128000")){
													cmdSet_rate = new byte[]{ (byte)0x01,(byte)0x04,(byte)0x00,(byte)0xF4,(byte)0x01,(byte)0x00};
												}else if(setting_rate.equals("153600")){
													cmdSet_rate = new byte[]{ (byte)0x01,(byte)0x04,(byte)0x00,(byte)0x58,(byte)0x02,(byte)0x00};
												}else if(setting_rate.equals("230400")){
													cmdSet_rate = new byte[]{ (byte)0x01,(byte)0x04,(byte)0x00,(byte)0x84,(byte)0x03,(byte)0x00};
												}else if(setting_rate.equals("460800")){
													cmdSet_rate = new byte[]{ (byte)0x01,(byte)0x04,(byte)0x00,(byte)0x08,(byte)0x07,(byte)0x00};
												}else if(setting_rate.equals("500000")){
													cmdSet_rate = new byte[]{ (byte)0x01,(byte)0x04,(byte)0x20,(byte)0xA1,(byte)0x07,(byte)0x00};
												}else if(setting_rate.equals("921600")){
													cmdSet_rate = new byte[]{ (byte)0x01,(byte)0x04,(byte)0x00,(byte)0x10,(byte)0x0E,(byte)0x00};
												} 
												
												if(setting_data.equals("8")){
													cmdSet_data = new byte[]{ 0x02,0x01, 0x08};
												}else{
													cmdSet_data = new byte[]{ 0x02,0x01, 0x07};
												}
												
												if(setting_parity.equals("none")){
													cmdSet_parity = new byte[]{ 0x04,0x01, 0x00};
												}else if(setting_parity.equals("odd")){
													cmdSet_parity = new byte[]{ 0x04,0x01, 0x01};
												}else if(setting_parity.equals("even")){
													cmdSet_parity = new byte[]{ 0x04,0x01, 0x02};
												}
												
												if(setting_stopbit.equals("none")){
													cmdSet_stopbit = new byte[]{ 0x08,0x01, 0x00};
												}else if(setting_stopbit.equals("1 bit")){
													cmdSet_stopbit = new byte[]{ 0x08,0x01, 0x01};
												}

												byte[] reqCmdByte = new byte[]{0x00};
												
												//combine req cmd
								                ByteBuffer reqTmp = ByteBuffer.allocate(cmdPrefix.length +
								                									reqCmdByte.length+
								                									cmdSet_rate.length+
								                									cmdSet_data.length+
								                									cmdSet_parity.length+
								                									cmdSet_stopbit.length);



								                reqTmp.put(cmdPrefix);
								                reqTmp.put(reqCmdByte);
								                reqTmp.put(cmdSet_rate);
								                reqTmp.put(cmdSet_data);
								                reqTmp.put(cmdSet_parity);
								                reqTmp.put(cmdSet_stopbit);
								                byte[] test = reqTmp.array();

												return reqTmp.array();
											}

										});
										
										btnCancel.setOnClickListener(new Button.OnClickListener() {

											@Override
											public void onClick(View v) {
                                                g_ctrl.setCmd("stop");
                                                popupWindow.dismiss();
											}
										});
										popupWindow.showAtLocation(popupView, Gravity.CENTER, 0, 0);
									}

								});
							}
						};
						gettingThread.start();
						dialog.cancel();
						
					}
					
				} );
				setting_builder.setPositiveButton("Cancel",new DialogInterface.OnClickListener() {
		            public void onClick(DialogInterface dialog, int whichButton) {
		            	
		            }
		        });
		    	
				setting_builder.create().show();
			}			
		});



		//======================= action ======================
		//search devices when no device
		boolean isSearchTrigger = true;
		for(int i=0;i<DEVICE_MAX_NUM;i++){
			if(infoDevices[i].getaliveFlag()>0){
				isSearchTrigger = false;
				break;
			}
		}
		if(isSearchTrigger){
			btn_scanDevices.performClick();
		}
		
	}

	protected int parseInfo(String recvBuf) {
		//TODO	

		return 1;

		//-------- response for getting --------
		
	}

	

	private void gridViewItemComponent() {
		
		gridView.setOnItemClickListener( new OnItemClickListener(){

			@SuppressLint("NewApi")
			@Override
			public void onItemClick(AdapterView<?> arg0, View v, int position,
					long id) {
				//Log.d(TAG,infoDevices[position].getName());
				Toast.makeText(MainActivity.this,"Connect to "+
						infoDevices[position].getName(),
						Toast.LENGTH_SHORT).show();
				//TODO
				g_d.resetInfo();
				g_d.setConnIP(g_d.getDeviceList().elementAt(0).getHost());
				g_d.setConnPort(g_d.getDeviceList().elementAt(0).getPort());
                g_d.setCmd("Hello");
                
                dataClient =  new TcpClient(g_d);
                dataClient.executeOnExecutor(TcpClient.THREAD_POOL_EXECUTOR);
                g_d.opStates().setOpState(g_d.opStates().stateConnectedServer());
				
                Intent intent_Navigation = new Intent();
    			intent_Navigation.setClass(MainActivity.this, ChatActivity.class);
    			
    			startActivity(intent_Navigation);
    			finish();
			}
		});
	}
	
	private void startDiscover() {
    	
    	Log.d(TAG_DISCOVER, "Start Service Button clicked");
    	g_d.resetInfo();
    	g_d.clearDeviceList();
    	g_ctrl.resetInfo();
    	g_ctrl.clearDeviceList();
    	
    	g_discoverEnable = true;
    	
        if (mNSD==null){
            mNSD = new NsdCore(this);
            mNSD.initializeNsd();
        }
        
        mNSD.discoverServices(g_d.getServiceType());
        mNSD.discoverServices(g_ctrl.getServiceType());

        if(uiThread==null){
            uiThread = new UpdateUiThread();
            uiThread.start();
        }
        
        g_d.opStates().setOpState(g_d.opStates().stateDiscoveringService());
        g_ctrl.opStates().setOpState(g_d.opStates().stateDiscoveringService());
    }

	private void stopDiscover(){
    	
    	g_discoverEnable = false;
    	
    	Log.d(TAG_DISCOVER,"canceling discovering clicked");
    	
        mNSD.stopDiscovery();
        //uiThread.interrupt();
        
        g_d.opStates().setOpState(g_d.opStates().stateAppStart());
        g_ctrl.opStates().setOpState(g_d.opStates().stateAppStart());
    }

    private void reloadDeviceInfo() {
    	devInfoList.clear();
    	
    	for(int i=0;i<infoDevices.length;i++){
    		if(infoDevices[i].getaliveFlag()==1){
    			HashMap<String, Object> reloadItemHashMap = new HashMap<String, Object>();
    			reloadItemHashMap.put("item_image",infoDevices[i].getimg());
				reloadItemHashMap.put("item_text", infoDevices[i].getName());
				reloadItemHashMap.put("item_text_info", infoDevices[i].getIP());
				devInfoList.add(reloadItemHashMap);
    		}
    	}
    	gridView.setAdapter(adapter_deviceInfo);
	}

    public class recvThread extends Thread{


        //======================= Thread ======================


            @Override
            public void run() {
                //Log.d(TAG,"recvThread Run");

                while(!rcvThreadExit){

                    if(g_ctrl.checkRecvBufUpdate() && g_ctrl.pullRecvBuffer().length()>0){

                        _gmutex_recvBuf.lock();
                        //Log.d(TAG,"recvBuf: lock " + recvBuf + " update? " + g_ctrl.checkRecvBufUpdate() + " length: "+g_ctrl.pullRecvBuffer().length());
                        recvBuf = g_ctrl.pullRecvBuffer();
                        g_ctrl.resetRecvBuffer();
                        _gmutex_recvBuf.unlock();

                        if(parseInfo(recvBuf)<0)
                            Log.e(TAG,"parseInfo(recvBuf) Fail!!!!!");
                    }

                    try {
                        //   Log.d(TAG,"recvThread update " + g_ctrl.checkRecvBufUpdate() +" pullRecvBuffer length " + g_ctrl.pullRecvBuffer().length());
                        //Log.d(TAG,"isInterrupted() " + isInterrupted());
                        Thread.sleep(100);
                    } catch (InterruptedException e) {
                        e.printStackTrace();
                    }
                }
                //Log.d(TAG,"recvThread exit");


            }

        //recvThread.start();





    }

    /*
     * Class - UpdateUiThread
     */
    public class UpdateUiThread extends Thread {

        Globals_d g_d = Globals_d.getInstance();

        private static final int DELAY = 200; // ms

        @Override
        public void run() {
            Log.v(TAG_UI_THREAD, "Update Ui thread started");

            while(g_discoverEnable){
                
            	//Log.d(TAG_UI_THREAD,"-----------");
            	//Log.d(TAG_UI_THREAD,g_d.getInfo());
            	
                try {
                    Thread.sleep(DELAY);
                } catch (InterruptedException e) {
                    Log.e(TAG_UI_THREAD,"Update Ui thread err");
                    return;
                }
            }
            Log.v(TAG_UI_THREAD, "Update Ui thread close");
        }

    }
    
	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		// Inflate the menu; this adds items to the action bar if it is present.
		getMenuInflater().inflate(R.menu.main, menu);
		return true;
	}
	
}
