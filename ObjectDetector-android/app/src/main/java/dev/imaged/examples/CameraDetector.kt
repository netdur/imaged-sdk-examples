package dev.imaged.examples

import android.content.Context
import android.graphics.RectF
import android.os.Build
import android.util.Log
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.LifecycleOwner
import dev.imaged.sdk.ColorCode
import dev.imaged.sdk.ConfigurationOptions
import dev.imaged.sdk.Image
import dev.imaged.sdk.ImagedLoader
import dev.imaged.sdk.ImagedSDK
import java.io.File
import java.util.UUID
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.roundToInt

// === Benchmark switches — edit between runs ===
// Models in assets:
//   yolov8n.onnx       fp32, 320x320, opset 13, no end2end NMS  (HTP-friendly)
//   yolov8n_qdq.onnx   static QDQ int8, per-channel weights
//   yolov8s.onnx       fp32 small
//   yolov8s_qdq.onnx   static QDQ int8 small
//   yolov8m.onnx       fp32 medium
//   yolov8m_qdq.onnx   static QDQ int8 medium
//   yolo26{n,m,x}.onnx fp32, head-split, no end2end NMS  (HTP-friendly)
//   yolo26{n,m,x}_qdq.onnx static QDQ int8 head-split
private const val BENCH_MODEL = "yolo26x_qdq.onnx"
// Providers: "cpu" or "qnn" (qnn requires arm64-v8a)
private const val BENCH_PROVIDER = "qnn"
// =============================================

@Immutable
data class Detection(
    val id: String = UUID.randomUUID().toString(),
    val label: String,
    val score: Double,
    val rect: RectF,
)

