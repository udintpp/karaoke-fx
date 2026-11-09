package com.karaokefx.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Shader
import android.hardware.SensorManager
import android.media.MediaMetadataRetriever
import android.media.MediaPlayer
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.util.Size
import android.view.OrientationEventListener
import android.view.Surface
import androidx.annotation.OptIn
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.FocusMeteringAction
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.core.SurfaceOrientedMeteringPointFactory
import androidx.camera.core.resolutionselector.AspectRatioStrategy
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.exifinterface.media.ExifInterface
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import com.google.common.util.concurrent.ListenableFuture
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.segmentation.Segmentation
import com.google.mlkit.vision.segmentation.Segmenter
import com.google.mlkit.vision.segmentation.selfie.SelfieSegmenterOptions
import io.flutter.FlutterInjector
import io.flutter.view.TextureRegistry
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.max

/**
 * Native CameraX + Google ML Kit Selfie Segmentation + OpenGL ES Video Background Remover Engine.
 * - Truly isolates the human/person object from camera background pixel-by-pixel via ML Kit.
 * - Replaces removed background with chosen Image OR Video media (built-in presets or gallery files).
 * - Keeps continuous autofocus & metering locked onto the person object.
 * - Renders to Flutter TextureRegistry for 60 FPS preview AND records composited MP4 via MediaCodec+MediaMuxer.
 */
