package com.karaokefx.app

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaRecorder
import android.media.audiofx.AcousticEchoCanceler
import android.media.audiofx.NoiseSuppressor
import android.os.Process
import android.util.Log
import kotlin.math.abs
import kotlin.math.log10
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin

/**
 * High-performance, ultra-low latency real-time microphone pass-through engine with
 * hardware echo cancellation, software DSP effects (Gain, Noise Gate, 3-Band EQ,
 * Echo/Delay, Schroeder Reverb, Compressor, and Soft-Knee Limiter).
 */
class RealtimeMicEngine private constructor() {

    companion object {
        private const val TAG = "RealtimeMicEngine"
        private const val SAMPLE_RATE = 44100
        private const val CHUNK_SIZE = 512 // 512 frames (~11.6ms) - optimal & stable low-latency without buffer underrun/crackling

        @Volatile
        private var instance: RealtimeMicEngine? = null

        fun getInstance(): RealtimeMicEngine {
            return instance ?: synchronized(this) {
                instance ?: RealtimeMicEngine().also { instance = it }
            }
        }
    }

    private var audioRecord: AudioRecord? = null
    private var audioTrack: AudioTrack? = null
    private var echoCanceler: AcousticEchoCanceler? = null
    private var noiseSuppressor: NoiseSuppressor? = null

    private var workerThread: Thread? = null
    @Volatile
    private var isRunning = false

    // ─── DSP Control Parameters (Thread-safe) ─────────────────────────────
    @Volatile var isEnabled: Boolean = true
    @Volatile var inputGain: Float = 1.2f

    // Noise Gate
    @Volatile var noiseGateEnabled: Boolean = false
    @Volatile var noiseGateThresholdDb: Float = -45.0f

    // 3-Band EQ
    @Volatile var eqEnabled: Boolean = false
    @Volatile var eqBassDb: Float = 0.0f
    @Volatile var eqMidDb: Float = 0.0f
    @Volatile var eqTrebleDb: Float = 0.0f

    // Echo / Delay
    @Volatile var echoEnabled: Boolean = false
    @Volatile var echoDelayMs: Float = 250.0f
    @Volatile var echoFeedback: Float = 0.35f
    @Volatile var echoWetMix: Float = 0.4f

    // Reverb
    @Volatile var reverbEnabled: Boolean = false
    @Volatile var reverbRoom: Float = 0.5f
    @Volatile var reverbDamping: Float = 0.5f
    @Volatile var reverbWetMix: Float = 0.35f

    // Compressor
    @Volatile var compressorEnabled: Boolean = false
    @Volatile var compressorThresholdDb: Float = -20.0f
    @Volatile var compressorRatio: Float = 4.0f

    // Pitch / Voice FX
    @Volatile var pitchEnabled: Boolean = false
    @Volatile var pitchSemitones: Float = 0.0f

    // Live VU Meter Output (0.0 to 1.0)
    @Volatile var liveVuLevel: Float = 0.0f
        private set

    // ─── Pre-allocated DSP Buffers (Zero GC allocations in audio loop) ─────
    // Delay buffer: 1 second at 44.1kHz
    private val delayBuffer = FloatArray(44100)
    private var delayWriteIndex = 0

    // Comb filters for Reverb (Schroeder model)
    private val combLengths = intArrayOf(1116, 1188, 1277, 1356)
    private val combBuffers = Array(4) { FloatArray(combLengths[it]) }
    private val combIndices = IntArray(4)

    // All-pass filters for Reverb
    private val allPassLengths = intArrayOf(225, 341)
    private val allPassBuffers = Array(2) { FloatArray(allPassLengths[it]) }
    private val allPassIndices = IntArray(2)

    // Filter states for 3-band EQ
    private var lowState = 0.0f
    private var highState = 0.0f

    // Gate gain smoothing
    private var currentGateGain = 1.0f

    // Pitch / Robot oscillator phase
    private var robotPhase = 0.0

    // AudioManager reference — injected by MainActivity
    var audioManager: AudioManager? = null

