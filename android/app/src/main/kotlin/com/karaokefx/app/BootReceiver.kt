package com.karaokefx.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.media.audiofx.BassBoost
import android.media.audiofx.Equalizer
import android.media.audiofx.LoudnessEnhancer
import android.media.audiofx.Virtualizer
import android.os.Build

class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action == Intent.ACTION_BOOT_COMPLETED ||
            intent?.action == "android.intent.action.QUICKBOOT_POWERON"
        ) {
            val prefs = context.getSharedPreferences("KaraokeFxPrefs", Context.MODE_PRIVATE)
            val autoStart = prefs.getBoolean("auto_start_on_boot", true)

            if (autoStart) {
                // Restore saved Audio FX to Android system hardware
                try {
                    val eqEnabled = prefs.getBoolean("eq_enabled", false)
                    val eq = Equalizer(1000, 0)
                    eq.enabled = eqEnabled
                    val numBands = eq.numberOfBands.toInt()
                    for (i in 0 until numBands) {
                        val savedLevel = prefs.getInt("eq_band_$i", 0)
                        eq.setBandLevel(i.toShort(), savedLevel.toShort())
                    }

                    val bassEnabled = prefs.getBoolean("bass_enabled", false)
                    val bassStrength = prefs.getInt("bass_strength", 500)
                    val bass = BassBoost(1000, 0)
                    bass.enabled = bassEnabled
                    bass.setStrength(bassStrength.toShort())

                    val virtEnabled = prefs.getBoolean("virt_enabled", false)
                    val virtStrength = prefs.getInt("virt_strength", 500)
                    val virt = Virtualizer(1000, 0)
                    virt.enabled = virtEnabled
                    virt.setStrength(virtStrength.toShort())

                    val loudEnabled = prefs.getBoolean("loud_enabled", false)
                    val loudGain = prefs.getInt("loud_gain", 300)
                    val loud = LoudnessEnhancer(0)
                    loud.enabled = loudEnabled
                    loud.setTargetGain(loudGain)

                    val savedVolume = prefs.getInt("system_volume", -1)
                    if (savedVolume >= 0) {
                        val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        am.setStreamVolume(AudioManager.STREAM_MUSIC, savedVolume, 0)
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                }

                // Start Foreground Service so effects persist in background
                val serviceIntent = Intent(context, KaraokeFxForegroundService::class.java).apply {
                    action = KaraokeFxForegroundService.ACTION_START
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
            }
        }
    }
}
