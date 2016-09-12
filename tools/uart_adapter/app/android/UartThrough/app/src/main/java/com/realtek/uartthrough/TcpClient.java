package com.realtek.uartthrough;

import android.os.AsyncTask;
import android.util.Log;

import java.io.BufferedInputStream;
import java.io.IOException;
import java.io.PrintStream;
import java.net.InetAddress;
import java.net.Socket;
import java.nio.ByteBuffer;
import java.nio.CharBuffer;

///////////////////////////////////////////////
public class TcpClient extends AsyncTask<Void, Void, Void> {

	public static final String TAG 		= "TCP_Client";
    public static final String TAG_CTRL = "TCP_Client(CTRL): ";
    public static final String TAG_DATA = "TCP_Client(DATA): ";
    int type;
    Globals_ctrl g_ctrl ;
    Globals_d g_d;
    InetAddress ip;
    int port ;
    String cmd_ctrl_req = "null";
    String cmd_ctrl_response = "null";
    String cmd = "null";


    ByteBuffer bf = ByteBuffer.allocate(1024);
    CharBuffer cbuf = bf.asCharBuffer();


    public TcpClient(Globals_ctrl gInstance) {
        //Log.w("TcpClient Developing","G instructor control port");
        g_ctrl = gInstance;
        ip = g_ctrl.getConnIP();
        port = g_ctrl.getConnPort();
        type = 0;
    }

    public TcpClient(Globals_d gInstance) {
        //Log.w("TcpClient Developing","G_d instructor data port");
        g_d = gInstance;
        ip = g_d.getConnIP();
        port = g_d.getConnPort();
        type = 1;
    }

    @Override
    protected Void doInBackground(Void...params) {
        //g_d.addInfo("TcpClient start");

        try {
            do{
            Thread.sleep(1000);
            final Socket  s = new Socket(ip, port);
            s.setTcpNoDelay(true);

            final BufferedInputStream rx = new BufferedInputStream(s.getInputStream());
            final PrintStream tx = new PrintStream(s.getOutputStream());


            switch (type) {
                case 0: // control port

                	g_ctrl.resetInfo();
                	
                	/*==========================
                                        * thread for control TX
                                        * =========================
                                        */
                	new Thread(new Runnable() {
                        public void run() {
                            do {

                                try {
                                    Thread.sleep(500);
                                } catch (InterruptedException e) {
                                    Log.v(TAG_CTRL,"TX thread error");
                                    break;
                                }

                                cmd_ctrl_req = g_ctrl.getCmd();
                                if(cmd_ctrl_req.equals("Request")) {
                                    try {
                                        tx.write(g_ctrl.getTx());

                                    } catch (IOException e) {
                                        Log.v(TAG_CTRL,"TX write error");
                                        break;
                                    }
                                    tx.flush();
                                    g_ctrl.clearTx();
                                    g_ctrl.clearCmd();
                                }
                            }while ( !cmd_ctrl_req.equals("stop") );
                             tx.close();

                        }
                    }).start();

                	/*==========================
                                         * for control RX
                                         * =========================
                                         */
                	int len;
                	byte [] recv_buf = new byte[64];
                	while (!cmd_ctrl_response.equals("stop")) {
                		cmd_ctrl_response = g_ctrl.getCmd();

                        if( rx.available() > 0 ) {
                        	len = rx.read(recv_buf);
                            g_ctrl.commitRecvBuffer(recv_buf,len);
                        }else{
                            Thread.sleep(200);
                        }
                    }

                    break;
                    
                case 1: //data port
                    g_d.resetInfo();
                    /*==========================
                                         * thread for data TX
                                         * =========================
                                         */
                    new Thread(new Runnable() {
                        public void run() {

                            do {

                                try {
                                    Thread.sleep(500);
                                } catch (InterruptedException e) {
                                    Log.v(TAG_DATA,"TX thread error");
                                    break;
                                }
                                cmd = g_d.getCmd();
                                if(cmd.equals("send")) {
                                    tx.println(g_d.getTx());
                                    g_d.clearTx();
                                    g_d.clearCmd();
                                }

                            }while ( !cmd.equals("stop") );
                            tx.close();

                        }
                    }).start();

                    /*==========================
                                         * for data RX
                                         * =========================
                                         */
                    int b=0;
                    cmd = g_d.getCmd();
                    while (!cmd.equals("stop")) {
                        cmd = g_d.getCmd();
                        
                        if( rx.available() > 0 ) {
                            while(rx.available() > 0) {
                                b = rx.read();
                                cbuf.put((char) b);
                                cbuf.flip();
                                g_d.addInfo(cbuf.toString());
                                if(rx.available() == 0) {
                                    g_d.setReadable(true);
                                }
                            }

                        }else{
                            Thread.sleep(200);
                        }
                    }

                    break;
                default:
                    break;
            }
            if(!s.isClosed()) {
                rx.close();
                s.close();
            }

           }while ( !(!cmd_ctrl_response.equals("stop") || !cmd.equals("stop")) );
            if(type == 0)
                Log.w(TAG, "TCP Control RX Quit");
            else
                Log.w(TAG, "TCP data RX Quit");
        }
        catch (Exception err)
        {
            Log.e(TAG,""+err);
        }

        return null;
    }

/*
    @Override
    protected void onPostExecute(Void result) {

        //do something....

        super.onPostExecute(result);
    }
*/
}