    @Synchronized
    fun start(): Boolean {
        if (isRunning) return true

        try {
            // Keep normal audio mode — DO NOT use MODE_IN_COMMUNICATION as it routes audio
            // through Android's slow telephony VoIP HAL which adds 150-250ms delay and mutes mic sensitivity.
            try {
                audioManager?.mode = AudioManager.MODE_NORMAL
            } catch (e: Exception) {
                Log.w(TAG, "Could not set MODE_NORMAL: ${e.message}")
            }

            val minRecBuf = AudioRecord.getMinBufferSize(
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )
            val recBufSize = max(minRecBuf, CHUNK_SIZE * 4)

            // AudioSource.MIC provides pure, clean hardware audio capture
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                recBufSize
            )

            if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                Log.e(TAG, "AudioRecord initialization failed!")
                stop()
                return false
            }

            // Attach hardware AEC / Noise suppressor if supported by device chipset
            val sessionId = audioRecord?.audioSessionId ?: 0
            if (AcousticEchoCanceler.isAvailable()) {
                try {
                    echoCanceler = AcousticEchoCanceler.create(sessionId)
                    echoCanceler?.enabled = true
                } catch (e: Exception) {
                    Log.w(TAG, "Could not enable AcousticEchoCanceler: ${e.message}")
                }
            }

            if (NoiseSuppressor.isAvailable()) {
                try {
                    noiseSuppressor = NoiseSuppressor.create(sessionId)
                    noiseSuppressor?.enabled = true
                } catch (e: Exception) {
                    Log.w(TAG, "Could not enable NoiseSuppressor: ${e.message}")
                }
            }

            val minTrackBuf = AudioTrack.getMinBufferSize(
                SAMPLE_RATE,
                AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )
            val trackBufSize = max(minTrackBuf, CHUNK_SIZE * 4)

            // USAGE_MEDIA routes to standard FastMixer path
            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .build()

            val audioFormat = AudioFormat.Builder()
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .setSampleRate(SAMPLE_RATE)
                .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                .build()

            audioTrack = AudioTrack.Builder()
                .setAudioAttributes(audioAttributes)
                .setAudioFormat(audioFormat)
                .setBufferSizeInBytes(trackBufSize)
                .setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build()

            if (audioTrack?.state != AudioTrack.STATE_INITIALIZED) {
                Log.e(TAG, "AudioTrack initialization failed!")
                stop()
                return false
            }

            audioRecord?.startRecording()
            audioTrack?.play()

            isRunning = true
            currentGateGain = 1.0f

