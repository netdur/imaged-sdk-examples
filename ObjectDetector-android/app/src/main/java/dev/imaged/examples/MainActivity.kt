package dev.imaged.examples

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.RectF
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.view.PreviewView
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.core.content.ContextCompat
import dev.imaged.examples.ui.theme.ObjectDetectorandroidTheme

private const val LICENSE = "eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJpbWFnZWQuZGV2IiwiYXVkIjoic2RrLmltYWdlZC5kZXYiLCJzdWIiOiJjdXN0b21lckBpbWFnZWQuZGV2IiwiaWF0IjoxNzc3MjE1NDA5LCJuYmYiOjE3NzcyMTU0MDksImV4cCI6MTgwODMxOTQwOSwibWsiOiJiNjM5Y2RhZmYyNWEwNTcyYWFiYTY2NDg0Njg3MmI3NWZjODI3OTBkNzVhN2Y0MzE5ODg3MmVkMzExOWZmMjM4In0.1wT2igaHIAUrvUM_vNO3M6zifEgMSzp22OCxo0UCCnFoIFfCeuA1od-C_8vwQ6EiBwytaKFiRluFfHYAQLBg6Q"

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            ObjectDetectorandroidTheme {
                DetectorScreen()
            }
        }
    }
}

@Composable
private fun DetectorScreen() {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val detector = remember { CameraDetector(context, LICENSE) }

    var hasCameraPermission by remember {
        mutableStateOf(
            ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) ==
                PackageManager.PERMISSION_GRANTED
        )
    }
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted -> hasCameraPermission = granted }

    LaunchedEffect(Unit) {
        if (!hasCameraPermission) {
            permissionLauncher.launch(Manifest.permission.CAMERA)
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        if (hasCameraPermission) {
            AndroidView(
                modifier = Modifier.fillMaxSize(),
                factory = { ctx ->
                    PreviewView(ctx).apply {
                        scaleType = PreviewView.ScaleType.FIT_CENTER
                        implementationMode = PreviewView.ImplementationMode.COMPATIBLE
                        detector.bindToLifecycle(lifecycleOwner, surfaceProvider)
                    }
                }
            )

            DetectionsOverlay(detector = detector)
        } else {
            Column(
                modifier = Modifier.align(Alignment.Center).padding(24.dp)
            ) {
                Text(
                    text = "Camera permission required",
                    color = Color.White,
                )
            }
        }

        Text(
            text = detector.status,
            color = Color.White,
            fontSize = 12.sp,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 24.dp)
                .clip(RoundedCornerShape(50))
                .background(Color.Black.copy(alpha = 0.6f))
                .padding(horizontal = 10.dp, vertical = 4.dp)
        )
    }
}

@Composable
private fun DetectionsOverlay(detector: CameraDetector) {
    val frameW = detector.frameWidth
    val frameH = detector.frameHeight
    val detections = detector.detections
    if (frameW == 0 || frameH == 0 || detections.isEmpty()) return

    Canvas(modifier = Modifier.fillMaxSize()) {
        val displayRect = aspectFit(frameW.toFloat(), frameH.toFloat(), size.width, size.height)
        val sx = displayRect.width() / frameW
        val sy = displayRect.height() / frameH
        for (det in detections) {
            val x = displayRect.left + det.rect.left * sx
            val y = displayRect.top + det.rect.top * sy
            val w = det.rect.width() * sx
            val h = det.rect.height() * sy
            drawRect(
                color = Color.Green,
                topLeft = Offset(x, y),
                size = Size(w, h),
                style = Stroke(width = 4f)
            )
        }
    }

    LabelLayer(detector = detector)
}

@Composable
private fun LabelLayer(detector: CameraDetector) {
    val frameW = detector.frameWidth
    val frameH = detector.frameHeight
    val detections = detector.detections
    if (frameW == 0 || frameH == 0) return

    androidx.compose.foundation.layout.BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
        val containerW = constraints.maxWidth.toFloat()
        val containerH = constraints.maxHeight.toFloat()
        val displayRect = aspectFit(frameW.toFloat(), frameH.toFloat(), containerW, containerH)
        val sx = displayRect.width() / frameW
        val sy = displayRect.height() / frameH
        val density = androidx.compose.ui.platform.LocalDensity.current
        for (det in detections) {
            val xPx = (displayRect.left + det.rect.left * sx).coerceAtLeast(0f)
            val yPx = (displayRect.top + det.rect.top * sy - 16f).coerceAtLeast(0f)
            with(density) {
                Text(
                    text = "${det.label} ${(det.score * 100).toInt()}%",
                    color = Color.Black,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier
                        .padding(start = xPx.toDp(), top = yPx.toDp())
                        .background(Color.Green)
                        .padding(horizontal = 4.dp, vertical = 2.dp)
                )
            }
        }
    }
}

private fun aspectFit(contentW: Float, contentH: Float, containerW: Float, containerH: Float): RectF {
    if (contentW <= 0f || contentH <= 0f) return RectF(0f, 0f, containerW, containerH)
    val scale = minOf(containerW / contentW, containerH / contentH)
    val w = contentW * scale
    val h = contentH * scale
    val left = (containerW - w) / 2f
    val top = (containerH - h) / 2f
    return RectF(left, top, left + w, top + h)
}
