package com.futuristiclabs.kitchen;

import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.WritableNativeMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;

import org.bouncycastle.jce.provider.BouncyCastleProvider;
import org.bouncycastle.openssl.PEMKeyPair;
import org.bouncycastle.openssl.PEMParser;
import org.bouncycastle.openssl.jcajce.JcaPEMKeyConverter;
import org.bouncycastle.asn1.pkcs.PrivateKeyInfo;

import java.io.BufferedInputStream;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.security.KeyFactory;
import java.security.KeyPair;
import java.security.KeyStore;
import java.security.NoSuchAlgorithmException;
import java.security.PrivateKey;
import java.security.Security;
import java.security.cert.CertificateException;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;
import java.security.spec.InvalidKeySpecException;
import java.security.spec.PKCS8EncodedKeySpec;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.BlockingQueue;

import javax.net.ssl.HostnameVerifier;
import javax.net.ssl.KeyManagerFactory;
import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLSession;
import javax.net.ssl.SSLSocketFactory;
import javax.net.ssl.TrustManager;
import javax.net.ssl.TrustManagerFactory;
import javax.net.ssl.X509TrustManager;

import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;
import okhttp3.WebSocket;
import okhttp3.WebSocketListener;
import okio.ByteString;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

public class WebSocketModule extends ReactContextBaseJavaModule {

    private static final String TAG = WebSocketModule.class.getSimpleName();

    private static Context context;
    private OkHttpClient client;
    private X509TrustManager trustManager;
    private SSLSocketFactory sslSocketFactory;
    private WebSocket ws;
    private WebSocket wsUpdate;
    private DeviceEventManagerModule.RCTDeviceEventEmitter mEmitter = null;
    private boolean clientConnected;
    private boolean updateClientConnected;
    private boolean sentSuccessfully;
    private String recievedMessage;
    private String toUpdateFileName;
    private boolean transferSuccess;
    private String sendingCommand;
    private String otaStatus;
    private BlockingQueue<String> queue;
    private String domain;
    private Integer totalPages;

    WebSocketModule(ReactApplicationContext applicationContext) {
        super(applicationContext);
        context = applicationContext;
        queue = new ArrayBlockingQueue<>(1000);
    }

    public static Context getAppContext() {
        return context;
    }

    @NonNull
    @Override
    public String getName() {
        return "WebSocket";
    }

