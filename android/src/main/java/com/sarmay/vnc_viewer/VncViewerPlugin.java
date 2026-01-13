package com.sarmay.vnc_viewer;

import android.graphics.SurfaceTexture;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.view.Surface;

import androidx.annotation.NonNull;
import androidx.annotation.RequiresApi;

import org.json.JSONException;
import org.json.JSONObject;

import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.view.TextureRegistry;

/** VncViewerPlugin */
public class VncViewerPlugin implements FlutterPlugin, MethodCallHandler {
    /// The MethodChannel that will the communication between Flutter and native
    /// Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine
    /// and unregister it when the Flutter Engine is detached from the Activity
    private MethodChannel channel;

    private EventChannel eventChannel;

    private Map<Long, EventChannel.EventSink> eventSinkMap = new HashMap<>();

    private final Object removeSinkLock = new Object();

    private Handler handler = new Handler(Looper.getMainLooper());

    private FlutterPluginBinding flutterPluginBinding;

    @RequiresApi(api = Build.VERSION_CODES.FROYO)
    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        this.flutterPluginBinding = flutterPluginBinding;
        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "libvncviewer_flutter");
        channel.setMethodCallHandler(this);
        eventChannel = new EventChannel(flutterPluginBinding.getBinaryMessenger(), "libvncviewer_flutter_eventchannel");
        eventChannel.setStreamHandler(new EventChannel.StreamHandler() {

            @Override
            public void onListen(Object arguments, EventChannel.EventSink events) {
                if (arguments instanceof Map) {
                    @SuppressWarnings("unchecked")
                    Map<String, Object> args = (Map<String, Object>) arguments;
                    Object clientIdObj = args.get("clientId");
                    if (clientIdObj != null) {
                        String clientIdStr = clientIdObj.toString();
                        try {
                            long clientId = Long.parseLong(clientIdStr);
                            eventSinkMap.put(clientId, events);
                            Map<String, Object> respData = new HashMap<>();
                            respData.put("flag", "onReady");
                            events.success(respData);
                        } catch (NumberFormatException e) {
                            events.error("INVALID_CLIENT_ID", "Invalid client ID format: " + clientIdStr, e);
                        }
                    }
                }
            }

            @Override
            public void onCancel(Object arguments) {
                if (arguments instanceof Map) {
                    @SuppressWarnings("unchecked")
                    Map<String, Object> args = (Map<String, Object>) arguments;
                    Object clientIdObj = args.get("clientId");
                    if (clientIdObj != null) {
                        String clientIdStr = clientIdObj.toString();
                        try {
                            long clientId = Long.parseLong(clientIdStr);
                            synchronized (removeSinkLock) {
                                eventSinkMap.remove(clientId);
                            }
                        } catch (NumberFormatException e) {
                            // Handle invalid client ID silently or log if needed
                        }
                    }
                }
            }
        });
    }

    @RequiresApi(api = Build.VERSION_CODES.ICE_CREAM_SANDWICH)
    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        if (call.method.equals("getPlatformVersion")) {
            result.success("Android " + android.os.Build.VERSION.RELEASE);
        } else if (call.method.equals("closeVncClient")) {
            @SuppressWarnings("unchecked")
            Long clientId = (Long) call.argument("clientId");
            if (clientId != null) {
                new VncClient().closeRfbClient(clientId);
            }
        } else if (call.method.equals("startVncClient")) {
            @SuppressWarnings("unchecked")
            Long clientId = (Long) call.argument("clientId");
            if (clientId != null) {
                new VncClient().startRfbClient(clientId);
            }
        } else if (call.method.equals("sendPointer")) {
            @SuppressWarnings("unchecked")
            Long clientId = (Long) call.argument("clientId");
            @SuppressWarnings("unchecked")
            Integer x = (Integer) call.argument("x");
            @SuppressWarnings("unchecked")
            Integer y = (Integer) call.argument("y");
            @SuppressWarnings("unchecked")
            Integer mask = (Integer) call.argument("mask");
            if (clientId != null && x != null && y != null && mask != null) {
                new VncClient().sendPointer(clientId, x, y, mask);
            }
        } else if (call.method.equals("sendKey")) {
            @SuppressWarnings("unchecked")
            Long clientId = (Long) call.argument("clientId");
            @SuppressWarnings("unchecked")
            Integer key = (Integer) call.argument("key");
            @SuppressWarnings("unchecked")
            Boolean down = (Boolean) call.argument("down");
            if (clientId != null && key != null && down != null) {
                new VncClient().sendKeyEvent(clientId, key, down);
            }
        } else if (call.method.equals("initVncClient")) {
            TextureRegistry.SurfaceTextureEntry surfaceTextureEntry = flutterPluginBinding.getTextureRegistry()
                    .createSurfaceTexture();
            SurfaceTexture surfaceTexture = surfaceTextureEntry.surfaceTexture();
            Surface surface = new Surface(surfaceTexture);
            
            @SuppressWarnings("unchecked")
            String hostName = (String) call.argument("hostName");
            @SuppressWarnings("unchecked")
            Integer port = (Integer) call.argument("port");
            @SuppressWarnings("unchecked")
            String password = (String) call.argument("password");
            
            if (hostName != null && port != null) {
                long clientId = new VncClient().rfbInitClient(hostName, port, password, surface, new RfbClientCallBack() {
                    @Override
                    public void onError(long clientId, int code, String msg) {
                        Map<String, Object> respData = new HashMap<>();
                        respData.put("flag", "onError");
                        respData.put("code", code);
                        respData.put("msg", msg);
                        handler.post(() -> {
                            EventChannel.EventSink sink = eventSinkMap.get(clientId);
                            if (sink != null) {
                                sink.success(respData);
                            }
                        });
                    }

                    @Override
                    public void onClosed(long clientId) {
                        Map<String, Object> respData = new HashMap<>();
                        respData.put("flag", "onClose");
                        handler.post(() -> {
                            EventChannel.EventSink sink = eventSinkMap.get(clientId);
                            if (sink != null) {
                                sink.success(respData);
                                synchronized (removeSinkLock) {
                                    eventSinkMap.remove(clientId);
                                }
                            }
                        });
                        surface.release();
                        surfaceTexture.release();
                        surfaceTextureEntry.release();
                    }

                    @Override
                    public void onConnectSuccess(long clientId, int width, int height) {
                    }

                    @Override
                    public void onFrameUpdate(long clientId, byte[] datas, int width, int height) {
                    }

                    @Override
                    public void imageResize(long clientId, int width, int height) {
                        long textureId = surfaceTextureEntry.id();
                        Map<String, Object> respData = new HashMap<>();
                        respData.put("flag", "imageResize");
                        respData.put("width", width);
                        respData.put("height", height);
                        respData.put("textureId", textureId);
                        handler.post(() -> {
                            EventChannel.EventSink sink = eventSinkMap.get(clientId);
                            if (sink != null) {
                                sink.success(respData);
                            }
                        });
                    }
                });
                result.success(clientId);
            }
        } else {
            result.notImplemented();
        }
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
    }
}