class CameraBgRemoverEngine(
    private val context: Context,
    private val textureRegistry: TextureRegistry
) {
    companion object {
        private const val TAG = "CameraBgRemoverEngine"
        private const val OUTPUT_WIDTH = 720
        private const val OUTPUT_HEIGHT = 960
    }

    private class CameraLifecycleOwner : LifecycleOwner {
        private val registry = LifecycleRegistry(this)
        private val mainHandler = Handler(Looper.getMainLooper())

        override val lifecycle: Lifecycle
            get() = registry

        fun moveToState(state: Lifecycle.State) {
            if (Looper.myLooper() == Looper.getMainLooper()) {
                registry.currentState = state
            } else {
                mainHandler.post { registry.currentState = state }
            }
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val cameraExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val bgLoaderExecutor: ExecutorService = Executors.newSingleThreadExecutor()

    private var lifecycleOwner: CameraLifecycleOwner? = null
    private var cameraProvider: ProcessCameraProvider? = null
    private var boundCamera: Camera? = null

    private var previewEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var previewTargetSurface: Surface? = null
    private var renderer: CameraGlRenderer? = null

    private var segmenter: Segmenter? = null
    private val isSegmenting = AtomicBoolean(false)

    // Pre-allocated mask buffers to prevent GC pauses during streaming segmentation
    private var prevFloatMask: FloatArray? = null
    private var maskByteArray: ByteArray? = null
    private var prevMaskW = 0
    private var prevMaskH = 0

    // Background video player (muted, looping onto GL SurfaceTexture)
    private var bgMediaPlayer: MediaPlayer? = null
    private var bgVideoSurface: Surface? = null

    // Composited MP4 recorder
    private var mp4Recorder: CompositedMp4Recorder? = null

    // Auto-rotation tracking via hardware orientation sensor
    private var previewUseCase: Preview? = null
    private var imageAnalysisUseCase: ImageAnalysis? = null
    private var orientationEventListener: OrientationEventListener? = null
    private var currentDeviceRotation = Surface.ROTATION_0

    var useFrontCamera: Boolean = true
        private set
    var isFlashOn: Boolean = false
        private set
    var hasMultipleCameras: Boolean = false
        private set
    var isInitialized: Boolean = false
        private set

    fun initialize(
        preferFront: Boolean = true,
        onSuccess: (Map<String, Any>) -> Unit,
        onError: (String) -> Unit
    ) {
        if (isInitialized && previewEntry != null) {
            onSuccess(
                mapOf(
                    "textureId" to previewEntry!!.id(),
                    "width" to OUTPUT_WIDTH,
                    "height" to OUTPUT_HEIGHT,
                    "hasMultipleCameras" to hasMultipleCameras,
                    "isFrontCamera" to useFrontCamera
                )
            )
            return
        }

        useFrontCamera = preferFront
        isFlashOn = false

        try {
            // 1. Initialize ML Kit Bundled Selfie Segmenter (Stream mode + raw size mask for 30fps speed)
            if (segmenter == null) {
                val options = SelfieSegmenterOptions.Builder()
                    .setDetectorMode(SelfieSegmenterOptions.STREAM_MODE)
                    .enableRawSizeMask()
                    .build()
                segmenter = Segmentation.getClient(options)
            }

            // 2. Allocate Flutter TextureRegistry surface
            val entry = textureRegistry.createSurfaceTexture()
            entry.surfaceTexture().setDefaultBufferSize(OUTPUT_WIDTH, OUTPUT_HEIGHT)
            val targetSurf = Surface(entry.surfaceTexture())
            previewEntry = entry
            previewTargetSurface = targetSurf

            // 3. Start OpenGL Compositor Renderer
            val glRenderer = CameraGlRenderer(OUTPUT_WIDTH, OUTPUT_HEIGHT)
            renderer = glRenderer
            glRenderer.isFrontCamera = useFrontCamera

            glRenderer.start(targetSurf) { cameraInputSurface ->
                mainHandler.post {
                    startCameraX(
                        cameraInputSurface = cameraInputSurface,
                        onBound = {
                            isInitialized = true
                            onSuccess(
                                mapOf(
                                    "textureId" to entry.id(),
                                    "width" to OUTPUT_WIDTH,
                                    "height" to OUTPUT_HEIGHT,
                                    "hasMultipleCameras" to hasMultipleCameras,
                                    "isFrontCamera" to useFrontCamera
                                )
                            )
                        },
                        onFail = { err ->
                            onError(err)
                        }
                    )
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Initialize error: ${e.message}", e)
            onError(e.message ?: "Gagal inisialisasi kamera")
        }
    }

    @OptIn(ExperimentalGetImage::class)
    private fun startCameraX(
        cameraInputSurface: Surface,
        onBound: () -> Unit,
        onFail: (String) -> Unit
    ) {
        val providerFuture = ProcessCameraProvider.getInstance(context)
        providerFuture.addListener({
            try {
                val provider = providerFuture.get()
                cameraProvider = provider

                val hasFront = provider.hasCamera(CameraSelector.DEFAULT_FRONT_CAMERA)
                val hasBack = provider.hasCamera(CameraSelector.DEFAULT_BACK_CAMERA)
                hasMultipleCameras = hasFront && hasBack

                if (useFrontCamera && !hasFront && hasBack) {
                    useFrontCamera = false
                } else if (!useFrontCamera && !hasBack && hasFront) {
                    useFrontCamera = true
                }
                renderer?.isFrontCamera = useFrontCamera

                val selector = if (useFrontCamera) {
                    CameraSelector.DEFAULT_FRONT_CAMERA
                } else {
                    CameraSelector.DEFAULT_BACK_CAMERA
                }

                val resolutionSelector = ResolutionSelector.Builder()
                    .setAspectRatioStrategy(AspectRatioStrategy.RATIO_4_3_FALLBACK_AUTO_STRATEGY)
                    .setResolutionStrategy(
                        ResolutionStrategy(
                            Size(960, 720),
                            ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER
                        )
                    )
                    .build()

                val preview = Preview.Builder()
                    .setResolutionSelector(resolutionSelector)
                    .setTargetRotation(currentDeviceRotation)
                    .build()
                previewUseCase = preview

                preview.setSurfaceProvider(ContextCompat.getMainExecutor(context)) { surfaceRequest ->
                    val res = surfaceRequest.resolution
                    renderer?.postOnGlThread {
                        renderer?.cameraSurfaceTexture?.setDefaultBufferSize(res.width, res.height)
                    }
                    surfaceRequest.setTransformationInfoListener(cameraExecutor) { info ->
                        val rot = info.rotationDegrees
                        renderer?.rotationDegrees = rot
                        if (rot == 90 || rot == 270) {
                            renderer?.camPortraitW = res.height
                            renderer?.camPortraitH = res.width
                        } else {
                            renderer?.camPortraitW = res.width
                            renderer?.camPortraitH = res.height
                        }
                    }
                    surfaceRequest.provideSurface(cameraInputSurface, cameraExecutor) { _ ->
                        // Managed cleanly on engine dispose
                    }
                }

                val imageAnalysis = ImageAnalysis.Builder()
                    .setResolutionSelector(resolutionSelector)
                    .setTargetRotation(currentDeviceRotation)
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .build()
                imageAnalysisUseCase = imageAnalysis

                imageAnalysis.setAnalyzer(cameraExecutor) { imageProxy ->
                    val currentCutout = renderer?.cutoutMode ?: 1
                    // Only run ML Kit segmentation when AI Cutout (1) or AI Bokeh Blur (2) is selected
                    if (currentCutout != 1 && currentCutout != 2) {
                        imageProxy.close()
                        return@setAnalyzer
                    }

                    if (!isSegmenting.compareAndSet(false, true)) {
                        imageProxy.close()
                        return@setAnalyzer
                    }

                    val mediaImage = imageProxy.image
                    val seg = segmenter
                    if (mediaImage == null || seg == null) {
                        imageProxy.close()
                        isSegmenting.set(false)
                        return@setAnalyzer
                    }

                    val rot = imageProxy.imageInfo.rotationDegrees
                    if (rot == 90 || rot == 270) {
                        renderer?.analysisPortraitW = imageProxy.height
                        renderer?.analysisPortraitH = imageProxy.width
                    } else {
                        renderer?.analysisPortraitW = imageProxy.width
                        renderer?.analysisPortraitH = imageProxy.height
                    }

                    try {
                        val inputImage = InputImage.fromMediaImage(mediaImage, rot)
                        seg.process(inputImage)
                            .addOnSuccessListener { mask ->
                                try {
                                    val w = mask.width
                                    val h = mask.height
                                    val buf = mask.buffer
                                    buf.rewind()
                                    val count = w * h

                                    if (prevMaskW != w || prevMaskH != h || prevFloatMask == null || prevFloatMask!!.size != count) {
                                        prevFloatMask = FloatArray(count)
                                        maskByteArray = ByteArray(count)
                                        prevMaskW = w
                                        prevMaskH = h
                                        val cache = prevFloatMask!!
                                        val outBytes = maskByteArray!!
                                        for (i in 0 until count) {
                                            val conf = buf.float.coerceIn(0.0f, 1.0f)
                                            cache[i] = conf
                                            outBytes[i] = (conf * 255.0f + 0.5f).toInt().coerceIn(0, 255).toByte()
                                        }
                                    } else {
                                        val cache = prevFloatMask!!
                                        val outBytes = maskByteArray!!
                                        for (i in 0 until count) {
                                            val raw = buf.float.coerceIn(0.0f, 1.0f)
                                            // Smooth temporal blend removes edge flicker while keeping rapid hand movement crisp
                                            val smoothed = cache[i] * 0.25f + raw * 0.75f
                                            cache[i] = smoothed
                                            outBytes[i] = (smoothed * 255.0f + 0.5f).toInt().coerceIn(0, 255).toByte()
                                        }
                                    }

                                    maskByteArray?.let { bytes ->
                                        renderer?.updateMask(bytes, w, h)
                                    }
                                } catch (e: Exception) {
                                    Log.w(TAG, "Mask conversion warning: ${e.message}")
                                }
                            }
                            .addOnFailureListener { e ->
                                Log.w(TAG, "Segmentation failure: ${e.message}")
                            }
                            .addOnCompleteListener {
                                imageProxy.close()
                                isSegmenting.set(false)
                            }
                    } catch (e: Exception) {
                        Log.e(TAG, "Segmentation invocation error: ${e.message}", e)
                        imageProxy.close()
                        isSegmenting.set(false)
                    }
                }

                if (lifecycleOwner == null) {
                    lifecycleOwner = CameraLifecycleOwner()
                }
                val owner = lifecycleOwner!!
                owner.moveToState(Lifecycle.State.CREATED)

                provider.unbindAll()
                boundCamera = provider.bindToLifecycle(owner, selector, preview, imageAnalysis)
                owner.moveToState(Lifecycle.State.RESUMED)
                isFlashOn = false

                // Lock continuous focus & exposure toward upper-center where person/face is framed
                tapToFocus(0.5f, 0.42f)

                setupOrientationEventListener()

                onBound()
            } catch (e: Exception) {
                Log.e(TAG, "CameraX bind failed: ${e.message}", e)
                onFail(e.message ?: "Gagal membuka kamera")
            }
        }, ContextCompat.getMainExecutor(context))
    }

    var onOrientationChanged: ((Int, Boolean) -> Unit)? = null

    private fun setupOrientationEventListener() {
        if (orientationEventListener != null) return
        try {
            orientationEventListener = object : OrientationEventListener(context, SensorManager.SENSOR_DELAY_UI) {
                override fun onOrientationChanged(orientation: Int) {
                    if (orientation == ORIENTATION_UNKNOWN) return

                    // Map accelerometer degrees (0..359) to Surface.ROTATION constants
                    val newRotation = when (orientation) {
                        in 45 until 135 -> Surface.ROTATION_270
                        in 135 until 225 -> Surface.ROTATION_180
                        in 225 until 315 -> Surface.ROTATION_90
                        else -> Surface.ROTATION_0
                    }

                    if (newRotation != currentDeviceRotation) {
                        currentDeviceRotation = newRotation
                        val sensorDeg = when (newRotation) {
                            Surface.ROTATION_90 -> 90
                            Surface.ROTATION_180 -> 180
                            Surface.ROTATION_270 -> 270
                            else -> 0
                        }
                        val isLandscape = (sensorDeg == 90 || sensorDeg == 270)
                        val outW = if (isLandscape) 960 else 720
                        val outH = if (isLandscape) 720 else 960

                        renderer?.deviceRotationDegrees = sensorDeg
                        renderer?.outputWidth = outW
                        renderer?.outputHeight = outH
                        previewEntry?.surfaceTexture()?.setDefaultBufferSize(outW, outH)

                        mainHandler.post {
                            try {
                                previewUseCase?.targetRotation = newRotation
                                imageAnalysisUseCase?.targetRotation = newRotation
                            } catch (e: Exception) {
                                Log.d(TAG, "Update targetRotation error: ${e.message}")
                            }
                            onOrientationChanged?.invoke(sensorDeg, isLandscape)
                        }
                    }
                }
            }.apply {
                if (canDetectOrientation()) {
                    enable()
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to initialize OrientationEventListener: ${e.message}")
        }
    }

    fun switchCamera(onDone: (Boolean) -> Unit, onError: (String) -> Unit) {
        if (!isInitialized || renderer == null || cameraProvider == null) {
            onError("Kamera belum siap")
            return
        }
        useFrontCamera = !useFrontCamera
        renderer?.isFrontCamera = useFrontCamera
        startCameraXWithExistingRenderer(
            onBound = { onDone(useFrontCamera) },
            onFail = onError
        )
    }

    private fun startCameraXWithExistingRenderer(onBound: () -> Unit, onFail: (String) -> Unit) {
        val camSurf = renderer?.cameraSurface
        if (camSurf == null) {
            onFail("Surface kamera tidak tersedia")
            return
        }
        mainHandler.post {
            startCameraX(
                cameraInputSurface = camSurf,
                onBound = onBound,
                onFail = onFail
            )
        }
    }

    fun setFlash(enabled: Boolean): Boolean {
        val cam = boundCamera ?: return false
        return try {
            if (cam.cameraInfo.hasFlashUnit()) {
                cam.cameraControl.enableTorch(enabled)
                isFlashOn = enabled
                enabled
            } else {
                isFlashOn = false
                false
            }
        } catch (_: Exception) {
            isFlashOn = false
            false
        }
    }

    fun tapToFocus(nx: Float, ny: Float) {
        val cam = boundCamera ?: return
        try {
            val factory = SurfaceOrientedMeteringPointFactory(1.0f, 1.0f)
            val point = factory.createPoint(nx.coerceIn(0.05f, 0.95f), ny.coerceIn(0.05f, 0.95f))
            val action = FocusMeteringAction.Builder(
                point,
                FocusMeteringAction.FLAG_AF or FocusMeteringAction.FLAG_AE or FocusMeteringAction.FLAG_AWB
            )
                .setAutoCancelDuration(6, TimeUnit.SECONDS)
                .build()
            if (cam.cameraInfo.isFocusMeteringSupported(action)) {
                cam.cameraControl.startFocusAndMetering(action)
            }
        } catch (e: Exception) {
            Log.d(TAG, "Focus metering skipped: ${e.message}")
        }
    }

    fun setCutoutMode(modeName: String, sensitivity: Float) {
        val code = when (modeName) {
            "none" -> 0
            "aiCutout", "aiPersonCutout" -> 1
            "aiBlur", "aiBlurBackground" -> 2
            "greenScreen" -> 3
            "blueScreen" -> 4
            else -> 1
        }
        renderer?.cutoutMode = code
        renderer?.sensitivity = sensitivity.coerceIn(0.05f, 1.0f)
    }

    fun setColorFilter(matrixList: List<Double>?, isBeauty: Boolean) {
        val arr = if (matrixList != null && matrixList.size >= 20) {
            FloatArray(20) { matrixList[it].toFloat() }
        } else {
            null
        }
        renderer?.setColorFilter(arr, isBeauty)
    }

    fun setBackdropMedia(
        mediaType: String,
        sourceKind: String,
        pathOrKey: String,
        motionType: String,
        gradientColors: List<Int>
    ) {
        renderer?.motionMode = when (motionType) {
            "concertBeams" -> 1
            "neonPulse" -> 2
            "galaxyStars" -> 3
            else -> 0
        }

        if (mediaType == "video" && pathOrKey.isNotEmpty()) {
            startBgVideoPlayback(pathOrKey)
            return
        }

        stopBgVideoPlayback()

        bgLoaderExecutor.execute {
            try {
                var bmp: Bitmap? = null
                if (mediaType == "none") {
                    bmp = createGradientBitmap(listOf(0xFF141422.toInt(), 0xFF0A0A14.toInt()))
                } else if (sourceKind == "asset" && pathOrKey.isNotEmpty()) {
                    bmp = loadFlutterAssetBitmap(pathOrKey)
                } else if (sourceKind == "file" && pathOrKey.isNotEmpty()) {
                    bmp = loadGalleryFileBitmapWithExif(pathOrKey)
                }

                if (bmp == null) {
                    val cols = if (gradientColors.size >= 2) gradientColors else listOf(0xFF2A0845.toInt(), 0xFF6441A5.toInt())
                    bmp = createGradientBitmap(cols)
                }
                renderer?.setBackdropImage(bmp)
            } catch (e: Exception) {
                Log.w(TAG, "Backdrop load error: ${e.message}")
            }
        }
    }

    private fun startBgVideoPlayback(filePath: String) {
        stopBgVideoPlayback()
        val st = renderer?.bgVideoSurfaceTexture ?: return

        var detectedRotation = 0
        try {
            val retriever = MediaMetadataRetriever()
            retriever.setDataSource(filePath)
            val rotStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
            detectedRotation = rotStr?.toIntOrNull() ?: 0
            retriever.release()
        } catch (e: Exception) {
            Log.d(TAG, "Metadata rotation read skipped: ${e.message}")
        }

        try {
            val surf = Surface(st)
            bgVideoSurface = surf
            val mp = MediaPlayer().apply {
                setDataSource(filePath)
                setSurface(surf)
                isLooping = true
                setVolume(0f, 0f) // Muted so Karaoke music + mic vocal remain clear
                setOnVideoSizeChangedListener { _, width, height ->
                    renderer?.setBackdropVideoDimensions(width, height, detectedRotation)
                }
                setOnPreparedListener { player ->
                    val w = if (player.videoWidth > 0) player.videoWidth else 720
                    val h = if (player.videoHeight > 0) player.videoHeight else 960
                    renderer?.setBackdropVideoActive(true, w, h, detectedRotation)
                    player.start()
                }
                setOnErrorListener { _, what, extra ->
                    Log.e(TAG, "Background Video MediaPlayer error: $what/$extra")
                    renderer?.setBackdropVideoActive(false)
                    true
                }
                prepareAsync()
            }
            bgMediaPlayer = mp
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start background video: ${e.message}", e)
            renderer?.setBackdropVideoActive(false)
        }
    }

    private fun stopBgVideoPlayback() {
        renderer?.setBackdropVideoActive(false)
        try {
            bgMediaPlayer?.stop()
        } catch (_: Exception) {}
        try {
            bgMediaPlayer?.release()
        } catch (_: Exception) {}
        bgMediaPlayer = null
        try {
            bgVideoSurface?.release()
        } catch (_: Exception) {}
        bgVideoSurface = null
    }

    private fun loadFlutterAssetBitmap(assetPath: String): Bitmap? {
        return try {
            val lookupKey = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(assetPath)
            context.assets.open(lookupKey).use { input ->
                BitmapFactory.decodeStream(input)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Could not load asset bitmap $assetPath: ${e.message}")
            null
        }
    }

    private fun loadGalleryFileBitmapWithExif(filePath: String): Bitmap? {
        val file = File(filePath)
        if (!file.exists()) return null

        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(filePath, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

        var inSampleSize = 1
        while (bounds.outWidth / inSampleSize > 1440 || bounds.outHeight / inSampleSize > 1440) {
            inSampleSize *= 2
        }

        val decodeOpts = BitmapFactory.Options().apply { this.inSampleSize = inSampleSize }
        val decoded = BitmapFactory.decodeFile(filePath, decodeOpts) ?: return null

        return try {
            val exif = ExifInterface(filePath)
            val orientation = exif.getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
            val matrix = Matrix()
            when (orientation) {
                ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
                ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
                ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
                ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.postScale(-1f, 1f)
                ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.postScale(1f, -1f)
                else -> return decoded
            }
            val rotated = Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, matrix, true)
            if (rotated != decoded) decoded.recycle()
            rotated
        } catch (_: Exception) {
            decoded
        }
    }

    private fun createGradientBitmap(colors: List<Int>): Bitmap {
        val w = 360
        val h = 480
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val colorArr = colors.toIntArray()
        val paint = Paint().apply {
            shader = LinearGradient(
                0f, 0f, w.toFloat(), h.toFloat(),
                colorArr, null, Shader.TileMode.CLAMP
            )
        }
        canvas.drawRect(0f, 0f, w.toFloat(), h.toFloat(), paint)
        return bmp
    }

    fun startVideoRecording(outputPath: String): Boolean {
        val gl = renderer ?: return false
        if (mp4Recorder?.isRecording == true) return true

        val isLandscape = (gl.deviceRotationDegrees == 90 || gl.deviceRotationDegrees == 270)
        val recW = if (isLandscape) 960 else 720
        val recH = if (isLandscape) 720 else 960

        val recorder = CompositedMp4Recorder()
        val surface = recorder.start(outputPath, recW, recH) ?: return false
        mp4Recorder = recorder
        gl.attachRecorderSurface(recorder, surface, recW, recH)
        return true
    }

    fun stopVideoRecording(): String? {
        val rec = mp4Recorder ?: return null
        val gl = renderer

        // CRITICAL: Detach EGL encoder surface FIRST so GL stops swapping frames before signalEndOfInputStream()
        if (gl != null) {
            val latch = CountDownLatch(1)
            gl.detachRecorderSurface { latch.countDown() }
            try {
                latch.await(1200, TimeUnit.MILLISECONDS)
            } catch (_: Exception) {}
        }

        val path = rec.stop()
        mp4Recorder = null
        return path
    }

    fun release() {
        if (mp4Recorder?.isRecording == true) {
            stopVideoRecording()
        }
        stopBgVideoPlayback()

        try {
            orientationEventListener?.disable()
            orientationEventListener = null
        } catch (_: Exception) {}
        previewUseCase = null
        imageAnalysisUseCase = null

        mainHandler.post {
            try {
                lifecycleOwner?.moveToState(Lifecycle.State.DESTROYED)
                cameraProvider?.unbindAll()
            } catch (_: Exception) {}
            boundCamera = null
            lifecycleOwner = null
        }

        renderer?.release()
        renderer = null

        try {
            segmenter?.close()
        } catch (_: Exception) {}
        segmenter = null

        try {
            previewTargetSurface?.release()
        } catch (_: Exception) {}
        previewTargetSurface = null

        try {
            previewEntry?.release()
        } catch (_: Exception) {}
        previewEntry = null

        prevFloatMask = null
        maskByteArray = null
        isInitialized = false
    }
}