    private OkHttpClient attachCerts(String domainName) {
        try {
            InputStream caCrtFile = context.getResources().openRawResource(R.raw.oldsemicacrt);
            InputStream crtFile = context.getResources().openRawResource(R.raw.oldsemiclientcrt);
            InputStream keyFile = context.getResources().openRawResource(R.raw.oldsemiclientkey);

            // InputStream caCrtFile = context.getResources().openRawResource(R.raw.cacrt);
            // InputStream crtFile = context.getResources().openRawResource(R.raw.clientcrt);
            // InputStream keyFile = context.getResources().openRawResource(R.raw.clientkey);

            Security.addProvider(new BouncyCastleProvider());

            String password = "";

            // Load CA certificate
            X509Certificate caCert = null;
            BufferedInputStream bis = new BufferedInputStream(caCrtFile);
            CertificateFactory cf = CertificateFactory.getInstance("X.509");
            while (bis.available() > 0) {
                caCert = (X509Certificate) cf.generateCertificate(bis);
            }
            bis.close();

            // Load client certificate
            bis = new BufferedInputStream(crtFile);
            X509Certificate cert = null;
            while (bis.available() > 0) {
                cert = (X509Certificate) cf.generateCertificate(bis);
            }
            bis.close();

            // Load client private certificate
            PEMParser pemParser = new PEMParser(new InputStreamReader(keyFile));
            Object object = pemParser.readObject();
            // Important the next line has made the connection work
            JcaPEMKeyConverter converter = new JcaPEMKeyConverter();
            KeyPair key = converter.getKeyPair((PEMKeyPair) object);
            pemParser.close();

            // PrivateKey privateKey = null;
            // if (object instanceof PKCS8EncodedKeySpec) {
            // privateKey = (PrivateKey) object;
            // } else if (object instanceof PrivateKeyInfo ) {
            // // Handle private key info (alternative format)
            // PKCS8EncodedKeySpec pkcs8Spec = new PKCS8EncodedKeySpec(((PrivateKeyInfo) object).getEncoded());
            // try {
            //     KeyFactory keyFactory = KeyFactory.getInstance("RSA"); // or desired algorithm
            //     privateKey = keyFactory.generatePrivate(pkcs8Spec);
            // } catch (NoSuchAlgorithmException | InvalidKeySpecException e) {
            //     // Handle exceptions (wrong algorithm, invalid key data)
            //     e.printStackTrace();
            // }
            // }
            // pemParser.close();

            KeyStore caKs = KeyStore.getInstance(KeyStore.getDefaultType());
            caKs.load(null, null);
            caKs.setCertificateEntry("ca-certificate", caCert);

            TrustManagerFactory trustManagerFactory = TrustManagerFactory.getInstance(
                    TrustManagerFactory.getDefaultAlgorithm());
            trustManagerFactory.init(caKs);
            TrustManager[] trustManagers = trustManagerFactory.getTrustManagers();

            if (trustManagers.length != 1 || !(trustManagers[0] instanceof X509TrustManager)) {
                throw new IllegalStateException("Unexpected default trust managers:"
                        + Arrays.toString(trustManagers));
            }
            trustManager = (X509TrustManager) trustManagers[0];
            

            KeyStore ks = KeyStore.getInstance(KeyStore.getDefaultType());
            ks.load(null, null);
            ks.setCertificateEntry("client-certificate", cert);
            ks.setKeyEntry("client-key", key.getPrivate(), password.toCharArray(),
                    new java.security.cert.Certificate[]{cert});

            // ks.setKeyEntry("client-key", privateKey, password.toCharArray(), new java.security.cert.Certificate[]{cert});
            KeyManagerFactory kmf = KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm());
            kmf.init(ks, password.toCharArray());

            // HostnameVerifier hostnameVerifier = new HostnameVerifier() {
            //     @Override
            //     public boolean verify(String hostname, SSLSession session) {
            //         return true; // Always return true to bypass hostname verification
            //     }
            // };

            SSLContext sslContext = SSLContext.getInstance("TLS");
            sslContext.init(kmf.getKeyManagers(), trustManagers, null);
            // sslContext.init(kmf.getKeyManagers(), trustAllCerts, new java.security.SecureRandom());
            
            SSLSocketFactory sslSocketFactory = sslContext.getSocketFactory();

            return new OkHttpClient.Builder()
                    .sslSocketFactory(sslSocketFactory, trustManager)
                    .hostnameVerifier(new HostnameVerifier() {
                        @Override
                        public boolean verify(String hostname, SSLSession sslSession) {
                            if(hostname.equals(domainName)) return true;                            
                            return false;
                        }
                    })
                    // .hostnameVerifier(hostnameVerifier)
                    .build();

        } catch (Exception e) {
            Log.e(TAG, "Error attaching certificates", e);
            throw new RuntimeException(e);
        }
    }

    private WebSocket webSocketClient(Request request, OkHttpClient socketClient) {
        return socketClient.newWebSocket(request, new WebSocketListener() {
            @Override
            public void onOpen(@NonNull WebSocket webSocket, @NonNull Response response) {
                clientConnected = true;
                Log.d(TAG, "WebSocket Connected");
                Map<String, Object> params = new HashMap<>();
                params.put("status", "CONNECTED");
                sendEvent("onConnection",params);
            }

            @Override
            public void onClosed(@NonNull WebSocket webSocket, int code, @NonNull String reason) {
                clientConnected = false;
                Log.d(TAG, "WebSocket closed: " + reason);
                Map<String, Object> params = new HashMap<>();
                params.put("status", "CLOSED");
                params.put("message", reason);
                sendEvent("onClosed", params);
            }

            @Override
            public void onFailure(@NonNull WebSocket webSocket, @NonNull Throwable t, @Nullable Response response) {
                clientConnected = false;
                Log.e(TAG, "WebSocket failure", t);
                Map<String, Object> params = new HashMap<>();
                params.put("status", "WEB_SOCKET_ERROR");
                params.put("message", t.getMessage());
                sendEvent("onWebSocketError", params);
            }

            @Override
            public void onMessage(@NonNull WebSocket webSocket, @NonNull String text) {
                Log.d(TAG, "WebSocket message received: " + text);
                Map<String, Object> params = new HashMap<>();
                params.put("status", "MESSAGE_RECEIVED");
                params.put("message", text);
                sendEvent("onMessage", params);

                try {
                    JSONObject obj = new JSONObject(text);
                    String cmd = obj.getString("CMD");
                    String status = obj.getString("STATUS");
                    if (!cmd.equals("IND-DATA")) {
                        queue.put(text);
                    }
                    switch (cmd) {
                        case "OTA-WRITE-PAGE":
                            sentSuccessfully = true;
                            recievedMessage = status;
                            break;
                        case "GET-OTA-STATUS":
                            Log.d(TAG, "OTA status: " + status);
                            if (status.equals("IDLE")) {
                                otaStatus = status;
                            }
                            break;
                        default:
                            break;
                    }
                } catch (JSONException | InterruptedException e) {
                    Log.e(TAG, "Error processing message", e);
                }
            }
        });
    }

    private WebSocket webUpdateClient(Request request, OkHttpClient updateClient) {
        return updateClient.newWebSocket(request, new WebSocketListener() {
            @Override
            public void onOpen(@NonNull WebSocket webSocket, @NonNull Response response) {
                Log.d(TAG, "WebSocket update connection opened");
                Map<String, Object> params = new HashMap<>();
                params.put("status", "CONNECTED");
                sendEvent("onUpdateConnection", params);
                updateClientConnected = true;
                UpdateCtrl update = new UpdateCtrl();
                update.start();
            }

            @Override
            public void onClosed(@NonNull WebSocket webSocket, int code, @NonNull String reason) {
                updateClientConnected = false;
                Map<String, Object> params = new HashMap<>();
                params.put("status", "CLOSED");
                params.put("message", reason);                
                sendEvent("onUpdateClosed", params);
            }

            @Override
            public void onFailure(@NonNull WebSocket webSocket, @NonNull Throwable t, @Nullable Response response) {
                updateClientConnected = false;
                Log.e(TAG, "WebSocket update failure", t);
                Map<String, Object> params = new HashMap<>();
                params.put("status", "UPDATE_SOCKET_ERROR");
                params.put("message", t.getMessage());
                sendEvent("onUpdateWebSocketError", params);
            }

            @Override
            public void onMessage(@NonNull WebSocket webSocket, @NonNull String text) {
                Log.d(TAG, "WebSocket update message received: " + text);
                Map<String, Object> params = new HashMap<>();
                params.put("status", "MESSAGE_RECEIVED");
                params.put("message", text);
                sendEvent("onUpdateMessage", params);

                try {
                    JSONObject obj = new JSONObject(text);
                    String cmd = obj.getString("CMD");
                    String status = obj.getString("STATUS");
                    switch (cmd) {
                        case "OTA-WRITE-PAGE":
                            if (status.equals("OK")) {
                                sentSuccessfully = true;
                                recievedMessage = text;
                            }
                            break;
                        case "GET-OTA-STATUS":
                            if (status.equals("IDLE")) {
                                // Handle IDLE status
                            }
                            break;
                        default:
                            break;
                    }
                } catch (JSONException e) {
                    Log.e(TAG, "Error processing update message", e);
                }
            }
        });
    }

    @ReactMethod
    public void connect(String url, Boolean update) {
        try {
            Log.i(TAG, "Connecting to WebSocket");
            String[] firstSplit = url.split("wss://");
            String[] domainName = firstSplit[1].split("/");
            OkHttpClient socketClient = attachCerts(domainName[0]);
            Request request = new Request.Builder().url(url).build();
            domain = domainName[0];

            if (update) {
                wsUpdate = webUpdateClient(request, socketClient);
            } else {
                ws = webSocketClient(request, socketClient);
            }            
        } catch (Exception e) {            
            Log.e(TAG, "Error connecting to WebSocket", e);
        }
    }

    @ReactMethod
    public void sendMessage(String message) {
        if (ws != null) {
            Log.d(TAG, "Native Message:" + message);
            ws.send(message.toString());
        } else {
            Map<String, Object> params = new HashMap<>();
            params.put("message", "Connect to WebSocket first");
            sendEvent("onWebSocketError", params);
        }
    }

    @ReactMethod
    public void disconnect(Boolean update) {        
        if (ws != null) {
            ws.close(1000, "Connection closed by user");
            ws = null;
            Map<String, Object> params = new HashMap<>();
            params.put("status", "CLOSED");
            params.put("message", "Connection closed by user");
            sendEvent("onClosed", params);
        }
        // Close update Client
        if (wsUpdate != null && update) {
            wsUpdate.close(1000, "Connection closed by user");
            wsUpdate = null;
            Map<String, Object> params = new HashMap<>();
            params.put("status", "CLOSED");
            params.put("message", "Connection closed by user");
            sendEvent("onUpdateClosed", params);
        }
    }

    private void sendUpdateMessage(String message) {
        if (wsUpdate != null) {
            wsUpdate.send(message.toString());
        } else {
            Map<String, Object> params = new HashMap<>();
            params.put("message", "Connect to WebSocket update first");
            sendEvent("onWebSocketError", params);
        }
    }

    @ReactMethod
    public boolean checkFile(String fileName) {
        return context.getFileStreamPath(fileName).exists();
    }

    private JSONObject waitForMessage(String cmd) {
        String message = null;
        JSONObject resultObj = null;

        try {
            JSONObject obj;
            String command;
            String status;
            while (true) {
                String item = queue.take();
                Log.d(TAG, "Queue item: " + item);
                obj = new JSONObject(item);
                command = obj.getString("CMD");
                status = obj.getString("STATUS");

                if (command.equals(cmd)) {
                    message = status;
                    resultObj = obj;
                    break;
                }
            }
        } catch (JSONException | InterruptedException e) {
            Log.e(TAG, "Error waiting for message", e);
        }

        return resultObj;
    }

    @ReactMethod
    public void isClientConnected(Promise promise) {
        promise.resolve(clientConnected);
    }

    @ReactMethod
    public void isUpdateClientConnected(Promise promise) {
        promise.resolve(updateClientConnected);
    }

    private void sendEvent(String eventName, Map<String, Object> params) {

        WritableMap map = Arguments.createMap();
        map.putString("eventName", eventName);
        if (params != null) {
            for (Map.Entry<String, Object> entry : params.entrySet()) {
                String key = entry.getKey();
                Object value = entry.getValue();
                if (value instanceof String) {
                map.putString(key, (String) value);
                } else if (value instanceof Boolean) {
                map.putBoolean(key, (Boolean) value);
                } else if (value instanceof Integer) {
                map.putInt(key, (Integer) value);
                } else if (value instanceof Double) {
                map.putDouble(key, (Double) value);
                } else if (value instanceof Float) {
                map.putDouble(key, (Float) value);
                } else if (value instanceof Map) {
                map.putMap(key, Arguments.makeNativeMap((Map) value));
                } else if (value instanceof List) {
                map.putArray(key, Arguments.makeNativeArray((List) value));
                }
            }
        }

        if (mEmitter == null) {
            mEmitter = getReactApplicationContext().getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class);
        }
        if (mEmitter != null) {
            mEmitter.emit(eventName, map);
        }
    }

    private void sendOTAAbort() {
        try {
            JSONObject json = new JSONObject();
            json.put("CMD", "OTA-ABORT");
            sendMessage(json.toString());
            JSONObject result = waitForMessage("OTA-ABORT");
            Log.d(TAG, "OTA abort result: " + result);
        } catch (JSONException e) {
            Log.e(TAG, "Error sending OTA abort", e);
        }
    }

    @ReactMethod
    public String checkOTAStatus() {
        String message = "hello";
        JSONObject result;
        try {
            JSONObject json = new JSONObject();
            json.put("CMD", "GET-OTA-STATUS");
            sendMessage(json.toString());
            result = waitForMessage("GET-OTA-STATUS");
            message = result.getString("STATUS");
            Log.d(TAG, "OTA status: " + message);
            Map<String, Object> params = new HashMap<>();
            params.put("message", message);
            sendEvent("onOTAStatus", params);
        } catch (JSONException e) {
            Log.e(TAG, "Error checking OTA status", e);
        }
        return message;
    }

    @ReactMethod
    public String readFirmwareVersion() {
        String message = "hello";
        JSONObject result;
        try {
            JSONObject json = new JSONObject();
            json.put("CMD", "GET-RUN-FW-VER");
            sendMessage(json.toString());
            result = waitForMessage("GET-RUN-FW-VER");
            message = result.getString("VERSION");
            Log.d(TAG, "Firmware version: " + message);
            Map<String, Object> params = new HashMap<>();
            params.put("firmwareVersion", message);
            sendEvent("onFirmwareVersion", params);
        } catch (JSONException e) {
            Log.e(TAG, "Error reading firmware version", e);
        }

        return message;
    }

    private void sendOTAStart() {
        try {
            FileInputStream file = context.openFileInput(toUpdateFileName);
            int fileSize = file.available();
            int PAGE_SIZE = 256;
            int sizeInBytes = (fileSize + PAGE_SIZE - 1) / PAGE_SIZE;
            totalPages = sizeInBytes;
            Log.d(TAG, "Total pages: " + sizeInBytes);

            JSONObject cmd = new JSONObject();
            cmd.put("CMD", "OTA-START");
            cmd.put("START-PAGE", 1);
            cmd.put("TOTAL-PAGES", sizeInBytes);
            sendMessage(cmd.toString());
            
            Map<String, Object> cmd1 = new HashMap<>();
            cmd1.put("CMD", "OTA-START");
            cmd1.put("START-PAGE", 1);
            cmd1.put("TOTAL-PAGES", sizeInBytes);
            sendEvent("onMessage", cmd1);

            JSONObject message = waitForMessage("OTA-START");
            Log.d(TAG, "OTA start response: " + message);
            Map<String, Object> params = new HashMap<>();
            params.put("CMD","OTA-START");  
            params.put("TOTAL-PAGES", Integer.toString(sizeInBytes));
            sendEvent("onMessage", params);
            
            file.close();
        } catch (IOException | JSONException e) {
            Log.e(TAG, "Error sending OTA start", e);
        }
    }

    private void connectToWebUpdateSocket() {
        Log.d(TAG, "Connecting to WebSocket update: wss://" + domain + "/update");
        connect("wss://" + domain + "/update", true);
    }

    private void sendOTADone() {
        try {
            JSONObject cmd = new JSONObject();
            cmd.put("CMD", "OTA-DONE");
            sendMessage(cmd.toString());
            JSONObject message = waitForMessage("OTA-DONE");
            Log.d(TAG, "OTA done response: " + message);
        } catch (JSONException e) {
            Log.e(TAG, "Error sending OTA done", e);
        }
    }

    private void sendDevReset() {
        try {
            JSONObject cmd = new JSONObject();
            cmd.put("CMD", "DEV-RESET");
            sendMessage(cmd.toString());
            JSONObject message = waitForMessage("DEV-RESET");
            Log.d(TAG, "Device reset response: " + message);
        } catch (JSONException e) {
            Log.e(TAG, "Error sending device reset", e);
        }
    }

    @ReactMethod
    public void startOTAUpdate(String fileName) {
        Log.d(TAG, "Starting OTA update with file: " + fileName);
        if (fileName == null) {
            Log.e(TAG, "Filename is null");
            Map<String, Object> params = new HashMap<>();
            params.put("message", "Filename is null");
            sendEvent("onError", params);
            return; // Or handle appropriately
        }
        
        toUpdateFileName = fileName;
        
        SemiCtrl s1 = new SemiCtrl();
        s1.start();
    }

    private class SemiCtrl extends Thread {
        @Override
        public void run() {
            Log.d(TAG, "SemiCtrl thread started");
            String result = checkOTAStatus();
            Log.d(TAG, "OTA status: " + result);
            if (result.equals("IN-PROGRESS")) {
                Log.d(TAG, "OTA in progress, aborting");
                sendOTAAbort();
            }
            String version = readFirmwareVersion();
            Log.d(TAG, "Firmware version: " + version);
            sendOTAStart();
            connectToWebUpdateSocket();
        }
    }

    private void transferThread() {
        int PAGE_SIZE = 256;

        if (toUpdateFileName == null) {
            Log.e(TAG, "Filename is null");
            Map<String, Object> params = new HashMap<>();
            params.put("message", "Filename is null");
            sendEvent("onError", params);
            return; // Or handle appropriately
        }

        FileInputStream fis = null;
        try {
            fis = context.openFileInput(toUpdateFileName);

            int pageId = 1;
            byte[] buffer = new byte[PAGE_SIZE];

            while (fis.read(buffer) != -1) {
                byte[] lsb = new byte[4];
                lsb[0] = (byte) (pageId & 0xff);
                lsb[1] = (byte) ((pageId >> 8) & 0xFF);
                lsb[2] = (byte) ((pageId >> 16) & 0xFF);
                lsb[3] = (byte) ((pageId >> 24) & 0xFF);
                byte[] finalBytes = new byte[lsb.length + buffer.length];

                System.arraycopy(lsb, 0, finalBytes, 0, lsb.length);
                System.arraycopy(buffer, 0, finalBytes, lsb.length, buffer.length);

                ByteString st = new ByteString(finalBytes);
                transferSuccess = false;
                while (!transferSuccess) {
                    try {
                        wsUpdate.send(st);
                        JSONObject result = waitForMessage("OTA-WRITE-PAGE");
                        Log.d(TAG, "OTA write page response: " + result);
                        String status = result.getString("STATUS");
                        if (status.equals("OK")) {
                            transferSuccess = true;
                        } else {
                            transferSuccess = false;
                        }
                    } catch (JSONException e) {
                        Log.e(TAG, "Error sending OTA write page", e);
                    }
                }
                pageId++;
            }
            fis.close();
        } catch (IOException | IllegalArgumentException e) {
            Log.e(TAG, "Error reading file for OTA update", e);
        }
    }

    private class UpdateCtrl extends Thread {
        @Override
        public void run() {
            Log.d(TAG, "UpdateCtrl thread started");
            transferThread();
            sendOTADone();
            sendDevReset();
        }
    }
}