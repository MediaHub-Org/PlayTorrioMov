package com.example.playtorrio

import android.app.UiModeManager
import android.content.Context
import android.content.res.Configuration
import android.net.wifi.WifiManager
import android.os.Build
import android.os.PowerManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// AudioServiceActivity, not FlutterActivity: audio_service needs the launch
// intent routed through it so tapping the playback notification returns to
// the running app instead of starting a second copy of it.
class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "com.example.playtorrio/power"
    private val TV_MODE_CHANNEL = "com.example.playtorrio/tv_mode"
    private var wifiLock: WifiManager.WifiLock? = null
    private var wakeLock: PowerManager.WakeLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TV_MODE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                // The one on-device source of truth for "is this a TV" -- not a
                // width/aspect-ratio guess, which a tablet or a Chromebook in
                // landscape would also match.
                "isTv" -> {
                    val uiModeManager = applicationContext.getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
                    val byMode = uiModeManager?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION
                    // UiModeManager alone is not enough: some TV boxes report
                    // a normal UI mode while still being a leanback device
                    // with no touchscreen. The system feature flags are what
                    // a TV is declared by.
                    val pm = applicationContext.packageManager
                    val byFeature = pm.hasSystemFeature("android.software.leanback") ||
                        pm.hasSystemFeature("android.hardware.type.television")
                    result.success(byMode || byFeature)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "acquireLocks" -> {
                    try {
                        // 1. High-Performance Low-Latency Wi-Fi Lock
                        if (wifiLock == null) {
                            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
                            val lockMode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                                WifiManager.WIFI_MODE_FULL_LOW_LATENCY
                            } else {
                                WifiManager.WIFI_MODE_FULL_HIGH_PERF
                            }
                            wifiLock = wifiManager?.createWifiLock(lockMode, "playtorrio:stream_wifi")?.apply {
                                setReferenceCounted(false)
                            }
                        }
                        if (wifiLock?.isHeld == false) {
                            wifiLock?.acquire()
                        }

                        // 2. Partial Wake Lock (prevents CPU sleep during streaming)
                        if (wakeLock == null) {
                            val powerManager = applicationContext.getSystemService(Context.POWER_SERVICE) as? PowerManager
                            wakeLock = powerManager?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "playtorrio:stream_wake")?.apply {
                                setReferenceCounted(false)
                            }
                        }
                        if (wakeLock?.isHeld == false) {
                            wakeLock?.acquire(3 * 60 * 60 * 1000L) // 3 hours timeout safety
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("LOCK_ERROR", e.message, null)
                    }
                }
                "releaseLocks" -> {
                    try {
                        if (wifiLock?.isHeld == true) {
                            wifiLock?.release()
                        }
                        if (wakeLock?.isHeld == true) {
                            wakeLock?.release()
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("LOCK_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        try {
            if (wifiLock?.isHeld == true) wifiLock?.release()
            if (wakeLock?.isHeld == true) wakeLock?.release()
        } catch (_: Exception) {}
        super.onDestroy()
    }
}