package com.realtek.uartthrough;

import java.text.SimpleDateFormat;
import java.util.Calendar;

import android.os.Bundle;
import android.app.Activity;
import android.content.Intent;
import android.text.Html;
import android.util.Log;
import android.view.Menu;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.view.View.OnClickListener;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ImageButton;
import android.widget.TextView;

public class ChatActivity extends Activity {

	//UI layout
	private ImageButton btn_back;
	private EditText 	editTx_send;
	private Button		btn_send;
	private TextView	text_chatDisplay;
    private boolean rxThreadExit = false;
	
	//Thread
	private Thread 		rxThread	= null;
	
	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		requestWindowFeature(Window.FEATURE_NO_TITLE);
        getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN, 
                                WindowManager.LayoutParams.FLAG_FULLSCREEN);
		setContentView(R.layout.activity_chat);

		initData();
		initComponent();
		initComponentAction();



	}

    @Override
    protected void onStart()
    {
        super.onStart();
        rxThread = new Thread(){
            @Override
            public void run() {

                //while(!isInterrupted()){
                while(!rxThreadExit){
                    try {
                        Thread.sleep(50);
                    } catch (InterruptedException e) {
                        e.printStackTrace();
                    }

                    runOnUiThread(new Runnable() {
                                      @Override
                                      public void run() {
                                          if(MainActivity.g_d.isReadable()) {
                                              updateInfoDisplay(MainActivity.g_d.getInfo());
                                              MainActivity.g_d.resetInfo();
                                              MainActivity.g_d.setReadable(false);
                                          }

                                      }}
                    );
                }
                rxThreadExit = false;
                Log.i("Sean debugging", "Chat rxThread exit");
            }
        };
        rxThread.start();

    }

	@Override
	protected void onStop() {
		super.onStop();
		
		if(rxThread != null){
			//rxThread.interrupt();
            rxThreadExit = true;
			rxThread = null;
		}
	}
	
	private void initData() {
		// TODO Auto-generated method stub
	}

	private void initComponent() {
		btn_back 	= (ImageButton) findViewById(R.id.btn_back);
		editTx_send = (EditText) findViewById(R.id.editTx_send);
		btn_send	= (Button) findViewById(R.id.btn_send);
		text_chatDisplay	= (TextView) findViewById(R.id.chatDisplay);
		
		SimpleDateFormat df = new SimpleDateFormat("yyyy.MM.dd");
		String date = df.format(Calendar.getInstance().getTime());
		text_chatDisplay.append("==========  "+date+"  ==========\n");
		editTx_send.setText("");
	}

	private void initComponentAction() {
		btn_back.setOnClickListener(new OnClickListener() {
			@Override
			public void onClick(View v) {
                MainActivity.g_d.setCmd("stop");
				
				MainActivity.g_d.resetInfo();
				MainActivity.g_d.opStates().setOpState(MainActivity.g_d.opStates().stateAppStart());
				
				Intent intent_Navigation = new Intent();
    			intent_Navigation.setClass(ChatActivity.this, MainActivity.class);
    			
    			startActivity(intent_Navigation);
    			finish();

			}
		});
		
		btn_send.setOnClickListener(new OnClickListener() {
			@Override
			public void onClick(View v) {
				
				if(editTx_send.getText().toString().length()>0){
					String text = editTx_send.getText().toString();
					
					MainActivity.g_d.setTx(text);
					MainActivity.g_d.setCmd("send");
					//text_chatDisplay.setTextColor(Color.parseColor("#e54545"));
					text_chatDisplay.append( Html.fromHtml(getCurrentTimeforHTML()) );
					text_chatDisplay.append( Html.fromHtml( "<font color=\"#47a842\">[Me]" + text + "</font>" ) );
					text_chatDisplay.append("\n");
					editTx_send.setText("");
				}
				
			}
		});

	}

	private void updateInfoDisplay(String recvStr) {

		if(recvStr.length()>0){
            String lines[] = recvStr.split("\\r?\\n");
            for (int i = 0; i < lines.length; i++) {
                SimpleDateFormat df = new SimpleDateFormat("HH:mm:ss");
                String date = df.format(Calendar.getInstance().getTime());


                //text_chatDisplay.setTextColor(Color.parseColor("#8ebbeb"));
                text_chatDisplay.append(Html.fromHtml(getCurrentTimeforHTML()));
                text_chatDisplay.append(Html.fromHtml("<font color=\"#8ebbeb\">[Ameba]" + lines[i] + "</font>"));
                text_chatDisplay.append("\n");
            }
		}

	}
	
	private String getCurrentTimeforHTML() {
		SimpleDateFormat df = new SimpleDateFormat("HH:mm:ss");
		String date = df.format(Calendar.getInstance().getTime());
		String result = "<i><small><font color=\"#c5c5c5\">"+ date + "</font></small></i>";
		return result;
	}

	@Override
	public boolean onCreateOptionsMenu(Menu menu) {
		// Inflate the menu; this adds items to the action bar if it is present.
		getMenuInflater().inflate(R.menu.chat, menu);
		return true;
	}

}
