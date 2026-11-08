package com.karaokefx.app

import android.media.MediaPlayer
import android.util.Log
import android.view.Surface
import io.flutter.view.TextureRegistry

/**
 * Lightweight native MP4 video player using Android MediaPlayer rendered directly
 * into a Flutter TextureRegistry.SurfaceTextureEntry (zero external player plugin overhead).
 */
class RecordedVideoPlayer(private val textureRegistry: TextureRegistry) {
    companion object {
        private const val TAG = "RecordedVideoPlayer"
    }

    private var surfaceEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var surface: Surface? = null
    private var mediaPlayer: MediaPlayer? = null
    private var onCompletedCallback: (() -> Unit)? = null

    fun play(
        filePath: String,
        onPrepared: (Map<String, Any>) -> Unit,
        onError: (String) -> Unit,
        onCompleted: () -> Unit
    ) {
        stop()
        onCompletedCallback = onCompleted

        try {
            val entry = textureRegistry.createSurfaceTexture()
            surfaceEntry = entry
            val surf = Surface(entry.surfaceTexture())
            surface = surf

            val mp = MediaPlayer().apply {
                setDataSource(filePath)
                setSurface(surf)
                setOnPreparedListener { player ->
                    val w = if (player.videoWidth > 0) player.videoWidth else 720
                    val h = if (player.videoHeight > 0) player.videoHeight else 960
                    entry.surfaceTexture().setDefaultBufferSize(w, h)
                    player.start()
                    onPrepared(
                        mapOf(
                            "textureId" to entry.id(),
                            "videoWidth" to w,
                            "videoHeight" to h,
                            "durationMs" to player.duration
                        )
                    )
                }
                setOnCompletionListener {
                    onCompletedCallback?.invoke()
                }
                setOnErrorListener { _, what, extra ->
                    Log.e(TAG, "MediaPlayer error what=$what extra=$extra")
                    onError("MediaPlayer error $what/$extra")
                    true
                }
                prepareAsync()
            }
            mediaPlayer = mp
        } catch (e: Exception) {
            Log.e(TAG, "Error starting recorded video playback: ${e.message}", e)
            stop()
            onError(e.message ?: "Playback error")
        }
    }

    fun togglePause(): Boolean {
        val mp = mediaPlayer ?: return false
        return try {
            if (mp.isPlaying) {
                mp.pause()
                false
            } else {
                mp.start()
                true
            }
        } catch (_: Exception) {
            false
        }
    }

    fun seekTo(positionMs: Int) {
        try {
            mediaPlayer?.seekTo(positionMs)
        } catch (_: Exception) {}
    }

    fun getPositionInfo(): Map<String, Any> {
        val mp = mediaPlayer ?: return mapOf("positionMs" to 0, "durationMs" to 0, "isPlaying" to false)
        return try {
            mapOf(
                "positionMs" to mp.currentPosition,
                "durationMs" to mp.duration,
                "isPlaying" to mp.isPlaying
            )
        } catch (_: Exception) {
            mapOf("positionMs" to 0, "durationMs" to 0, "isPlaying" to false)
        }
    }

    fun stop() {
        onCompletedCallback = null
        try {
            mediaPlayer?.stop()
        } catch (_: Exception) {}
        try {
            mediaPlayer?.release()
        } catch (_: Exception) {}
        mediaPlayer = null

        try {
            surface?.release()
        } catch (_: Exception) {}
        surface = null

        try {
            surfaceEntry?.release()
        } catch (_: Exception) {}
        surfaceEntry = null
    }
}
