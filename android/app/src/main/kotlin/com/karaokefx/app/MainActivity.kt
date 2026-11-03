package com.karaokefx.app

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.audiofx.AudioEffect
import android.media.audiofx.BassBoost
import android.media.audiofx.Equalizer
import android.media.audiofx.LoudnessEnhancer
import android.media.audiofx.Virtualizer
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.karaokefx.app/system_audio_fx"

    private var equalizer: Equalizer? = null
    private var bassBoost: BassBoost? = null
    private var virtualizer: Virtualizer? = null
    private var loudnessEnhancer: LoudnessEnhancer? = null
    private var audioManager: AudioManager? = null
    private lateinit var prefs: SharedPreferences

    // AudioSession 0 targets the GLOBAL Android system audio output mix
    private val GLOBAL_AUDIO_SESSION = 0

    // Bluetooth A2DP Sink (Audio Receiver) profile constant
    private val A2DP_SINK = 11
    private var a2dpSinkProxy: BluetoothProfile? = null
    private var connectedSenderDeviceName: String = ""
    private var connectedSenderDeviceAddress: String = ""
    private var isBtReceiverStreaming: Boolean = false
    private var bluetoothReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        prefs = getSharedPreferences("KaraokeFxPrefs", Context.MODE_PRIVATE)

        initSystemAudioFx()
        restoreSavedSettings()
        initBluetoothSink()
        registerBtBroadcastReceiver()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "init" -> {
                    initSystemAudioFx()
                    restoreSavedSettings()
                    result.success(getEqualizerBandsInfo())
                }
                "getSavedPreferences" -> {
                    val map = mapOf(
                        "autoStartOnBoot" to prefs.getBoolean("auto_start_on_boot", true),
                        "backgroundServiceEnabled" to KaraokeFxForegroundService.isRunning,
                        "eqEnabled" to prefs.getBoolean("eq_enabled", false),
                        "bassEnabled" to prefs.getBoolean("bass_enabled", false),
                        "bassStrength" to prefs.getInt("bass_strength", 500),
                        "virtEnabled" to prefs.getBoolean("virt_enabled", false),
                        "virtStrength" to prefs.getInt("virt_strength", 500),
                        "loudEnabled" to prefs.getBoolean("loud_enabled", false),
                        "loudGain" to prefs.getInt("loud_gain", 300),
                        "btReceiverEnabled" to prefs.getBoolean("bt_receiver_enabled", false)
                    )
                    result.success(map)
                }
                "startForegroundService" -> {
                    try {
                        val intent = Intent(this, KaraokeFxForegroundService::class.java).apply {
                            action = KaraokeFxForegroundService.ACTION_START
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        prefs.edit().putBoolean("background_service_enabled", true).apply()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "stopForegroundService" -> {
                    try {
                        val intent = Intent(this, KaraokeFxForegroundService::class.java).apply {
                            action = KaraokeFxForegroundService.ACTION_STOP
                        }
                        startService(intent)
                        prefs.edit().putBoolean("background_service_enabled", false).apply()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", e.message, null)
                    }
                }
                "isForegroundServiceRunning" -> {
                    result.success(KaraokeFxForegroundService.isRunning)
                }
                "setAutoStartOnBoot" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    prefs.edit().putBoolean("auto_start_on_boot", enabled).apply()
                    result.success(true)
                }
                "getSystemVolume" -> {
                    val current = audioManager?.getStreamVolume(AudioManager.STREAM_MUSIC) ?: 0
                    val max = audioManager?.getStreamMaxVolume(AudioManager.STREAM_MUSIC) ?: 15
                    result.success(mapOf("current" to current, "max" to max))
                }
                "setSystemVolume" -> {
                    val volume = call.argument<Int>("volume") ?: 0
                    audioManager?.setStreamVolume(AudioManager.STREAM_MUSIC, volume, 0)
                    prefs.edit().putInt("system_volume", volume).apply()
                    result.success(true)
                }
                "setEqualizerEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    try {
                        if (equalizer == null) initSystemAudioFx()
                        equalizer?.enabled = enabled
                        prefs.edit().putBoolean("eq_enabled", enabled).apply()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("FX_ERROR", e.message, null)
                    }
                }
                "setEqualizerBandLevel" -> {
                    val band = call.argument<Int>("band")?.toShort() ?: 0
                    val level = call.argument<Int>("level")?.toShort() ?: 0
                    try {
                        if (equalizer == null) initSystemAudioFx()
                        equalizer?.setBandLevel(band, level)
                        prefs.edit().putInt("eq_band_$band", level.toInt()).apply()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("FX_ERROR", e.message, null)
                    }
                }
                "setBassBoostEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    try {
                        if (bassBoost == null) initSystemAudioFx()
                        bassBoost?.enabled = enabled
                        prefs.edit().putBoolean("bass_enabled", enabled).apply()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("FX_ERROR", e.message, null)
                    }
                }
                "setBassBoostStrength" -> {
                    val strength = call.argument<Int>("strength")?.toShort() ?: 0
                    try {
                        if (bassBoost == null) initSystemAudioFx()
                        bassBoost?.setStrength(strength)
                        prefs.edit().putInt("bass_strength", strength.toInt()).apply()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("FX_ERROR", e.message, null)
                    }
                }
                "setVirtualizerEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    try {
                        if (virtualizer == null) initSystemAudioFx()
                        virtualizer?.enabled = enabled
                        prefs.edit().putBoolean("virt_enabled", enabled).apply()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("FX_ERROR", e.message, null)
                    }
                }
                "setVirtualizerStrength" -> {
                    val strength = call.argument<Int>("strength")?.toShort() ?: 0
                    try {
                        if (virtualizer == null) initSystemAudioFx()
                        virtualizer?.setStrength(strength)
                        prefs.edit().putInt("virt_strength", strength.toInt()).apply()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("FX_ERROR", e.message, null)
                    }
                }
                "setLoudnessEnhancerEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    try {
                        if (loudnessEnhancer == null) initSystemAudioFx()
                        loudnessEnhancer?.enabled = enabled
                        prefs.edit().putBoolean("loud_enabled", enabled).apply()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("FX_ERROR", e.message, null)
                    }
                }
                "setLoudnessGain" -> {
                    val gainMb = call.argument<Int>("gainMb") ?: 0
                    try {
                        if (loudnessEnhancer == null) initSystemAudioFx()
                        loudnessEnhancer?.setTargetGain(gainMb)
                        prefs.edit().putInt("loud_gain", gainMb).apply()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("FX_ERROR", e.message, null)
                    }
                }

                // ─── Bluetooth Audio Receiver & Router Methods ─────────────
                "getBluetoothAudioStatus" -> {
                    val btManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
                    val adapter = btManager?.adapter
                    val isBtEnabled = adapter?.isEnabled ?: false
                    var connectedSpeaker = ""
                    var connectedMic = ""
                    val isScoConnected = audioManager?.isBluetoothScoOn ?: false

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val devices = audioManager?.getDevices(
                            AudioManager.GET_DEVICES_OUTPUTS or AudioManager.GET_DEVICES_INPUTS
                        ) ?: emptyArray()
                        for (device in devices) {
                            if (device.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
                                device.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO
                            ) {
                                if (device.isSink && connectedSpeaker.isEmpty()) {
                                    connectedSpeaker = device.productName?.toString() ?: "Speaker Bluetooth"
                                }
                                if (device.isSource && connectedMic.isEmpty()) {
                                    connectedMic = device.productName?.toString() ?: "Mic Wireless Bluetooth"
                                }
                            }
                        }
                    }

                    result.success(mapOf(
                        "isBluetoothEnabled" to isBtEnabled,
                        "connectedSpeaker" to connectedSpeaker,
                        "connectedMic" to connectedMic,
                        "isScoOn" to isScoConnected,
                        "isLowLatencyOn" to (audioManager?.mode == AudioManager.MODE_IN_COMMUNICATION)
                    ))
                }
                "setBluetoothMicEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    try {
                        if (enabled) {
                            audioManager?.mode = AudioManager.MODE_IN_COMMUNICATION
                            audioManager?.startBluetoothSco()
                            audioManager?.isBluetoothScoOn = true
                        } else {
                            audioManager?.stopBluetoothSco()
                            audioManager?.isBluetoothScoOn = false
                            audioManager?.mode = AudioManager.MODE_NORMAL
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("BT_ERROR", e.message, null)
                    }
                }
                "setBluetoothSpeakerEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    try {
                        audioManager?.isSpeakerphoneOn = !enabled
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("BT_ERROR", e.message, null)
                    }
                }
                "setLowLatencyMode" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    try {
                        audioManager?.mode = if (enabled) {
                            AudioManager.MODE_IN_COMMUNICATION
                        } else {
                            AudioManager.MODE_NORMAL
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("AUDIO_ERROR", e.message, null)
                    }
                }
                "openBluetoothSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_BLUETOOTH_SETTINGS).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INTENT_ERROR", e.message, null)
                    }
                }

                // ─── Bluetooth Audio Receiver (A2DP Sink) Methods ──────────
                "requestBluetoothPermissions" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val permissions = arrayOf(
                            android.Manifest.permission.BLUETOOTH_CONNECT,
                            android.Manifest.permission.BLUETOOTH_SCAN,
                            android.Manifest.permission.BLUETOOTH_ADVERTISE
                        )
                        val missing = permissions.filter {
                            checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED
                        }
                        if (missing.isNotEmpty()) {
                            ActivityCompat.requestPermissions(this, missing.toTypedArray(), 1002)
                        }
                    }
                    result.success(true)
                }
                "enableBluetooth" -> {
                    try {
                        val enableBtIntent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(enableBtIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ENABLE_BT_ERROR", e.message, null)
                    }
                }
                "startBluetoothReceiverMode" -> {
                    val duration = call.argument<Int>("duration") ?: 300
                    prefs.edit().putBoolean("bt_receiver_enabled", true).apply()
                    initSystemAudioFx()

                    // Check if Bluetooth is enabled; if not, prompt user
                    try {
                        val btManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
                        val adapter = btManager?.adapter
                        if (adapter != null && !adapter.isEnabled) {
                            val enableBtIntent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(enableBtIntent)
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }

                    // Ensure background service is running so stream doesn't drop when screen turns off
                    try {
                        val svcIntent = Intent(this, KaraokeFxForegroundService::class.java).apply {
                            action = KaraokeFxForegroundService.ACTION_START
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(svcIntent)
                        } else {
                            startService(svcIntent)
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }

                    // Prompt discoverable so other phones/laptops can discover this device
                    try {
                        val discoverableIntent = Intent(BluetoothAdapter.ACTION_REQUEST_DISCOVERABLE).apply {
                            putExtra(BluetoothAdapter.EXTRA_DISCOVERABLE_DURATION, duration)
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(discoverableIntent)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }

                    initBluetoothSink()
                    result.success(true)
                }
                "stopBluetoothReceiverMode" -> {
                    prefs.edit().putBoolean("bt_receiver_enabled", false).apply()
                    result.success(true)
                }
                "requestDiscoverable" -> {
                    val duration = call.argument<Int>("duration") ?: 300
                    try {
                        val discoverableIntent = Intent(BluetoothAdapter.ACTION_REQUEST_DISCOVERABLE).apply {
                            putExtra(BluetoothAdapter.EXTRA_DISCOVERABLE_DURATION, duration)
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(discoverableIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("DISCOVERABLE_ERROR", e.message, null)
                    }
                }
                "getBluetoothReceiverStatus" -> {
                    try {
                        val btManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
                        val adapter = btManager?.adapter
                        val isBtEnabled = try { adapter?.isEnabled ?: false } catch (_: Exception) { false }
                        val isDiscoverable = try {
                            adapter?.scanMode == BluetoothAdapter.SCAN_MODE_CONNECTABLE_DISCOVERABLE
                        } catch (_: Exception) { false }
                        val localName = try {
                            adapter?.name ?: "Android Karaoke Device"
                        } catch (_: Exception) { "Android Karaoke Device" }

                        try { updateConnectedSenderDevice() } catch (_: Exception) {}

                        result.success(mapOf(
                            "isReceiverEnabled" to prefs.getBoolean("bt_receiver_enabled", false),
                            "isBluetoothEnabled" to isBtEnabled,
                            "isDiscoverable" to isDiscoverable,
                            "localDeviceName" to localName,
                            "connectedSenderName" to connectedSenderDeviceName,
                            "connectedSenderAddress" to connectedSenderDeviceAddress,
                            "isPlayingMusic" to isBtReceiverStreaming,
                            "isSinkSupported" to (a2dpSinkProxy != null)
                        ))
                    } catch (e: Exception) {
                        result.success(mapOf(
                            "isReceiverEnabled" to prefs.getBoolean("bt_receiver_enabled", false),
                            "isBluetoothEnabled" to false,
                            "isDiscoverable" to false,
                            "localDeviceName" to "Android Karaoke Device",
                            "connectedSenderName" to "",
                            "connectedSenderAddress" to "",
                            "isPlayingMusic" to false,
                            "isSinkSupported" to false
                        ))
                    }
                }

                // ─── Realtime Mic Pass-Through & DSP Methods ────────────────
                "startRealtimeMic" -> {
                    try {
                        val engine = RealtimeMicEngine.getInstance()
                        engine.audioManager = audioManager  // inject so engine can set MODE_IN_COMMUNICATION
                        val success = engine.start()
                        result.success(success)
                    } catch (e: Exception) {
                        result.error("MIC_ERROR", e.message, null)
                    }
                }
                "stopRealtimeMic" -> {
                    try {
                        RealtimeMicEngine.getInstance().stop()
                        audioManager?.mode = AudioManager.MODE_NORMAL  // restore normal audio routing
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("MIC_ERROR", e.message, null)
                    }
                }
                "isRealtimeMicActive" -> {
                    result.success(RealtimeMicEngine.getInstance().isLive())
                }
                "getRealtimeMicVu" -> {
                    result.success(RealtimeMicEngine.getInstance().liveVuLevel.toDouble())
                }
                "updateRealtimeMicSettings" -> {
                    try {
                        val settings = call.arguments as? Map<String, Any?> ?: emptyMap()
                        RealtimeMicEngine.getInstance().updateSettings(settings)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("MIC_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun initSystemAudioFx() {
        try {
            if (equalizer == null) {
                equalizer = Equalizer(1000, GLOBAL_AUDIO_SESSION)
            }
            if (bassBoost == null) {
                bassBoost = BassBoost(1000, GLOBAL_AUDIO_SESSION)
            }
            if (virtualizer == null) {
                virtualizer = Virtualizer(1000, GLOBAL_AUDIO_SESSION)
            }
            if (loudnessEnhancer == null) {
                loudnessEnhancer = LoudnessEnhancer(GLOBAL_AUDIO_SESSION)
            }

            val intent = Intent(AudioEffect.ACTION_OPEN_AUDIO_EFFECT_CONTROL_SESSION).apply {
                putExtra(AudioEffect.EXTRA_AUDIO_SESSION, GLOBAL_AUDIO_SESSION)
                putExtra(AudioEffect.EXTRA_PACKAGE_NAME, packageName)
                putExtra(AudioEffect.EXTRA_CONTENT_TYPE, AudioEffect.CONTENT_TYPE_MUSIC)
            }
            sendBroadcast(intent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun restoreSavedSettings() {
        try {
            val eqEnabled = prefs.getBoolean("eq_enabled", false)
            equalizer?.enabled = eqEnabled
            val eq = equalizer
            if (eq != null) {
                val numBands = eq.numberOfBands.toInt()
                for (i in 0 until numBands) {
                    val savedLevel = prefs.getInt("eq_band_$i", 0)
                    eq.setBandLevel(i.toShort(), savedLevel.toShort())
                }
            }

            val bassEnabled = prefs.getBoolean("bass_enabled", false)
            val bassStrength = prefs.getInt("bass_strength", 500)
            bassBoost?.enabled = bassEnabled
            bassBoost?.setStrength(bassStrength.toShort())

            val virtEnabled = prefs.getBoolean("virt_enabled", false)
            val virtStrength = prefs.getInt("virt_strength", 500)
            virtualizer?.enabled = virtEnabled
            virtualizer?.setStrength(virtStrength.toShort())

            val loudEnabled = prefs.getBoolean("loud_enabled", false)
            val loudGain = prefs.getInt("loud_gain", 300)
            loudnessEnhancer?.enabled = loudEnabled
            loudnessEnhancer?.setTargetGain(loudGain)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun getEqualizerBandsInfo(): Map<String, Any> {
        val bands = mutableListOf<Map<String, Any>>()
        val eq = equalizer ?: return emptyMap()

        try {
            val numBands = eq.numberOfBands.toInt()
            val levelRange = eq.bandLevelRange
            for (i in 0 until numBands) {
                val bandIndex = i.toShort()
                val centerFreq = eq.getCenterFreq(bandIndex)
                val currentLevel = eq.getBandLevel(bandIndex)
                bands.add(mapOf(
                    "index" to i,
                    "centerFreqHz" to centerFreq / 1000,
                    "level" to currentLevel.toInt()
                ))
            }

            return mapOf(
                "minLevel" to levelRange[0].toInt(),
                "maxLevel" to levelRange[1].toInt(),
                "bands" to bands
            )
        } catch (e: Exception) {
            return emptyMap()
        }
    }

    private fun initBluetoothSink() {
        val btManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val adapter = btManager?.adapter ?: return
        try {
            adapter.getProfileProxy(applicationContext, object : BluetoothProfile.ServiceListener {
                override fun onServiceConnected(profile: Int, proxy: BluetoothProfile) {
                    if (profile == A2DP_SINK) {
                        a2dpSinkProxy = proxy
                        updateConnectedSenderDevice()
                    }
                }
                override fun onServiceDisconnected(profile: Int) {
                    if (profile == A2DP_SINK) {
                        a2dpSinkProxy = null
                        connectedSenderDeviceName = ""
                        connectedSenderDeviceAddress = ""
                        isBtReceiverStreaming = false
                    }
                }
            }, A2DP_SINK)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun registerBtBroadcastReceiver() {
        if (bluetoothReceiver != null) return
        bluetoothReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val action = intent?.action ?: return
                when (action) {
                    BluetoothDevice.ACTION_ACL_CONNECTED -> {
                        val device = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
                        } else {
                            @Suppress("DEPRECATION")
                            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                        }
                        if (device != null) {
                            connectedSenderDeviceName = device.name ?: "Perangkat Terhubung"
                            connectedSenderDeviceAddress = device.address ?: ""
                        }
                    }
                    BluetoothDevice.ACTION_ACL_DISCONNECTED -> {
                        connectedSenderDeviceName = ""
                        connectedSenderDeviceAddress = ""
                        isBtReceiverStreaming = false
                    }
                    "android.bluetooth.a2dp-sink.profile.action.CONNECTION_STATE_CHANGED" -> {
                        val state = intent.getIntExtra(BluetoothProfile.EXTRA_STATE, BluetoothProfile.STATE_DISCONNECTED)
                        val device = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
                        } else {
                            @Suppress("DEPRECATION")
                            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                        }
                        if (state == BluetoothProfile.STATE_CONNECTED && device != null) {
                            connectedSenderDeviceName = device.name ?: "Perangkat Audio Pengirim"
                            connectedSenderDeviceAddress = device.address ?: ""
                        } else if (state == BluetoothProfile.STATE_DISCONNECTED) {
                            connectedSenderDeviceName = ""
                            connectedSenderDeviceAddress = ""
                            isBtReceiverStreaming = false
                        }
                    }
                    "android.bluetooth.a2dp-sink.profile.action.PLAYING_STATE_CHANGED" -> {
                        val playState = intent.getIntExtra(BluetoothProfile.EXTRA_STATE, 0)
                        isBtReceiverStreaming = (playState == 10 || playState == 1)
                    }
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(BluetoothAdapter.ACTION_SCAN_MODE_CHANGED)
            addAction(BluetoothAdapter.ACTION_STATE_CHANGED)
            addAction(BluetoothDevice.ACTION_ACL_CONNECTED)
            addAction(BluetoothDevice.ACTION_ACL_DISCONNECTED)
            addAction("android.bluetooth.a2dp-sink.profile.action.CONNECTION_STATE_CHANGED")
            addAction("android.bluetooth.a2dp-sink.profile.action.PLAYING_STATE_CHANGED")
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(bluetoothReceiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                registerReceiver(bluetoothReceiver, filter)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun updateConnectedSenderDevice() {
        try {
            val proxy = a2dpSinkProxy
            if (proxy != null) {
                val devices = proxy.connectedDevices
                if (devices.isNotEmpty()) {
                    val dev = devices[0]
                    connectedSenderDeviceName = dev.name ?: "Perangkat Pengirim"
                    connectedSenderDeviceAddress = dev.address ?: ""
                    try {
                        val method = proxy.javaClass.getMethod("isA2dpPlaying", BluetoothDevice::class.java)
                        isBtReceiverStreaming = method.invoke(proxy, dev) as? Boolean ?: false
                    } catch (_: Exception) {
                        isBtReceiverStreaming = true
                    }
                    return
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            RealtimeMicEngine.getInstance().stop()
        } catch (_: Exception) {}
        if (bluetoothReceiver != null) {
            try {
                unregisterReceiver(bluetoothReceiver)
            } catch (_: Exception) {}
            bluetoothReceiver = null
        }
        if (a2dpSinkProxy != null) {
            val btManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
            btManager?.adapter?.closeProfileProxy(A2DP_SINK, a2dpSinkProxy)
            a2dpSinkProxy = null
        }

        if (!KaraokeFxForegroundService.isRunning) {
            try {
                val intent = Intent(AudioEffect.ACTION_CLOSE_AUDIO_EFFECT_CONTROL_SESSION).apply {
                    putExtra(AudioEffect.EXTRA_AUDIO_SESSION, GLOBAL_AUDIO_SESSION)
                    putExtra(AudioEffect.EXTRA_PACKAGE_NAME, packageName)
                }
                sendBroadcast(intent)

                equalizer?.release()
                bassBoost?.release()
                virtualizer?.release()
                loudnessEnhancer?.release()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