class CameraDetector(
    private val context: Context,
    private val license: String,
) {
    var detections by mutableStateOf<List<Detection>>(emptyList())
        private set
    var frameWidth by mutableStateOf(0)
        private set
    var frameHeight by mutableStateOf(0)
        private set
    private var _status by mutableStateOf("Initializing…")
    val status: String get() = _status

    private fun setStatus(s: String) {
        Log.i(TAG, "STATUS: $s")
        _status = s
    }

    private val analysisExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var ai: ImagedSDK? = null
    private var isReady = false
    @Volatile private var inFlight = false

    // Benchmark state — accessed only from analysisExecutor thread.
    private var benchCount = 0
    private var benchSumNs = 0L
    private var benchMinNs = Long.MAX_VALUE
    private var benchMaxNs = 0L
    private val benchWindow = 30

    init {
        val loaded = try {
            // Pass the Context so ImagedLoader stages the Hexagon skel
            // files into filesDir and points ADSP_LIBRARY_PATH at them.
            // Required for QNN HTP to actually engage on Snapdragon —
            // without this, ORT defaults to /data/app/.../lib/arm64
            // which the FastRPC daemon can't read on Android 12+.
            ImagedLoader.load(context); true
        } catch (t: Throwable) {
            setStatus("Native lib load failed: ${t.message}")
            false
        }
        if (loaded) configureSDK()
    }

    private fun configureSDK() {
        val sdk = ImagedSDK()
        ai = sdk
        val cfg = sdk.options
        cfg.setString("license", license)
        val rc = cfg.checkLicense()
        if (rc != ConfigurationOptions.STATUS_SUCCESS || !sdk.isLicensed) {
            setStatus("License invalid (status $rc).")
            return
        }
        val modelPath = try {
            copyAssetToFiles(BENCH_MODEL)
        } catch (t: Throwable) {
            setStatus("Failed to stage model: ${t.message}")
            return
        }
        cfg.setString("yolo.model", modelPath)
        cfg.setString("yolo.classNames", COCO_LABELS.joinToString(","))
        cfg.setDouble("yolo.confidenceThreshold", 0.35)
        cfg.setString("yolo.inference.provider", BENCH_PROVIDER)
        Log.i(TAG, "BENCH config — model=$BENCH_MODEL provider=$BENCH_PROVIDER abi=${Build.SUPPORTED_ABIS.firstOrNull()}")
        if (!sdk.hasFamily("yolo")) {
            setStatus("yolo family unavailable in this SDK build.")
            return
        }
        isReady = true
        setStatus("Ready — starting camera…")
    }

    private fun copyAssetToFiles(name: String): String {
        val out = File(context.filesDir, name)
        // Always re-stage during benchmarking so updated APK assets overwrite stale copies.
        out.delete()
        Log.i(TAG, "Staging $name from APK assets…")
        context.assets.open(name).use { input ->
            out.outputStream().use { output -> input.copyTo(output) }
        }
        Log.i(TAG, "Staged $name -> ${out.absolutePath} (${out.length()} bytes)")
        return out.absolutePath
    }

    fun bindToLifecycle(
        lifecycleOwner: LifecycleOwner,
        previewSurfaceProvider: Preview.SurfaceProvider,
    ) {
        Log.e(TAG, "===BENCH=== bindToLifecycle called, isReady=$isReady")
        if (!isReady) return
        startHeartbeat()
        val providerFuture = ProcessCameraProvider.getInstance(context)
        providerFuture.addListener({
            val provider = providerFuture.get()
            val preview = Preview.Builder().build().apply {
                surfaceProvider = previewSurfaceProvider
            }
            val analysis = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                .setOutputImageRotationEnabled(true)
                .build()
            analysis.setAnalyzer(analysisExecutor) { proxy -> process(proxy) }
            Log.e(TAG, "===BENCH=== analyzer attached")

            try {
                provider.unbindAll()
                provider.bindToLifecycle(
                    lifecycleOwner,
                    CameraSelector.DEFAULT_BACK_CAMERA,
                    preview,
                    analysis,
                )
                Log.e(TAG, "===BENCH=== bindToLifecycle SUCCESS")
                setStatus("Running — point the camera at something.")
            } catch (t: Throwable) {
                Log.e(TAG, "===BENCH=== bindToLifecycle FAILED", t)
                setStatus("Camera bind failed: ${t.message}")
            }
        }, androidx.core.content.ContextCompat.getMainExecutor(context))
    }

    @Volatile private var heartbeatStarted = false
    private fun startHeartbeat() {
        if (heartbeatStarted) return
        heartbeatStarted = true
        Thread({
            var n = 0
            while (true) {
                Thread.sleep(2000)
                n += 1
                Log.e(TAG, "===BENCH=== HEARTBEAT #$n framesSeen=$framesSeen ready=$isReady inFlight=$inFlight")
            }
        }, "bench-heartbeat").apply { isDaemon = true }.start()
    }

    @Volatile private var framesSeen = 0
    private fun process(proxy: ImageProxy) {
        framesSeen += 1
        if (framesSeen <= 3 || framesSeen % 30 == 0) {
            Log.e(TAG, "===BENCH=== FRAME #$framesSeen ready=$isReady inFlight=$inFlight " +
                "size=${proxy.width}x${proxy.height} fmt=${proxy.format}")
        }
        if (!isReady || inFlight) {
            proxy.close()
            return
        }
        inFlight = true
        try {
            val plane = proxy.planes.firstOrNull()
            if (plane == null) return
            val width = proxy.width
            val height = proxy.height
            val rowStride = plane.rowStride
            val pixelStride = plane.pixelStride
            val src = plane.buffer
            val needed = width * height * 4
            val packed = ByteArray(needed)
            if (rowStride == width * pixelStride && pixelStride == 4) {
                src.position(0)
                src.get(packed, 0, needed)
            } else {
                val rowBuf = ByteArray(rowStride)
                for (y in 0 until height) {
                    src.position(y * rowStride)
                    src.get(rowBuf, 0, rowStride)
                    var dst = y * width * 4
                    var srcOff = 0
                    for (x in 0 until width) {
                        packed[dst]     = rowBuf[srcOff]
                        packed[dst + 1] = rowBuf[srcOff + 1]
                        packed[dst + 2] = rowBuf[srcOff + 2]
                        packed[dst + 3] = rowBuf[srcOff + 3]
                        dst += 4
                        srcOff += pixelStride
                    }
                }
            }

            Image().use { img ->
                img.setData(packed, width, height, ColorCode.RGBA)
                val sdk = ai ?: return
                val t0 = System.nanoTime()
                val resp = sdk.detect("yolo", img)
                val dtNs = System.nanoTime() - t0
                recordBench(dtNs, width, height)
                if (resp.error != 0) {
                    Log.w(TAG, "detect error ${resp.error}: ${resp.message}")
                    return
                }
                val mapped = resp.objects.orEmpty().map { obj ->
                    Detection(
                        label = obj.label ?: "?",
                        score = obj.score,
                        rect = RectF(
                            obj.boundingBox.x.toFloat(),
                            obj.boundingBox.y.toFloat(),
                            (obj.boundingBox.x + obj.boundingBox.width).toFloat(),
                            (obj.boundingBox.y + obj.boundingBox.height).toFloat(),
                        ),
                    )
                }
                frameWidth = width
                frameHeight = height
                detections = mapped
            }
        } catch (t: Throwable) {
            Log.e(TAG, "process failed", t)
        } finally {
            inFlight = false
            proxy.close()
        }
    }

    private fun recordBench(dtNs: Long, w: Int, h: Int) {
        val ms = dtNs / 1_000_000.0
        Log.e(TAG, "===BENCH=== detect ${w}x${h} = %.2fms".format(ms))
        benchCount += 1
        benchSumNs += dtNs
        if (dtNs < benchMinNs) benchMinNs = dtNs
        if (dtNs > benchMaxNs) benchMaxNs = dtNs
        if (benchCount >= benchWindow) {
            val avgMs = benchSumNs / benchCount / 1_000_000.0
            val minMs = benchMinNs / 1_000_000.0
            val maxMs = benchMaxNs / 1_000_000.0
            val fps = 1000.0 / avgMs
            Log.e(
                TAG,
                "===BENCH=== SUMMARY [%d frames] %s/%s avg=%.2fms min=%.2fms max=%.2fms ~%.1f fps".format(
                    benchCount, BENCH_MODEL, BENCH_PROVIDER, avgMs, minMs, maxMs, fps
                )
            )
            benchCount = 0
            benchSumNs = 0L
            benchMinNs = Long.MAX_VALUE
            benchMaxNs = 0L
        }
    }

    fun close() {
        analysisExecutor.shutdown()
        ai?.close()
        ai = null
    }

    companion object {
        private const val TAG = "CameraDetector"
    }
}

// COCO 80 classes — standard YOLOv8/YOLO11/YOLOv26 training set.
private val COCO_LABELS = listOf(
    "person", "bicycle", "car", "motorcycle", "airplane", "bus", "train",
    "truck", "boat", "traffic light", "fire hydrant", "stop sign",
    "parking meter", "bench", "bird", "cat", "dog", "horse", "sheep", "cow",
    "elephant", "bear", "zebra", "giraffe", "backpack", "umbrella", "handbag",
    "tie", "suitcase", "frisbee", "skis", "snowboard", "sports ball", "kite",
    "baseball bat", "baseball glove", "skateboard", "surfboard",
    "tennis racket", "bottle", "wine glass", "cup", "fork", "knife", "spoon",
    "bowl", "banana", "apple", "sandwich", "orange", "broccoli", "carrot",
    "hot dog", "pizza", "donut", "cake", "chair", "couch", "potted plant",
    "bed", "dining table", "toilet", "tv", "laptop", "mouse", "remote",
    "keyboard", "cell phone", "microwave", "oven", "toaster", "sink",
    "refrigerator", "book", "clock", "vase", "scissors", "teddy bear",
    "hair drier", "toothbrush",
)

internal fun Int.dpRound(): Int = (this + 0.5f).roundToInt()