            workerThread = Thread({
                Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO)
                processAudioLoop()
            }, "KaraokeFx-RealtimeMicEngine").apply {
                isDaemon = true
                start()
            }

            Log.i(TAG, "RealtimeMicEngine started (SampleRate: $SAMPLE_RATE, Chunk: $CHUNK_SIZE)")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error starting RealtimeMicEngine: ${e.message}", e)
            stop()
            return false
        }
    }

    @Synchronized
    fun stop() {
        isRunning = false
        try {
            workerThread?.interrupt()
            workerThread = null
        } catch (_: Exception) {}

        try {
            echoCanceler?.release()
            echoCanceler = null
        } catch (_: Exception) {}

        try {
            noiseSuppressor?.release()
            noiseSuppressor = null
        } catch (_: Exception) {}

        try {
            audioRecord?.stop()
            audioRecord?.release()
            audioRecord = null
        } catch (_: Exception) {}

        try {
            audioTrack?.stop()
            audioTrack?.release()
            audioTrack = null
        } catch (_: Exception) {}

        liveVuLevel = 0.0f
        Log.i(TAG, "RealtimeMicEngine stopped")
    }

    fun isLive(): Boolean = isRunning

    fun updateSettings(map: Map<String, Any?>) {
        (map["isEnabled"] as? Boolean)?.let { isEnabled = it }
        (map["inputGain"] as? Number)?.let { inputGain = it.toFloat().coerceIn(0f, 5.0f) }

        // Echo
        (map["echoEnabled"] as? Boolean)?.let { echoEnabled = it }
        (map["echoDelay"] as? Number)?.let { echoDelayMs = it.toFloat().coerceIn(40f, 1000f) }
        (map["echoFeedback"] as? Number)?.let { echoFeedback = it.toFloat().coerceIn(0f, 0.9f) }
        (map["echoWetMix"] as? Number)?.let { echoWetMix = it.toFloat().coerceIn(0f, 1.0f) }

        // Reverb
        (map["reverbEnabled"] as? Boolean)?.let { reverbEnabled = it }
        (map["reverbRoom"] as? Number)?.let { reverbRoom = it.toFloat().coerceIn(0f, 1.0f) }
        (map["reverbDamping"] as? Number)?.let { reverbDamping = it.toFloat().coerceIn(0f, 1.0f) }
        (map["reverbWetMix"] as? Number)?.let { reverbWetMix = it.toFloat().coerceIn(0f, 1.0f) }

        // EQ
        (map["eqEnabled"] as? Boolean)?.let { eqEnabled = it }
        (map["eqBass"] as? Number)?.let { eqBassDb = it.toFloat().coerceIn(-12f, 12f) }
        (map["eqMid"] as? Number)?.let { eqMidDb = it.toFloat().coerceIn(-12f, 12f) }
        (map["eqTreble"] as? Number)?.let { eqTrebleDb = it.toFloat().coerceIn(-12f, 12f) }

        // Noise gate
        (map["noiseGateEnabled"] as? Boolean)?.let { noiseGateEnabled = it }
        (map["noiseGateThreshold"] as? Number)?.let { noiseGateThresholdDb = it.toFloat().coerceIn(-60f, 0f) }

        // Compressor
        (map["compressorEnabled"] as? Boolean)?.let { compressorEnabled = it }
        (map["compressorThreshold"] as? Number)?.let { compressorThresholdDb = it.toFloat().coerceIn(-40f, 0f) }
        (map["compressorRatio"] as? Number)?.let { compressorRatio = it.toFloat().coerceIn(1f, 20f) }

        // Pitch / Voice FX
        (map["pitchEnabled"] as? Boolean)?.let { pitchEnabled = it }
        (map["pitchSemitones"] as? Number)?.let { pitchSemitones = it.toFloat().coerceIn(-12f, 12f) }
    }

    private fun processAudioLoop() {
        val pcmIn = ShortArray(CHUNK_SIZE)
        val pcmOut = ShortArray(CHUNK_SIZE)
        val floatBuf = FloatArray(CHUNK_SIZE)

        while (isRunning) {
            val record = audioRecord ?: break
            val track = audioTrack ?: break

            val readCount = record.read(pcmIn, 0, CHUNK_SIZE)
            if (readCount <= 0) continue

            // 1. Convert Short to Normalized Float [-1.0, 1.0] and compute RMS for VU Meter
            var sumSquare = 0.0f
            for (i in 0 until readCount) {
                val f = pcmIn[i] / 32768.0f
                floatBuf[i] = f
                sumSquare += f * f
            }

            val rms = kotlin.math.sqrt((sumSquare / readCount).toDouble()).toFloat()
            // Highly sensitive & dynamic VU level
            val instantDb = if (rms > 0.000005f) (20.0 * log10(rms.toDouble())).toFloat().coerceIn(-60f, 0f) else -60f
            val rawVu = ((instantDb + 55f) / 55f).coerceIn(0f, 1f)
            liveVuLevel = liveVuLevel * 0.6f + rawVu * 0.4f

            // If mic output is disabled, silence output
            if (!isEnabled) {
                track.write(ShortArray(readCount), 0, readCount)
                continue
            }

            // 2. Noise Gate logic (Clean bypass when disabled)
            if (!noiseGateEnabled) {
                currentGateGain = 1.0f
            } else {
                val gateTarget = if (instantDb >= noiseGateThresholdDb) 1.0f else 0.0f
                val gateSpeed = if (gateTarget > currentGateGain) 0.35f else 0.06f
                currentGateGain += (gateTarget - currentGateGain) * gateSpeed
            }

            // 3. DSP Effects Chain
            val gain = inputGain
            val isEcho = echoEnabled
            val delaySamples = ((echoDelayMs / 1000f) * SAMPLE_RATE).toInt().coerceIn(100, 44000)
            val fb = echoFeedback
            val echoMix = echoWetMix

            val isRev = reverbEnabled
            val revRoom = 0.7f + reverbRoom * 0.25f
            val revDamp = reverbDamping * 0.4f
            val revMix = reverbWetMix

            val isEq = eqEnabled
            val bassGain = if (isEq) 10.0.pow((eqBassDb / 20.0)).toFloat() else 1.0f
            val midGain = if (isEq) 10.0.pow((eqMidDb / 20.0)).toFloat() else 1.0f
            val trebleGain = if (isEq) 10.0.pow((eqTrebleDb / 20.0)).toFloat() else 1.0f

            val isComp = compressorEnabled
            val compThreshLinear = 10.0.pow((compressorThresholdDb / 20.0)).toFloat()
            val compRatio = compressorRatio

            val isPitch = pitchEnabled
            val semitones = pitchSemitones

            for (i in 0 until readCount) {
                var s = floatBuf[i] * gain * currentGateGain

                // EQ Filtering (Low shelf ~300Hz, High shelf ~3500Hz, Mid)
                if (isEq) {
                    lowState += (s - lowState) * 0.042f
                    highState += (s - highState) * 0.45f
                    val lowPart = lowState
                    val highPart = s - highState
                    val midPart = s - lowPart - highPart
                    s = lowPart * bassGain + midPart * midGain + highPart * trebleGain
                }

                // Echo / Delay
                var echoOut = 0.0f
                if (isEcho) {
                    val readIdx = (delayWriteIndex - delaySamples + 44100) % 44100
                    val delayed = delayBuffer[readIdx]
                    delayBuffer[delayWriteIndex] = (s + delayed * fb).coerceIn(-1.5f, 1.5f)
                    delayWriteIndex = (delayWriteIndex + 1) % 44100
                    echoOut = delayed
                }

                // Reverb (Comb + Allpass)
                var revOut = 0.0f
                if (isRev) {
                    var combSum = 0.0f
                    for (c in 0 until 4) {
                        val buf = combBuffers[c]
                        val len = combLengths[c]
                        val idx = combIndices[c]
                        val outSample = buf[idx]
                        combSum += outSample
                        buf[idx] = s + outSample * revRoom * (1.0f - revDamp)
                        combIndices[c] = (idx + 1) % len
                    }

                    // Feed comb output into 2 series all-pass filters
                    var apIn = combSum * 0.25f
                    for (a in 0 until 2) {
                        val buf = allPassBuffers[a]
                        val len = allPassLengths[a]
                        val idx = allPassIndices[a]
                        val bufOut = buf[idx]
                        val apOut = -apIn + bufOut
                        buf[idx] = apIn + bufOut * 0.5f
                        allPassIndices[a] = (idx + 1) % len
                        apIn = apOut
                    }
                    revOut = apIn
                }

                // Mix dry, echo, reverb
                if (isEcho && isRev) {
                    s = s * (1.0f - echoMix * 0.6f - revMix * 0.6f) + echoOut * echoMix + revOut * revMix
                } else if (isEcho) {
                    s = s * (1.0f - echoMix) + echoOut * echoMix
                } else if (isRev) {
                    s = s * (1.0f - revMix) + revOut * revMix
                }

                // Pitch / Voice effect (Robot or High pitch ring-mod)
                if (isPitch) {
                    if (semitones < -2f) { // Robot / Deep
                        val robot = sin(robotPhase).toFloat()
                        robotPhase += (2.0 * Math.PI * 75.0 / SAMPLE_RATE)
                        s = s * 0.45f + s * robot * 0.55f
                    } else if (semitones > 2f) { // Helium / High
                        val helium = sin(robotPhase).toFloat()
                        robotPhase += (2.0 * Math.PI * 180.0 / SAMPLE_RATE)
                        s = s * 0.5f + s * helium * 0.5f
                    }
                }

                // Compressor
                if (isComp) {
                    val absVal = abs(s)
                    if (absVal > compThreshLinear && compThreshLinear > 0.001f) {
                        val overDb = 20.0 * log10((absVal / compThreshLinear).toDouble())
                        val compGain = 10.0.pow(-(overDb * (1.0 - 1.0 / compRatio)) / 20.0).toFloat()
                        s *= compGain
                    }
                }

                // Soft-knee Limiter (prevents digital clipping/harsh buzzing)
                val clamped = s.coerceIn(-1.5f, 1.5f)
                val limited = if (clamped > 0.75f) {
                    0.75f + (clamped - 0.75f) / (1.0f + (clamped - 0.75f) * (clamped - 0.75f))
                } else if (clamped < -0.75f) {
                    -0.75f + (clamped + 0.75f) / (1.0f + (clamped + 0.75f) * (clamped + 0.75f))
                } else {
                    clamped
                }

                pcmOut[i] = (limited.coerceIn(-1.0f, 1.0f) * 32767.0f).toInt().toShort()
            }

            // 4. Output directly to AudioTrack with low latency
            track.write(pcmOut, 0, readCount)
        }
    }
}
