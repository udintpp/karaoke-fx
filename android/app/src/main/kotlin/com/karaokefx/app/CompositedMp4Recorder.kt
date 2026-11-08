package com.karaokefx.app

import android.annotation.SuppressLint
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.MediaRecorder
import android.media.audiofx.AcousticEchoCanceler
import android.media.audiofx.NoiseSuppressor
import android.util.Log
import android.view.Surface
import java.io.File
import java.nio.ByteBuffer
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.max

/**
 * Hardware-accelerated MP4 (H.264 + AAC) recorder for OpenGL ES composited frames.
 * - Accepts an EGL-compatible Surface for recording composited frames (Person Cutout + Image/Video Backdrop + AI Filter).
 * - Mixes processed DSP mic audio seamlessly from RealtimeMicEngine (when live), or opens a fallback AudioRecord.
 * - Thread-safe MediaMuxer start synchronization buffers initial frames until both audio & video tracks report format.
 */
class CompositedMp4Recorder {

    companion object {
        private const val TAG = "CompositedMp4Recorder"
        private const val VIDEO_MIME = MediaFormat.MIMETYPE_VIDEO_AVC
        private const val AUDIO_MIME = MediaFormat.MIMETYPE_AUDIO_AAC
        private const val SAMPLE_RATE = 44100
        private const val CHANNEL_COUNT = 1
        private const val AUDIO_BITRATE = 128_000
        private const val VIDEO_BITRATE = 4_000_000
        private const val VIDEO_FPS = 30
    }

    private data class PendingPacket(
        val isVideo: Boolean,
        val data: ByteArray,
        val offset: Int,
        val size: Int,
        val presentationTimeUs: Long,
        val flags: Int
    )

    private var videoEncoder: MediaCodec? = null
    private var audioEncoder: MediaCodec? = null
    private var muxer: MediaMuxer? = null

    var inputSurface: Surface? = null
        private set

    private val isRecordingFlag = AtomicBoolean(false)
    private val stopRequested = AtomicBoolean(false)
    @Volatile
    var startTimeNs: Long = 0L
        private set

    private val muxerLock = Object()
    @Volatile private var videoTrackIndex = -1
    @Volatile private var audioTrackIndex = -1
    @Volatile private var muxerStarted = false
    private val pendingPackets = ArrayList<PendingPacket>(32)

    private var videoDrainThread: Thread? = null
    private var audioWorkerThread: Thread? = null

    // Non-blocking queue for receiving PCM chunks from RealtimeMicEngine
    private var pcmQueue: ArrayBlockingQueue<ShortArray>? = null
    private var usingExternalMicEngine = false

    private var fallbackAudioRecord: AudioRecord? = null
    private var fallbackAec: AcousticEchoCanceler? = null
    private var fallbackNs: NoiseSuppressor? = null

    private var outputFilePath: String? = null

    val isRecording: Boolean
        get() = isRecordingFlag.get()

