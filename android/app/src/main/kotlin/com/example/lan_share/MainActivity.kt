package com.example.lan_share

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "lan_share/network"
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "acquireMulticastLock" -> {
                        try {
                            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                            if (multicastLock == null) {
                                multicastLock = wifiManager.createMulticastLock("lan_share_multicast_lock").apply {
                                    setReferenceCounted(true)
                                }
                            }
                            multicastLock?.acquire()
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("acquire_failed", e.message, null)
                        }
                    }
                    "releaseMulticastLock" -> {
                        try {
                            multicastLock?.let {
                                if (it.isHeld) {
                                    it.release()
                                }
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("release_failed", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        try {
            multicastLock?.let {
                if (it.isHeld) {
                    it.release()
                }
            }
        } catch (_: Exception) {
        }
        super.onDestroy()
    }
}
