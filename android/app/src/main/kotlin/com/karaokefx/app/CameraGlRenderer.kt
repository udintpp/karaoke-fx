package com.karaokefx.app

import android.graphics.Bitmap
import android.graphics.SurfaceTexture
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLExt
import android.opengl.EGLSurface
import android.opengl.GLES11Ext
import android.opengl.GLES20
import android.opengl.GLUtils
import android.opengl.Matrix
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import android.view.Surface
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import kotlin.math.max

/**
 * High-performance OpenGL ES 2.0 GPU Video Compositor.
 *
 * Pass 1: Decoded Background Video (MediaPlayer SurfaceTexture OES) -> offscreen GL_TEXTURE_2D FBO (with Aspect-Fill crop).
 *         (Avoids multi-samplerExternalOES driver bugs on older Mali/Adreno GPUs).
 * Pass 2: Composites upright Portrait 720x960 stream:
 *         - Camera feed (aspect-fill + orientation + selfie mirroring + optional GPU Bokeh Blur or AI Color/Beauty Filter)
 *         - ML Kit SegmentationMask (5-tap smooth anti-aliased edge feathering + sensitivity cutoff)
 *         - Chroma Key Green/Blue screen with spill suppression
 *         - Replaced Background (Static Gallery/Preset Photo OR Dynamic MP4 Video OR Real-time Motion Stage Lighting)
 *         - Outputs identically to BOTH Flutter Preview EGLSurface AND MediaCodec H.264 Input EGLSurface!
 */
