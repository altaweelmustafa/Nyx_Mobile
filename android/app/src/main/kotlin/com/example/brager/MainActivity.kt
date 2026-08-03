package com.example.brager

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothClass
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothProfile
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Bridges the "which Bluetooth audio device is connected right now, and
/// what kind is it" query used by the mini player / track view Bluetooth
/// indicator. Classic Bluetooth (A2DP/HFP), not BLE -- that's what
/// headphones, speakers and car head units use for audio.
class MainActivity : FlutterActivity() {
    private val channelName = "com.brager/bluetooth"
    private val proxyTimeout = 3000L
    private val requestCodeBluetoothConnect = 4201

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getConnectedDevice" -> queryConnectedDevice(result)
                    else -> result.notImplemented()
                }
            }
    }

    /// BLUETOOTH_CONNECT is a runtime (dangerous) permission from API 31 on;
    /// without it, connectedDevices() throws SecurityException. We ask once
    /// per cold start -- the next poll (a few seconds later) picks up the
    /// result once the user responds.
    private fun ensureBluetoothConnectPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val granted = ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) ==
            PackageManager.PERMISSION_GRANTED
        if (!granted) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.BLUETOOTH_CONNECT),
                requestCodeBluetoothConnect,
            )
        }
        return granted
    }

    private fun queryConnectedDevice(result: MethodChannel.Result) {
        val adapter = BluetoothAdapter.getDefaultAdapter()
        if (adapter == null || !adapter.isEnabled || !ensureBluetoothConnectPermission()) {
            result.success(null)
            return
        }

        var finished = false
        val finish: (Map<String, Any?>?) -> Unit = { value ->
            if (!finished) {
                finished = true
                result.success(value)
            }
        }

        Handler(Looper.getMainLooper()).postDelayed({ finish(null) }, proxyTimeout)

        try {
            adapter.getProfileProxy(
                applicationContext,
                object : BluetoothProfile.ServiceListener {
                    override fun onServiceConnected(profile: Int, proxy: BluetoothProfile) {
                        val device = proxy.connectedDevices.firstOrNull()
                        adapter.closeProfileProxy(BluetoothProfile.A2DP, proxy)
                        if (device != null) {
                            finish(deviceToMap(device))
                        } else {
                            queryHeadsetProfile(adapter, finish)
                        }
                    }

                    override fun onServiceDisconnected(profile: Int) {}
                },
                BluetoothProfile.A2DP,
            )
        } catch (e: SecurityException) {
            finish(null)
        }
    }

    private fun queryHeadsetProfile(adapter: BluetoothAdapter, finish: (Map<String, Any?>?) -> Unit) {
        try {
            adapter.getProfileProxy(
                applicationContext,
                object : BluetoothProfile.ServiceListener {
                    override fun onServiceConnected(profile: Int, proxy: BluetoothProfile) {
                        val device = proxy.connectedDevices.firstOrNull()
                        adapter.closeProfileProxy(BluetoothProfile.HEADSET, proxy)
                        finish(if (device != null) deviceToMap(device) else null)
                    }

                    override fun onServiceDisconnected(profile: Int) {}
                },
                BluetoothProfile.HEADSET,
            )
        } catch (e: SecurityException) {
            finish(null)
        }
    }

    private fun deviceToMap(device: BluetoothDevice): Map<String, Any?> {
        val name = try {
            device.name
        } catch (e: SecurityException) {
            null
        } ?: "Bluetooth Device"
        val deviceClass = try {
            device.bluetoothClass?.deviceClass
        } catch (e: SecurityException) {
            null
        }
        return mapOf("name" to name, "type" to classify(deviceClass))
    }

    private fun classify(deviceClass: Int?): String = when (deviceClass) {
        BluetoothClass.Device.AUDIO_VIDEO_WEARABLE_HEADSET,
        BluetoothClass.Device.AUDIO_VIDEO_HEADPHONES,
        BluetoothClass.Device.AUDIO_VIDEO_PORTABLE_AUDIO,
        -> "headphones"
        BluetoothClass.Device.AUDIO_VIDEO_CAR_AUDIO,
        BluetoothClass.Device.AUDIO_VIDEO_HANDSFREE,
        -> "car"
        BluetoothClass.Device.AUDIO_VIDEO_LOUDSPEAKER,
        BluetoothClass.Device.AUDIO_VIDEO_HIFI_AUDIO,
        -> "speaker"
        else -> "unknown"
    }
}
