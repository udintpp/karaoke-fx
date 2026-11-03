package com.karaokefx.app

import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.media.audiofx.AudioEffect
import android.media.audiofx.BassBoost
import android.media.audiofx.Equalizer
import android.media.audiofx.LoudnessEnhancer
import android.media.audiofx.Virtualizer
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

    // AudioSession 0 targets the GLOBAL Android system audio output mix
    private val GLOBAL_AUDIO_SESSION = 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

        initSystemAudioFx()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "init" -> {
                    initSystemAudioFx()
                    result.success(getEqualizerBandsInfo())
                }
                "getSystemVolume" -> {
                    val current = audioManager?.getStreamVolume(AudioManager.STREAM_MUSIC) ?: 0
                    val max = audioManager?.getStreamMaxVolume(AudioManager.STREAM_MUSIC) ?: 15
                    result.success(mapOf("current" to current, "max" to max))
                }
                "setSystemVolume" -> {
                    val volume = call.argument<Int>("volume") ?: 0
                    audioManager?.setStreamVolume(AudioManager.STREAM_MUSIC, volume, 0)
                    result.success(true)
                }
                "setEqualizerEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    try {
                        if (equalizer == null) initSystemAudioFx()
                        equalizer?.enabled = enabled
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
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("FX_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun initSystemAudioFx() {
        try {
            // Attach audio effects to global audio session 0 (system-wide output)
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

            // Notify Android system and other media players of our audio effect session
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

    private fun getEqualizerBandsInfo(): Map<String, Any> {
        val bands = mutableListOf<Map<String, Any>>()
        val eq = equalizer ?: return emptyMap()

        try {
            val numBands = eq.numberOfBands.toInt()
            val levelRange = eq.bandLevelRange // [min, max] in millibels
            for (i in 0 until numBands) {
                val bandIndex = i.toShort()
                val centerFreq = eq.getCenterFreq(bandIndex) // in milliHertz
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

    override fun onDestroy() {
        super.onDestroy()
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