class CameraGlRenderer(
    var outputWidth: Int = 720,
    var outputHeight: Int = 960
) {
    companion object {
        private const val TAG = "CameraGlRenderer"

        // Fullscreen Quad: (X, Y) + Upright UV (U, V) where (0,0)=Top-Left, (1,1)=Bottom-Right
        private val QUAD_VERTICES = floatArrayOf(
            -1.0f,  1.0f,  0.0f, 0.0f, // Top-Left
             1.0f,  1.0f,  1.0f, 0.0f, // Top-Right
            -1.0f, -1.0f,  0.0f, 1.0f, // Bottom-Left
             1.0f, -1.0f,  1.0f, 1.0f  // Bottom-Right
        )

        private const val EGL_RECORDABLE_ANDROID = 0x3142

        // ─── Pass 1 Vertex & Fragment Shader (Bg Video OES -> FBO) ──────────
        private const val PASS1_VERT = """
            attribute vec2 aPosition;
            attribute vec2 aUprightUv;
            uniform mat4 uBgVideoMatrix;
            uniform vec2 uBgVideoCropScale;
            uniform int uBgVideoRotation;
            varying vec2 vBgTexCoord;
            void main() {
                gl_Position = vec4(aPosition, 0.0, 1.0);
                // Center-crop to 3:4 portrait aspect ratio
                vec2 cropped = (aUprightUv - vec2(0.5)) * uBgVideoCropScale + vec2(0.5);
                vec2 rawUv = cropped;
                if (uBgVideoRotation == 90) {
                    rawUv = vec2(cropped.y, 1.0 - cropped.x);
                } else if (uBgVideoRotation == 180) {
                    rawUv = vec2(1.0 - cropped.x, 1.0 - cropped.y);
                } else if (uBgVideoRotation == 270) {
                    rawUv = vec2(1.0 - cropped.y, cropped.x);
                }
                // Convert Top-Left (0,0) -> Bottom-Left GL (0,0) for SurfaceTexture matrix
                vec4 glUv = vec4(rawUv.x, 1.0 - rawUv.y, 0.0, 1.0);
                // NOTE: Because FBO t=0 maps to gl_Position.y=-1, flipping output Y in gl_Position aligns FBO t=0 with video TOP!
                gl_Position.y = -gl_Position.y;
                vBgTexCoord = (uBgVideoMatrix * glUv).xy;
            }
        """

        private const val PASS1_FRAG = """
            #extension GL_OES_EGL_image_external : require
            precision mediump float;
            uniform samplerExternalOES uBgVideoTex;
            varying vec2 vBgTexCoord;
            void main() {
                gl_FragColor = texture2D(uBgVideoTex, clamp(vBgTexCoord, 0.001, 0.999));
            }
        """

        // ─── Pass 2 Vertex & Fragment Shader (Main AI Cutout Compositor) ────
        private const val MAIN_VERT = """
            attribute vec2 aPosition;
            attribute vec2 aUprightUv;
            varying vec2 vUprightUv;
            void main() {
                gl_Position = vec4(aPosition, 0.0, 1.0);
                vUprightUv = aUprightUv;
            }
        """

        private const val MAIN_FRAG = """
            #extension GL_OES_EGL_image_external : require
            precision mediump float;

            uniform samplerExternalOES uCameraTex;
            uniform sampler2D uMaskTex;
            uniform sampler2D uBgTex;

            uniform mat4 uStMatrix;
            uniform int uRotationDegrees;
            uniform int uDeviceRotation;
            uniform float uIsFrontCamera;
            uniform vec2 uCamCropScale;
            uniform vec2 uMaskCropScale;
            uniform vec2 uBgCropScale;
            uniform vec2 uMaskTexel;
            uniform int uHasMask;

            // Cutout Modes:
            // 0 = none (kamera penuh)
            // 1 = aiCutout (hapus background, ganti gambar/video, fokus orang)
            // 2 = aiBlur (blur bokeh latar, fokus tajam ke orang)
            // 3 = greenScreen
            // 4 = blueScreen
            uniform int uCutoutMode;
            uniform float uSensitivity;

            // Backdrop source mode:
            // 0 = solid dark fallback
            // 1 = static image / preset (uses uBgCropScale)
            // 2 = video FBO (already cropped 1:1 in Pass 1!)
            uniform int uHasBgTex;
            uniform int uBgIsVideoFbo;
            uniform int uMotionMode; // 0=none, 1=concertBeams, 2=neonPulse, 3=galaxyStars
            uniform float uTime;

            // AI Color Filter (4x4 RGB/Alpha matrix + normalized offset)
            uniform int uHasColorFilter;
            uniform mat4 uColorMat;
            uniform vec4 uColorOffset;
            uniform float uBeautyStrength;

            varying vec2 vUprightUv;

            vec2 rotateScreenUvToPortrait(vec2 uv, int devRot) {
                vec2 c = clamp(uv, 0.001, 0.999);
                if (devRot == 90) {
                    return vec2(1.0 - c.y, c.x);
                } else if (devRot == 180) {
                    return vec2(1.0 - c.x, 1.0 - c.y);
                } else if (devRot == 270) {
                    return vec2(c.y, 1.0 - c.x);
                }
                return c;
            }

            vec2 uprightToCameraOes(vec2 uprightMirroredUv) {
                vec2 c = clamp(uprightMirroredUv, 0.002, 0.998);
                // Convert Top-Left (0,0) -> Bottom-Left GL (0,0) for SurfaceTexture matrix
                vec4 glUv = vec4(c.x, 1.0 - c.y, 0.0, 1.0);
                return clamp((uStMatrix * glUv).xy, 0.001, 0.999);
            }

            vec3 applyColorFilter(vec3 rgb) {
                vec3 res = rgb;
                if (uBeautyStrength > 0.01) {
                    // Subtle warm luminous soft glow enhancement for skin/face
                    vec3 smoothGlow = pow(res, vec3(0.92));
                    res = mix(res, smoothGlow, uBeautyStrength * 0.45);
                }
                if (uHasColorFilter == 1) {
                    vec4 transformed = uColorMat * vec4(res, 1.0) + uColorOffset;
                    res = clamp(transformed.rgb, 0.0, 1.0);
                }
                return res;
            }

            vec3 computeMotionOverlay(vec2 uv, vec3 baseBg) {
                if (uMotionMode == 1) {
                    // Dynamic sweeping concert stage spotlights
                    float angle1 = sin(uTime * 1.1) * 0.35;
                    float beam1 = exp(-abs((uv.x - 0.3) + (uv.y - 0.0) * angle1) * 7.5) * (1.0 - uv.y * 0.7);
                    float angle2 = cos(uTime * 0.85) * 0.35;
                    float beam2 = exp(-abs((uv.x - 0.7) + (uv.y - 0.0) * angle2) * 7.5) * (1.0 - uv.y * 0.7);
                    vec3 spotColor = vec3(0.75, 0.35, 1.0) * beam1 * 0.32 + vec3(0.25, 0.85, 1.0) * beam2 * 0.28;
                    return clamp(baseBg + spotColor, 0.0, 1.0);
                } else if (uMotionMode == 2) {
                    // Pulsing VIP Neon club wave glow
                    float pulse = 0.5 + 0.5 * sin(uTime * 2.4 - uv.y * 4.0);
                    vec3 neonTint = mix(vec3(0.0, 0.85, 1.0), vec3(1.0, 0.15, 0.65), uv.x);
                    return clamp(baseBg + neonTint * (0.06 + 0.10 * pulse) * (1.0 - abs(uv.y - 0.5)), 0.0, 1.0);
                } else if (uMotionMode == 3) {
                    // Cosmic aurora shimmer & subtle sparkle
                    float wave = 0.5 + 0.5 * sin(uv.x * 5.0 + uTime * 1.3 + sin(uv.y * 4.0 - uTime * 0.7));
                    vec3 aurora = vec3(0.1, 0.9, 0.65) * wave * 0.14 * (1.0 - uv.y * 0.5);
                    return clamp(baseBg + aurora, 0.0, 1.0);
                }
                return baseBg;
            }

            void main() {
                vec2 sceneUv = rotateScreenUvToPortrait(vUprightUv, uDeviceRotation);

                // 1. Center-crop portrait UV for Camera & Mask
                vec2 camUpright = (sceneUv - vec2(0.5)) * uCamCropScale + vec2(0.5);
                // Horizontal mirror for front selfie camera
                vec2 camMirrored = vec2(
                    uIsFrontCamera > 0.5 ? (1.0 - camUpright.x) : camUpright.x,
                    camUpright.y
                );

                vec2 camOesUv = uprightToCameraOes(camMirrored);
                vec3 rawCamRgb = texture2D(uCameraTex, camOesUv).rgb;
                vec3 personRgb = applyColorFilter(rawCamRgb);

                // Mode 0: Normal full camera (no cutout)
                if (uCutoutMode == 0) {
                    gl_FragColor = vec4(personRgb, 1.0);
                    return;
                }

                float personAlpha = 1.0;

                if (uCutoutMode == 1 || uCutoutMode == 2) {
                    // AI Person Segmentation Mask (5-tap smooth anti-aliased edge sampling)
                    if (uHasMask == 1) {
                        vec2 maskUpright = (sceneUv - vec2(0.5)) * uMaskCropScale + vec2(0.5);
                        // FIXED: Do NOT invert X for front camera!
                        // Keeps mask movement 100% synchronized with person motion (moving right follows right).
                        vec2 maskCoord = vec2(
                            maskUpright.x,
                            maskUpright.y
                        );
                        vec2 mUv = clamp(maskCoord, 0.002, 0.998);
                        vec2 off = uMaskTexel * 1.35;
                        float m0 = texture2D(uMaskTex, mUv).r;
                        float m1 = texture2D(uMaskTex, clamp(mUv + vec2(-off.x, -off.y), 0.002, 0.998)).r;
                        float m2 = texture2D(uMaskTex, clamp(mUv + vec2( off.x, -off.y), 0.002, 0.998)).r;
                        float m3 = texture2D(uMaskTex, clamp(mUv + vec2(-off.x,  off.y), 0.002, 0.998)).r;
                        float m4 = texture2D(uMaskTex, clamp(mUv + vec2( off.x,  off.y), 0.002, 0.998)).r;
                        float maskConf = m0 * 0.44 + (m1 + m2 + m3 + m4) * 0.14;

                        float thresh = mix(0.26, 0.72, uSensitivity);
                        float edgeSoftness = 0.13;
                        personAlpha = smoothstep(
                            clamp(thresh - edgeSoftness, 0.0, 0.92),
                            clamp(thresh + edgeSoftness, 0.08, 1.0),
                            maskConf
                        );
                    }
                } else if (uCutoutMode == 3) {
                    // Chroma Key Green Screen + Green Spill Suppression
                    float maxRB = max(rawCamRgb.r, rawCamRgb.b);
                    float greenDom = rawCamRgb.g - maxRB;
                    float cutoff = mix(0.32, 0.06, uSensitivity);
                    personAlpha = 1.0 - smoothstep(cutoff * 0.35, cutoff + 0.08, greenDom);
                    if (personAlpha < 0.98) {
                        personRgb.g = min(personRgb.g, max(personRgb.r, personRgb.b) * 1.02 + 0.01);
                    }
                } else if (uCutoutMode == 4) {
                    // Chroma Key Blue Screen + Blue Spill Suppression
                    float maxRG = max(rawCamRgb.r, rawCamRgb.g);
                    float blueDom = rawCamRgb.b - maxRG;
                    float cutoff = mix(0.32, 0.06, uSensitivity);
                    personAlpha = 1.0 - smoothstep(cutoff * 0.35, cutoff + 0.08, blueDom);
                    if (personAlpha < 0.98) {
                        personRgb.b = min(personRgb.b, max(personRgb.r, personRgb.g) * 1.02 + 0.01);
                    }
                }

                // Mode 2: AI Bokeh Blur Background (keeps person razor-sharp & in focus!)
                if (uCutoutMode == 2) {
                    vec3 blurSum = rawCamRgb * 0.2;
                    float r = mix(0.008, 0.026, uSensitivity);
                    blurSum += texture2D(uCameraTex, uprightToCameraOes(camMirrored + vec2(-r, 0.0))).rgb * 0.1;
                    blurSum += texture2D(uCameraTex, uprightToCameraOes(camMirrored + vec2( r, 0.0))).rgb * 0.1;
                    blurSum += texture2D(uCameraTex, uprightToCameraOes(camMirrored + vec2(0.0, -r))).rgb * 0.1;
                    blurSum += texture2D(uCameraTex, uprightToCameraOes(camMirrored + vec2(0.0,  r))).rgb * 0.1;
                    blurSum += texture2D(uCameraTex, uprightToCameraOes(camMirrored + vec2(-r*0.7, -r*0.7))).rgb * 0.1;
                    blurSum += texture2D(uCameraTex, uprightToCameraOes(camMirrored + vec2( r*0.7, -r*0.7))).rgb * 0.1;
                    blurSum += texture2D(uCameraTex, uprightToCameraOes(camMirrored + vec2(-r*0.7,  r*0.7))).rgb * 0.1;
                    blurSum += texture2D(uCameraTex, uprightToCameraOes(camMirrored + vec2( r*0.7,  r*0.7))).rgb * 0.1;
                    vec3 blurredBg = applyColorFilter(blurSum);
                    gl_FragColor = vec4(mix(blurredBg, personRgb, personAlpha), 1.0);
                    return;
                }

                // Mode 1 / 3 / 4: Replace Background with Selected Photo / Video Media
                vec3 bgRgb = vec3(0.08, 0.08, 0.14);
                if (uHasBgTex == 1) {
                    vec2 bgUv = uBgIsVideoFbo == 1
                        ? sceneUv
                        : clamp((sceneUv - vec2(0.5)) * uBgCropScale + vec2(0.5), 0.001, 0.999);
                    bgRgb = texture2D(uBgTex, bgUv).rgb;
                }
                bgRgb = computeMotionOverlay(sceneUv, bgRgb);

                vec3 finalRgb = mix(bgRgb, personRgb, personAlpha);
                gl_FragColor = vec4(finalRgb, 1.0);
            }
        """
    }

    private var glThread: HandlerThread? = null
    private var glHandler: Handler? = null

    private var eglDisplay: EGLDisplay = EGL14.EGL_NO_DISPLAY
    private var eglContext: EGLContext = EGL14.EGL_NO_CONTEXT
    private var eglConfig: EGLConfig? = null

    private var previewEglSurface: EGLSurface = EGL14.EGL_NO_SURFACE
    private var encoderEglSurface: EGLSurface = EGL14.EGL_NO_SURFACE

    // Textures
    private var cameraTexId = 0
    var cameraSurfaceTexture: SurfaceTexture? = null
        private set
    var cameraSurface: Surface? = null
        private set

    private var bgVideoTexId = 0
    var bgVideoSurfaceTexture: SurfaceTexture? = null
        private set
    private var bgVideoSurface: Surface? = null

    private var bgFboId = 0
    private var bgFboTexId = 0
    private var bgImageTexId = 0
    private var maskTexId = 0

    // Shaders
    private var pass1Program = 0
    private var mainProgram = 0
    private val vertexBuffer: FloatBuffer = ByteBuffer
        .allocateDirect(QUAD_VERTICES.size * 4)
        .order(ByteOrder.nativeOrder())
        .asFloatBuffer()
        .apply {
            put(QUAD_VERTICES)
            position(0)
        }

    // Dynamic matrices & frame flags
    private val stMatrix = FloatArray(16).also { Matrix.setIdentityM(it, 0) }
    private val bgVideoMatrix = FloatArray(16).also { Matrix.setIdentityM(it, 0) }

    @Volatile private var cameraFrameAvailable = false
    @Volatile private var bgVideoFrameAvailable = false
    @Volatile private var hasBgVideo = false
    @Volatile private var hasBgImage = false
    @Volatile private var bgImageW = 1
    @Volatile private var bgImageH = 1
    @Volatile private var bgVideoW = 1
    @Volatile private var bgVideoH = 1
    @Volatile private var bgVideoRotationDegrees = 0

    // Pending image & mask transfers
    private val stateLock = Object()
    private var pendingBgBitmap: Bitmap? = null
    private var pendingMaskBuffer: ByteBuffer? = null
    private var pendingMaskW = 0
    private var pendingMaskH = 0
    private var maskDirty = false
    private var maskUploadedOnce = false
    private var uploadedMaskW = 1
    private var uploadedMaskH = 1

    // Camera transform & settings
    @Volatile var rotationDegrees = 0
    @Volatile var deviceRotationDegrees = 0
    @Volatile var isFrontCamera = true
    @Volatile var camPortraitW = 720
    @Volatile var camPortraitH = 960
    @Volatile var analysisPortraitW = 720
    @Volatile var analysisPortraitH = 960

    @Volatile var cutoutMode = 1 // 0=none, 1=aiCutout, 2=aiBlur, 3=greenScreen, 4=blueScreen
    @Volatile var sensitivity = 0.55f
    @Volatile var motionMode = 0 // 0=none, 1=concertBeams, 2=neonPulse, 3=galaxyStars

    private var hasColorFilter = false
    private val colorMat4 = FloatArray(16).also { Matrix.setIdentityM(it, 0) }
    private val colorOffset4 = FloatArray(4)
    private var beautyStrength = 0.0f

    // Video recorder attachment
    private var activeRecorder: CompositedMp4Recorder? = null
    private var lastEncodedPtsNs = 0L
    private var startTimeMs = System.currentTimeMillis()
    private var renderLoopScheduled = false

    @Volatile private var isReleased = false

    fun start(previewTargetSurface: Surface, onReady: (Surface) -> Unit) {
        val thread = HandlerThread("KaraokeGlThread").also { it.start() }
        glThread = thread
        val handler = Handler(thread.looper)
        glHandler = handler

        handler.post {
            try {
                initEgl(previewTargetSurface)
                initGlObjects()
                val camSurf = cameraSurface
                if (camSurf != null) {
                    onReady(camSurf)
                }
                scheduleRenderTick()
            } catch (e: Exception) {
                Log.e(TAG, "GL init error: ${e.message}", e)
            }
        }
    }

    fun postOnGlThread(action: () -> Unit) {
        glHandler?.post(action)
    }

    fun updateMask(bytes: ByteArray, width: Int, height: Int) {
        synchronized(stateLock) {
            if (pendingMaskBuffer == null || pendingMaskBuffer!!.capacity() != bytes.size) {
                pendingMaskBuffer = ByteBuffer.allocateDirect(bytes.size)
            }
            val buf = pendingMaskBuffer!!
            buf.clear()
            buf.put(bytes)
            buf.position(0)
            pendingMaskW = width
            pendingMaskH = height
            maskDirty = true
        }
    }

    fun setBackdropImage(bitmap: Bitmap?) {
        synchronized(stateLock) {
            pendingBgBitmap?.recycle()
            pendingBgBitmap = bitmap
            if (bitmap == null) {
                hasBgImage = false
            }
            hasBgVideo = false
        }
    }

    fun setBackdropVideoActive(
        active: Boolean,
        videoWidth: Int = 720,
        videoHeight: Int = 960,
        rotationDeg: Int = bgVideoRotationDegrees
    ) {
        hasBgVideo = active
        if (active) {
            if (videoWidth > 0 && videoHeight > 0) {
                bgVideoW = videoWidth
                bgVideoH = videoHeight
            }
            bgVideoRotationDegrees = rotationDeg
            hasBgImage = false
        }
    }

    fun setBackdropVideoDimensions(videoWidth: Int, videoHeight: Int, rotationDeg: Int = bgVideoRotationDegrees) {
        if (videoWidth > 0 && videoHeight > 0) {
            bgVideoW = videoWidth
            bgVideoH = videoHeight
        }
        bgVideoRotationDegrees = rotationDeg
    }

    fun setColorFilter(matrix20: FloatArray?, isBeauty: Boolean) {
        postOnGlThread {
            if (matrix20 == null || matrix20.size < 20) {
                hasColorFilter = false
                beautyStrength = if (isBeauty) 0.7f else 0.0f
                Matrix.setIdentityM(colorMat4, 0)
                colorOffset4.fill(0f)
            } else {
                hasColorFilter = true
                beautyStrength = if (isBeauty) 0.7f else 0.0f
                // Android / Flutter 4x5 Row-major ColorMatrix -> OpenGL Column-major mat4 + vec4 offset
                // Row 0: [0, 1, 2, 3 | 4]
                // Row 1: [5, 6, 7, 8 | 9]
                // Row 2: [10,11,12,13| 14]
                // Row 3: [15,16,17,18| 19]
                colorMat4[0] = matrix20[0]; colorMat4[4] = matrix20[1]; colorMat4[8]  = matrix20[2];  colorMat4[12] = matrix20[3]
                colorMat4[1] = matrix20[5]; colorMat4[5] = matrix20[6]; colorMat4[9]  = matrix20[7];  colorMat4[13] = matrix20[8]
                colorMat4[2] = matrix20[10];colorMat4[6] = matrix20[11];colorMat4[10] = matrix20[12]; colorMat4[14] = matrix20[13]
                colorMat4[3] = matrix20[15];colorMat4[7] = matrix20[16];colorMat4[11] = matrix20[17]; colorMat4[15] = matrix20[18]

                colorOffset4[0] = matrix20[4] / 255.0f
                colorOffset4[1] = matrix20[9] / 255.0f
                colorOffset4[2] = matrix20[14] / 255.0f
                colorOffset4[3] = matrix20[19] / 255.0f
            }
        }
    }

    @Volatile private var encoderWidth = 720
    @Volatile private var encoderHeight = 960

    fun attachRecorderSurface(recorder: CompositedMp4Recorder, surface: Surface, width: Int = outputWidth, height: Int = outputHeight) {
        postOnGlThread {
            detachEncoderSurfaceInternal()
            val cfg = eglConfig ?: return@postOnGlThread
            val attribs = intArrayOf(EGL14.EGL_NONE)
            encoderEglSurface = EGL14.eglCreateWindowSurface(eglDisplay, cfg, surface, attribs, 0)
            encoderWidth = width
            encoderHeight = height
            lastEncodedPtsNs = 0L
            activeRecorder = recorder
            Log.i(TAG, "Encoder EGLSurface attached for video recording (${width}x${height})")
        }
    }

    fun detachRecorderSurface(onDetached: () -> Unit) {
        postOnGlThread {
            detachEncoderSurfaceInternal()
            onDetached()
        }
    }

    private fun detachEncoderSurfaceInternal() {
        activeRecorder = null
        if (encoderEglSurface != EGL14.EGL_NO_SURFACE) {
            EGL14.eglMakeCurrent(eglDisplay, previewEglSurface, previewEglSurface, eglContext)
            EGL14.eglDestroySurface(eglDisplay, encoderEglSurface)
            encoderEglSurface = EGL14.EGL_NO_SURFACE
        }
    }

    private fun scheduleRenderTick() {
        if (isReleased || renderLoopScheduled) return
        renderLoopScheduled = true
        glHandler?.postDelayed(renderRunnable, 30)
    }

    private val renderRunnable = Runnable {
        renderLoopScheduled = false
        if (!isReleased) {
            renderFrame()
            scheduleRenderTick()
        }
    }

    private fun initEgl(previewTargetSurface: Surface) {
        eglDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        val version = IntArray(2)
        EGL14.eglInitialize(eglDisplay, version, 0, version, 1)

        val configAttribs = intArrayOf(
            EGL14.EGL_RED_SIZE, 8,
            EGL14.EGL_GREEN_SIZE, 8,
            EGL14.EGL_BLUE_SIZE, 8,
            EGL14.EGL_ALPHA_SIZE, 8,
            EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
            EGL_RECORDABLE_ANDROID, 1,
            EGL14.EGL_NONE
        )
        val configs = arrayOfNulls<EGLConfig>(1)
        val numConfigs = IntArray(1)
        EGL14.eglChooseConfig(eglDisplay, configAttribs, 0, configs, 0, 1, numConfigs, 0)
        eglConfig = configs[0]

        val ctxAttribs = intArrayOf(
            EGL14.EGL_CONTEXT_CLIENT_VERSION, 2,
            EGL14.EGL_NONE
        )
        eglContext = EGL14.eglCreateContext(eglDisplay, eglConfig, EGL14.EGL_NO_CONTEXT, ctxAttribs, 0)

        val surfAttribs = intArrayOf(EGL14.EGL_NONE)
        previewEglSurface = EGL14.eglCreateWindowSurface(eglDisplay, eglConfig, previewTargetSurface, surfAttribs, 0)
        EGL14.eglMakeCurrent(eglDisplay, previewEglSurface, previewEglSurface, eglContext)
    }

    private fun initGlObjects() {
        pass1Program = createProgram(PASS1_VERT, PASS1_FRAG)
        mainProgram = createProgram(MAIN_VERT, MAIN_FRAG)

        // 1. Camera OES Texture
        val texIds = IntArray(4)
        GLES20.glGenTextures(4, texIds, 0)
        cameraTexId = texIds[0]
        bgVideoTexId = texIds[1]
        bgImageTexId = texIds[2]
        maskTexId = texIds[3]

        setupOesTexture(cameraTexId)
        setupOesTexture(bgVideoTexId)

        setup2DTexture(bgImageTexId)
        setup2DTexture(maskTexId)

        // Create SurfaceTextures
        cameraSurfaceTexture = SurfaceTexture(cameraTexId).apply {
            setDefaultBufferSize(960, 720)
            setOnFrameAvailableListener {
                cameraFrameAvailable = true
                glHandler?.post { renderFrame() }
            }
        }
        cameraSurface = Surface(cameraSurfaceTexture)

        bgVideoSurfaceTexture = SurfaceTexture(bgVideoTexId).apply {
            setDefaultBufferSize(outputWidth, outputHeight)
            setOnFrameAvailableListener {
                bgVideoFrameAvailable = true
            }
        }
        bgVideoSurface = Surface(bgVideoSurfaceTexture)

        // 2. Background Video Offscreen FBO (720x960)
        val fboArr = IntArray(1)
        GLES20.glGenFramebuffers(1, fboArr, 0)
        bgFboId = fboArr[0]

        val fboTexArr = IntArray(1)
        GLES20.glGenTextures(1, fboTexArr, 0)
        bgFboTexId = fboTexArr[0]
        setup2DTexture(bgFboTexId)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, bgFboTexId)
        GLES20.glTexImage2D(
            GLES20.GL_TEXTURE_2D, 0, GLES20.GL_RGBA,
            outputWidth, outputHeight, 0,
            GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, null
        )

        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, bgFboId)
        GLES20.glFramebufferTexture2D(
            GLES20.GL_FRAMEBUFFER, GLES20.GL_COLOR_ATTACHMENT0,
            GLES20.GL_TEXTURE_2D, bgFboTexId, 0
        )
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
    }

    private fun setupOesTexture(texId: Int) {
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, texId)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
    }

    private fun setup2DTexture(texId: Int) {
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texId)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
    }

    private fun renderFrame() {
        if (isReleased || eglDisplay == EGL14.EGL_NO_DISPLAY) return

        // Update SurfaceTextures while EGLContext is current on preview surface
        EGL14.eglMakeCurrent(eglDisplay, previewEglSurface, previewEglSurface, eglContext)

        if (cameraFrameAvailable) {
            cameraFrameAvailable = false
            try {
                cameraSurfaceTexture?.updateTexImage()
                cameraSurfaceTexture?.getTransformMatrix(stMatrix)
            } catch (_: Exception) {}
        }

        if (hasBgVideo && bgVideoFrameAvailable) {
            bgVideoFrameAvailable = false
            try {
                bgVideoSurfaceTexture?.updateTexImage()
                bgVideoSurfaceTexture?.getTransformMatrix(bgVideoMatrix)
                blitBgVideoToFbo()
            } catch (_: Exception) {}
        } else if (hasBgVideo) {
            // Re-blit FBO periodically even if video hasn't ticked this 30ms slot on first frame
            blitBgVideoToFbo()
        }

        uploadPendingTextures()

        // Draw to Flutter Preview Texture Surface
        drawCompositeScene(outputWidth, outputHeight)
        EGL14.eglSwapBuffers(eglDisplay, previewEglSurface)

        // Draw to MP4 Encoder Surface if actively recording
        val rec = activeRecorder
        if (rec != null && rec.isRecording && encoderEglSurface != EGL14.EGL_NO_SURFACE) {
            EGL14.eglMakeCurrent(eglDisplay, encoderEglSurface, encoderEglSurface, eglContext)
            drawCompositeScene(encoderWidth, encoderHeight)
            val nowNs = System.nanoTime()
            val ptsNs = max(nowNs - rec.startTimeNs, lastEncodedPtsNs + 1_000_000L)
            lastEncodedPtsNs = ptsNs
            EGLExt.eglPresentationTimeANDROID(eglDisplay, encoderEglSurface, ptsNs)
            EGL14.eglSwapBuffers(eglDisplay, encoderEglSurface)
        }
    }

    private fun uploadPendingTextures() {
        var bmpToUpload: Bitmap? = null
        var mBuf: ByteBuffer? = null
        var mW = 0
        var mH = 0

        synchronized(stateLock) {
            if (pendingBgBitmap != null) {
                bmpToUpload = pendingBgBitmap
                pendingBgBitmap = null
            }
            if (maskDirty && pendingMaskBuffer != null) {
                mBuf = pendingMaskBuffer
                mW = pendingMaskW
                mH = pendingMaskH
                maskDirty = false
            }
        }

        bmpToUpload?.let { bmp ->
            if (!bmp.isRecycled) {
                bgImageW = max(1, bmp.width)
                bgImageH = max(1, bmp.height)
                GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, bgImageTexId)
                GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bmp, 0)
                hasBgImage = true
                bmp.recycle()
            }
        }

        mBuf?.let { buf ->
            if (mW > 0 && mH > 0) {
                buf.position(0)
                GLES20.glPixelStorei(GLES20.GL_UNPACK_ALIGNMENT, 1)
                GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, maskTexId)
                if (!maskUploadedOnce || uploadedMaskW != mW || uploadedMaskH != mH) {
                    GLES20.glTexImage2D(
                        GLES20.GL_TEXTURE_2D, 0, GLES20.GL_LUMINANCE,
                        mW, mH, 0, GLES20.GL_LUMINANCE, GLES20.GL_UNSIGNED_BYTE, buf
                    )
                    uploadedMaskW = mW
                    uploadedMaskH = mH
                    maskUploadedOnce = true
                } else {
                    GLES20.glTexSubImage2D(
                        GLES20.GL_TEXTURE_2D, 0, 0, 0,
                        mW, mH, GLES20.GL_LUMINANCE, GLES20.GL_UNSIGNED_BYTE, buf
                    )
                }
            }
        }
    }

    private fun computeAspectFillScale(srcW: Int, srcH: Int, dstW: Int, dstH: Int): Pair<Float, Float> {
        val srcAspect = srcW.toFloat() / max(1, srcH).toFloat()
        val dstAspect = dstW.toFloat() / max(1, dstH).toFloat()
        return if (srcAspect > dstAspect) {
            Pair(dstAspect / srcAspect, 1.0f)
        } else {
            Pair(1.0f, srcAspect / dstAspect)
        }
    }

    private fun blitBgVideoToFbo() {
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, bgFboId)
        GLES20.glViewport(0, 0, outputWidth, outputHeight)
        GLES20.glUseProgram(pass1Program)

        val aPos = GLES20.glGetAttribLocation(pass1Program, "aPosition")
        val aUv = GLES20.glGetAttribLocation(pass1Program, "aUprightUv")
        bindQuadAttribs(aPos, aUv)

        val matrixHasRot = kotlin.math.abs(bgVideoMatrix[1]) > 0.3f || kotlin.math.abs(bgVideoMatrix[4]) > 0.3f
        val effectiveRot = if (matrixHasRot) 0 else bgVideoRotationDegrees
        val isRotatedPortrait = bgVideoRotationDegrees == 90 || bgVideoRotationDegrees == 270
        val dispW = if (isRotatedPortrait) bgVideoH else bgVideoW
        val dispH = if (isRotatedPortrait) bgVideoW else bgVideoH
        val (sx, sy) = computeAspectFillScale(dispW, dispH, outputWidth, outputHeight)

        GLES20.glUniformMatrix4fv(GLES20.glGetUniformLocation(pass1Program, "uBgVideoMatrix"), 1, false, bgVideoMatrix, 0)
        GLES20.glUniform2f(GLES20.glGetUniformLocation(pass1Program, "uBgVideoCropScale"), sx, sy)
        GLES20.glUniform1i(GLES20.glGetUniformLocation(pass1Program, "uBgVideoRotation"), effectiveRot)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, bgVideoTexId)
        GLES20.glUniform1i(GLES20.glGetUniformLocation(pass1Program, "uBgVideoTex"), 0)

        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        GLES20.glDisableVertexAttribArray(aPos)
        GLES20.glDisableVertexAttribArray(aUv)
        GLES20.glBindFramebuffer(GLES20.GL_FRAMEBUFFER, 0)
    }

    private fun drawCompositeScene(targetW: Int = outputWidth, targetH: Int = outputHeight) {
        GLES20.glViewport(0, 0, targetW, targetH)
        GLES20.glClearColor(0.06f, 0.06f, 0.1f, 1.0f)
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
        GLES20.glUseProgram(mainProgram)

        val aPos = GLES20.glGetAttribLocation(mainProgram, "aPosition")
        val aUv = GLES20.glGetAttribLocation(mainProgram, "aUprightUv")
        bindQuadAttribs(aPos, aUv)

        // Texture Unit 0 -> Camera OES
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, cameraTexId)
        GLES20.glUniform1i(GLES20.glGetUniformLocation(mainProgram, "uCameraTex"), 0)

        // Texture Unit 1 -> ML Kit Mask 2D
        GLES20.glActiveTexture(GLES20.GL_TEXTURE1)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, maskTexId)
        GLES20.glUniform1i(GLES20.glGetUniformLocation(mainProgram, "uMaskTex"), 1)

        // Texture Unit 2 -> Replaced Background 2D (Video FBO or Static Image)
        val useVideoFbo = hasBgVideo
        val hasAnyBg = hasBgVideo || hasBgImage
        GLES20.glActiveTexture(GLES20.GL_TEXTURE2)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, if (useVideoFbo) bgFboTexId else bgImageTexId)
        GLES20.glUniform1i(GLES20.glGetUniformLocation(mainProgram, "uBgTex"), 2)

        val isLandscape = deviceRotationDegrees == 90 || deviceRotationDegrees == 270
        val effDstW = if (isLandscape) targetH else targetW
        val effDstH = if (isLandscape) targetW else targetH

        val (camSx, camSy) = computeAspectFillScale(camPortraitW, camPortraitH, effDstW, effDstH)
        val (maskSx, maskSy) = computeAspectFillScale(analysisPortraitW, analysisPortraitH, effDstW, effDstH)
        val (bgSx, bgSy) = computeAspectFillScale(bgImageW, bgImageH, effDstW, effDstH)

        GLES20.glUniformMatrix4fv(GLES20.glGetUniformLocation(mainProgram, "uStMatrix"), 1, false, stMatrix, 0)
        GLES20.glUniform1i(GLES20.glGetUniformLocation(mainProgram, "uRotationDegrees"), 0)
        GLES20.glUniform1i(GLES20.glGetUniformLocation(mainProgram, "uDeviceRotation"), deviceRotationDegrees)
        GLES20.glUniform1f(GLES20.glGetUniformLocation(mainProgram, "uIsFrontCamera"), if (isFrontCamera) 1.0f else 0.0f)

        GLES20.glUniform2f(GLES20.glGetUniformLocation(mainProgram, "uCamCropScale"), camSx, camSy)
        GLES20.glUniform2f(GLES20.glGetUniformLocation(mainProgram, "uMaskCropScale"), maskSx, maskSy)
        GLES20.glUniform2f(GLES20.glGetUniformLocation(mainProgram, "uBgCropScale"), bgSx, bgSy)
        GLES20.glUniform2f(
            GLES20.glGetUniformLocation(mainProgram, "uMaskTexel"),
            1.0f / max(1, uploadedMaskW),
            1.0f / max(1, uploadedMaskH)
        )
        GLES20.glUniform1i(GLES20.glGetUniformLocation(mainProgram, "uHasMask"), if (maskUploadedOnce) 1 else 0)

        GLES20.glUniform1i(GLES20.glGetUniformLocation(mainProgram, "uCutoutMode"), cutoutMode)
        GLES20.glUniform1f(GLES20.glGetUniformLocation(mainProgram, "uSensitivity"), sensitivity)

        GLES20.glUniform1i(GLES20.glGetUniformLocation(mainProgram, "uHasBgTex"), if (hasAnyBg) 1 else 0)
        GLES20.glUniform1i(GLES20.glGetUniformLocation(mainProgram, "uBgIsVideoFbo"), if (useVideoFbo) 1 else 0)
        GLES20.glUniform1i(GLES20.glGetUniformLocation(mainProgram, "uMotionMode"), motionMode)
        val elapsedSec = ((System.currentTimeMillis() - startTimeMs) % 600_000L) / 1000.0f
        GLES20.glUniform1f(GLES20.glGetUniformLocation(mainProgram, "uTime"), elapsedSec)

        GLES20.glUniform1i(GLES20.glGetUniformLocation(mainProgram, "uHasColorFilter"), if (hasColorFilter) 1 else 0)
        GLES20.glUniformMatrix4fv(GLES20.glGetUniformLocation(mainProgram, "uColorMat"), 1, false, colorMat4, 0)
        GLES20.glUniform4fv(GLES20.glGetUniformLocation(mainProgram, "uColorOffset"), 1, colorOffset4, 0)
        GLES20.glUniform1f(GLES20.glGetUniformLocation(mainProgram, "uBeautyStrength"), beautyStrength)

        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        GLES20.glDisableVertexAttribArray(aPos)
        GLES20.glDisableVertexAttribArray(aUv)
    }

    private fun bindQuadAttribs(posLoc: Int, uvLoc: Int) {
        vertexBuffer.position(0)
        GLES20.glEnableVertexAttribArray(posLoc)
        GLES20.glVertexAttribPointer(posLoc, 2, GLES20.GL_FLOAT, false, 16, vertexBuffer)

        vertexBuffer.position(2)
        GLES20.glEnableVertexAttribArray(uvLoc)
        GLES20.glVertexAttribPointer(uvLoc, 2, GLES20.GL_FLOAT, false, 16, vertexBuffer)
    }

    private fun createProgram(vertSrc: String, fragSrc: String): Int {
        val vShader = compileShader(GLES20.GL_VERTEX_SHADER, vertSrc)
        val fShader = compileShader(GLES20.GL_FRAGMENT_SHADER, fragSrc)
        val prog = GLES20.glCreateProgram()
        GLES20.glAttachShader(prog, vShader)
        GLES20.glAttachShader(prog, fShader)
        GLES20.glLinkProgram(prog)
        val linkStatus = IntArray(1)
        GLES20.glGetProgramiv(prog, GLES20.GL_LINK_STATUS, linkStatus, 0)
        if (linkStatus[0] == 0) {
            val err = GLES20.glGetProgramInfoLog(prog)
            GLES20.glDeleteProgram(prog)
            throw RuntimeException("GL Program link failed: $err")
        }
        return prog
    }

    private fun compileShader(type: Int, src: String): Int {
        val shader = GLES20.glCreateShader(type)
        GLES20.glShaderSource(shader, src)
        GLES20.glCompileShader(shader)
        val compiled = IntArray(1)
        GLES20.glGetShaderiv(shader, GLES20.GL_COMPILE_STATUS, compiled, 0)
        if (compiled[0] == 0) {
            val err = GLES20.glGetShaderInfoLog(shader)
            GLES20.glDeleteShader(shader)
            throw RuntimeException("GL Shader compile failed ($type): $err")
        }
        return shader
    }

    fun release() {
        if (isReleased) return
        isReleased = true
        glHandler?.post {
            try {
                detachEncoderSurfaceInternal()
                synchronized(stateLock) {
                    pendingBgBitmap?.recycle()
                    pendingBgBitmap = null
                }
                cameraSurface?.release()
                cameraSurfaceTexture?.release()
                bgVideoSurface?.release()
                bgVideoSurfaceTexture?.release()

                if (bgFboId != 0) GLES20.glDeleteFramebuffers(1, intArrayOf(bgFboId), 0)
                val delTex = intArrayOf(cameraTexId, bgVideoTexId, bgFboTexId, bgImageTexId, maskTexId)
                GLES20.glDeleteTextures(delTex.size, delTex, 0)
                if (pass1Program != 0) GLES20.glDeleteProgram(pass1Program)
                if (mainProgram != 0) GLES20.glDeleteProgram(mainProgram)

                if (eglDisplay != EGL14.EGL_NO_DISPLAY) {
                    EGL14.eglMakeCurrent(eglDisplay, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
                    if (previewEglSurface != EGL14.EGL_NO_SURFACE) EGL14.eglDestroySurface(eglDisplay, previewEglSurface)
                    if (eglContext != EGL14.EGL_NO_CONTEXT) EGL14.eglDestroyContext(eglDisplay, eglContext)
                    EGL14.eglTerminate(eglDisplay)
                }
            } catch (e: Exception) {
                Log.w(TAG, "GL release error: ${e.message}")
            } finally {
                glThread?.quitSafely()
            }
        }
    }
}