    fun start(outputPath: String, width: Int, height: Int): Surface? {
        if (isRecordingFlag.get()) return inputSurface

        try {
            val outFile = File(outputPath)
            outFile.parentFile?.mkdirs()
            if (outFile.exists()) outFile.delete()
            outputFilePath = outFile.absolutePath

            synchronized(muxerLock) {
                videoTrackIndex = -1
                audioTrackIndex = -1
                muxerStarted = false
                pendingPackets.clear()
            }
            stopRequested.set(false)

            // 1. Setup H.264 Video Encoder
            val videoFormat = MediaFormat.createVideoFormat(VIDEO_MIME, width, height).apply {
                setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
                setInteger(MediaFormat.KEY_BIT_RATE, VIDEO_BITRATE)
                setInteger(MediaFormat.KEY_FRAME_RATE, VIDEO_FPS)
                setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
            }
            videoEncoder = MediaCodec.createEncoderByType(VIDEO_MIME).apply {
                configure(videoFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
                inputSurface = createInputSurface()
                start()
            }

            // 2. Setup AAC Audio Encoder
            val audioFormat = MediaFormat.createAudioFormat(AUDIO_MIME, SAMPLE_RATE, CHANNEL_COUNT).apply {
                setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
                setInteger(MediaFormat.KEY_BIT_RATE, AUDIO_BITRATE)
                setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16384)
            }
            audioEncoder = MediaCodec.createEncoderByType(AUDIO_MIME).apply {
                configure(audioFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
                start()
            }

            // 3. Create MediaMuxer
            muxer = MediaMuxer(outFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

            startTimeNs = System.nanoTime()
            isRecordingFlag.set(true)

            // 4. Attach audio source: share RealtimeMicEngine if already running to avoid dual-MIC contention
            val micEngine = RealtimeMicEngine.getInstance()
            if (micEngine.isLive()) {
                usingExternalMicEngine = true
                val queue = ArrayBlockingQueue<ShortArray>(96)
                pcmQueue = queue
                micEngine.audioFrameConsumer = { samples, count ->
                    if (isRecordingFlag.get() && !stopRequested.get()) {
                        queue.offer(samples.copyOf(count))
                    }
                }
            } else {
                usingExternalMicEngine = false
                pcmQueue = null
                startFallbackAudioRecord()
            }

            // 5. Start background drain / encode worker threads
            videoDrainThread = Thread({ drainVideoLoop() }, "Karaoke-VideoDrain").apply {
                isDaemon = true
                start()
            }
            audioWorkerThread = Thread({ encodeAndDrainAudioLoop() }, "Karaoke-AudioEncode").apply {
                isDaemon = true
                start()
            }

            Log.i(TAG, "Composited MP4 recording started (${width}x${height}, externalMic=$usingExternalMicEngine) -> $outputPath")
            return inputSurface
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start CompositedMp4Recorder: ${e.message}", e)
            cleanupResources()
            return null
        }
    }

    @SuppressLint("MissingPermission")
    private fun startFallbackAudioRecord() {
        try {
            val minBuf = AudioRecord.getMinBufferSize(
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )
            val bufSize = max(minBuf, 4096)
            val record = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                bufSize
            )
            if (record.state == AudioRecord.STATE_INITIALIZED) {
                val sid = record.audioSessionId
                if (AcousticEchoCanceler.isAvailable()) {
                    try {
                        fallbackAec = AcousticEchoCanceler.create(sid)?.apply { enabled = true }
                    } catch (_: Exception) {}
                }
                if (NoiseSuppressor.isAvailable()) {
                    try {
                        fallbackNs = NoiseSuppressor.create(sid)?.apply { enabled = true }
                    } catch (_: Exception) {}
                }
                record.startRecording()
                fallbackAudioRecord = record
            } else {
                record.release()
            }
        } catch (e: Exception) {
            Log.w(TAG, "Fallback AudioRecord init error: ${e.message}")
        }
    }

    /**
     * Signals EOS and finalizes MP4 cleanly. Returns saved file path or null on error.
     */
    fun stop(): String? {
        if (!isRecordingFlag.get()) return null
        stopRequested.set(true)
        isRecordingFlag.set(false)

        if (usingExternalMicEngine) {
            RealtimeMicEngine.getInstance().audioFrameConsumer = null
        }

        try {
            videoEncoder?.signalEndOfInputStream()
        } catch (e: Exception) {
            Log.w(TAG, "signalEndOfInputStream error: ${e.message}")
        }

        try {
            videoDrainThread?.join(2500)
        } catch (_: Exception) {}
        try {
            audioWorkerThread?.join(2500)
        } catch (_: Exception) {}

        val savedPath = outputFilePath
        cleanupResources()

        return if (savedPath != null && File(savedPath).exists() && File(savedPath).length() > 0) {
            Log.i(TAG, "Saved composited MP4 ($savedPath, ${File(savedPath).length()} bytes)")
            savedPath
        } else {
            null
        }
    }

    private fun drainVideoLoop() {
        val encoder = videoEncoder ?: return
        val info = MediaCodec.BufferInfo()
        val deadlineNs = System.nanoTime() + 4_000_000_000L

        while (true) {
            try {
                val outIndex = encoder.dequeueOutputBuffer(info, 10_000)
                if (outIndex == MediaCodec.INFO_TRY_AGAIN_LATER) {
                    if (stopRequested.get() && System.nanoTime() > deadlineNs) break
                } else if (outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    synchronized(muxerLock) {
                        if (videoTrackIndex == -1) {
                            videoTrackIndex = muxer?.addTrack(encoder.outputFormat) ?: -1
                            tryStartMuxerLocked()
                        }
                    }
                } else if (outIndex >= 0) {
                    val encodedData = encoder.getOutputBuffer(outIndex)
                    if (encodedData != null && info.size > 0 && (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) == 0) {
                        encodedData.position(info.offset)
                        encodedData.limit(info.offset + info.size)
                        writeOrQueueSample(isVideo = true, buffer = encodedData, info = info)
                    }
                    encoder.releaseOutputBuffer(outIndex, false)
                    if ((info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                        break
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Video drain error: ${e.message}")
                break
            }
        }
    }

    private fun encodeAndDrainAudioLoop() {
        val encoder = audioEncoder ?: return
        val info = MediaCodec.BufferInfo()
        val fallbackShorts = ShortArray(1024)
        var totalSamplesFed = 0L
        var eosSent = false
        var eosReceived = false

        while (!eosReceived) {
            try {
                // 1. Feed PCM to audioEncoder
                if (!eosSent) {
                    var pcmSamples: ShortArray? = null
                    var sampleCount = 0

                    if (usingExternalMicEngine) {
                        val polled = pcmQueue?.poll(15, TimeUnit.MILLISECONDS)
                        if (polled != null) {
                            pcmSamples = polled
                            sampleCount = polled.size
                        }
                    } else {
                        val rec = fallbackAudioRecord
                        if (rec != null && !stopRequested.get()) {
                            val read = rec.read(fallbackShorts, 0, fallbackShorts.size)
                            if (read > 0) {
                                pcmSamples = fallbackShorts
                                sampleCount = read
                            }
                        } else if (!stopRequested.get()) {
                            Thread.sleep(15)
                        }
                    }

                    if (pcmSamples != null && sampleCount > 0) {
                        val inIdx = encoder.dequeueInputBuffer(10_000)
                        if (inIdx >= 0) {
                            val inBuf = encoder.getInputBuffer(inIdx)
                            if (inBuf != null) {
                                inBuf.clear()
                                val byteLen = minOf(sampleCount * 2, inBuf.capacity())
                                val actualSamples = byteLen / 2
                                for (i in 0 until actualSamples) {
                                    val s = pcmSamples[i].toInt()
                                    inBuf.put((s and 0xFF).toByte())
                                    inBuf.put(((s shr 8) and 0xFF).toByte())
                                }
                                val ptsUs = totalSamplesFed * 1_000_000L / SAMPLE_RATE
                                encoder.queueInputBuffer(inIdx, 0, actualSamples * 2, ptsUs, 0)
                                totalSamplesFed += actualSamples
                            }
                        }
                    } else if (stopRequested.get()) {
                        val inIdx = encoder.dequeueInputBuffer(10_000)
                        if (inIdx >= 0) {
                            val ptsUs = totalSamplesFed * 1_000_000L / SAMPLE_RATE
                            encoder.queueInputBuffer(
                                inIdx, 0, 0, ptsUs,
                                MediaCodec.BUFFER_FLAG_END_OF_STREAM
                            )
                            eosSent = true
                        }
                    }
                }

                // 2. Drain encoded AAC packets
                var keepDraining = true
                while (keepDraining) {
                    val outIndex = encoder.dequeueOutputBuffer(info, if (eosSent) 10_000L else 0L)
                    if (outIndex == MediaCodec.INFO_TRY_AGAIN_LATER) {
                        keepDraining = false
                    } else if (outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                        synchronized(muxerLock) {
                            if (audioTrackIndex == -1) {
                                audioTrackIndex = muxer?.addTrack(encoder.outputFormat) ?: -1
                                tryStartMuxerLocked()
                            }
                        }
                    } else if (outIndex >= 0) {
                        val encodedData = encoder.getOutputBuffer(outIndex)
                        if (encodedData != null && info.size > 0 && (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) == 0) {
                            encodedData.position(info.offset)
                            encodedData.limit(info.offset + info.size)
                            writeOrQueueSample(isVideo = false, buffer = encodedData, info = info)
                        }
                        encoder.releaseOutputBuffer(outIndex, false)
                        if ((info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                            eosReceived = true
                            keepDraining = false
                        }
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Audio encode/drain error: ${e.message}")
                break
            }
        }
    }

    private fun tryStartMuxerLocked() {
        if (!muxerStarted && videoTrackIndex != -1 && audioTrackIndex != -1) {
            try {
                muxer?.start()
                muxerStarted = true
                // Flush queued samples from early-arriving track
                val writeInfo = MediaCodec.BufferInfo()
                for (pkt in pendingPackets) {
                    val trackIdx = if (pkt.isVideo) videoTrackIndex else audioTrackIndex
                    if (trackIdx >= 0) {
                        writeInfo.set(0, pkt.size, pkt.presentationTimeUs, pkt.flags)
                        muxer?.writeSampleData(trackIdx, ByteBuffer.wrap(pkt.data, 0, pkt.size), writeInfo)
                    }
                }
                pendingPackets.clear()
                Log.i(TAG, "MediaMuxer started with both A/V tracks!")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start muxer: ${e.message}", e)
            }
        }
    }

    private fun writeOrQueueSample(isVideo: Boolean, buffer: ByteBuffer, info: MediaCodec.BufferInfo) {
        synchronized(muxerLock) {
            if (!muxerStarted) {
                if (pendingPackets.size < 180) {
                    val copy = ByteArray(info.size)
                    buffer.get(copy)
                    pendingPackets.add(
                        PendingPacket(
                            isVideo = isVideo,
                            data = copy,
                            offset = 0,
                            size = info.size,
                            presentationTimeUs = info.presentationTimeUs,
                            flags = info.flags
                        )
                    )
                }
                return
            }
            val trackIdx = if (isVideo) videoTrackIndex else audioTrackIndex
            if (trackIdx >= 0) {
                try {
                    muxer?.writeSampleData(trackIdx, buffer, info)
                } catch (e: Exception) {
                    Log.w(TAG, "muxer writeSampleData warning: ${e.message}")
                }
            }
        }
    }

    private fun cleanupResources() {
        if (usingExternalMicEngine) {
            RealtimeMicEngine.getInstance().audioFrameConsumer = null
        }

        try { fallbackAec?.release() } catch (_: Exception) {}
        fallbackAec = null
        try { fallbackNs?.release() } catch (_: Exception) {}
        fallbackNs = null
        try {
            fallbackAudioRecord?.stop()
            fallbackAudioRecord?.release()
        } catch (_: Exception) {}
        fallbackAudioRecord = null

        try {
            videoEncoder?.stop()
            videoEncoder?.release()
        } catch (_: Exception) {}
        videoEncoder = null

        try {
            audioEncoder?.stop()
            audioEncoder?.release()
        } catch (_: Exception) {}
        audioEncoder = null

        try {
            inputSurface?.release()
        } catch (_: Exception) {}
        inputSurface = null

        synchronized(muxerLock) {
            try {
                if (muxerStarted) {
                    muxer?.stop()
                }
                muxer?.release()
            } catch (_: Exception) {}
            muxer = null
            muxerStarted = false
            pendingPackets.clear()
        }
    }
}
