package dev.imaged.examples.live_caption

import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channel = "dev.imaged.examples.live_caption/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "nativeLibraryDir" -> {
                        Log.i("LC_DIAG", "native_library_dir=${applicationInfo.nativeLibraryDir}")
                        result.success(applicationInfo.nativeLibraryDir)
                    }
                    "extractAsset" -> {
                        val assetPath = call.argument<String>("assetPath")
                        val outputPath = call.argument<String>("outputPath")
                        val expectedBytes = call.argument<Number>("expectedBytes")?.toLong()
                        if (assetPath == null || outputPath == null || expectedBytes == null) {
                            result.error("bad_args", "assetPath, outputPath, and expectedBytes are required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            extractFlutterAsset(assetPath, outputPath, expectedBytes)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("extract_failed", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun extractFlutterAsset(assetPath: String, outputPath: String, expectedBytes: Long) {
        Log.i("LC_DIAG", "native_extract_start asset=$assetPath output=$outputPath expected=$expectedBytes")
        val outFile = File(outputPath)
        if (outFile.exists() && outFile.length() == expectedBytes) {
            Log.i("LC_DIAG", "native_extract_skip asset=$assetPath bytes=${outFile.length()}")
            return
        }
        if (outFile.exists()) outFile.delete()
        outFile.parentFile?.mkdirs()

        val tmp = File("$outputPath.tmp")
        if (tmp.exists()) tmp.delete()

        assets.open("flutter_assets/$assetPath").use { input ->
            tmp.outputStream().use { output ->
                val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                while (true) {
                    val read = input.read(buffer)
                    if (read < 0) break
                    output.write(buffer, 0, read)
                }
                output.fd.sync()
            }
        }

        val written = tmp.length()
        if (written != expectedBytes) {
            tmp.delete()
            throw IllegalStateException("wrote $written bytes, expected $expectedBytes for $assetPath")
        }
        if (!tmp.renameTo(outFile)) {
            tmp.delete()
            throw IllegalStateException("failed to rename ${tmp.absolutePath} to ${outFile.absolutePath}")
        }
        Log.i("LC_DIAG", "native_extract_done asset=$assetPath bytes=$written")
    }
}
