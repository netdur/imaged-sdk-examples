import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Per-platform settings the engine layer needs to know about.
class PlatformConfig {
  PlatformConfig({
    required this.libraryPath,
    required this.gpuLayers,
    required this.spawnFromProcess,
    this.nativeLibraryDir,
  });

  /// Path passed to `LlamaLibrary.load(path:)` / `LlamaEngine.spawn(libraryPath:)`.
  /// Ignored when [spawnFromProcess] is true.
  final String libraryPath;

  /// On Apple: 99 (full Metal offload). On Android: 0 (CPU AAR has no GPU;
  /// Hex AAR auto-picks via ggml-backend regardless).
  final int gpuLayers;

  /// True on iOS: use `LlamaEngine.spawnFromProcess()` because the xcframework
  /// is statically linked into the app binary (no dlopen path).
  final bool spawnFromProcess;

  /// Android only: where `.so` files were extracted by the OS at install time.
  /// Used to set ADSP_LIBRARY_PATH so FastRPC can find the HTP DSP skeletons.
  final String? nativeLibraryDir;
}

const _nativeChannel = MethodChannel('dev.imaged.examples.aichat/native');

// On macOS the dylib isn't copied into the app bundle (no .framework here),
// so the example needs an absolute path to a llama.cpp build. Override via:
//   flutter run -d macos \
//     --dart-define=AICHAT_LLAMA_DYLIB=/abs/path/to/libllama.dylib
const _macDylibPath = String.fromEnvironment(
  'AICHAT_LLAMA_DYLIB',
  defaultValue: 'libllama.dylib',
);

Future<PlatformConfig> resolvePlatformConfig() async {
  if (Platform.isAndroid) {
    String? nativeLibDir;
    try {
      nativeLibDir =
          await _nativeChannel.invokeMethod<String>('nativeLibraryDir');
    } catch (_) {}
    if (nativeLibDir != null) {
      // FastRPC cdsprpcd looks here for libggml-htp-v*.so.
      _setenv('ADSP_LIBRARY_PATH', nativeLibDir);
      _setenv('LD_LIBRARY_PATH', nativeLibDir);
    }
    return PlatformConfig(
      libraryPath: 'libllama.so',
      gpuLayers: 0,
      spawnFromProcess: false,
      nativeLibraryDir: nativeLibDir,
    );
  }

  if (Platform.isMacOS) {
    return PlatformConfig(
      libraryPath: _macDylibPath,
      gpuLayers: 99,
      spawnFromProcess: false,
    );
  }

  if (Platform.isIOS) {
    return PlatformConfig(
      libraryPath: '<process>',
      gpuLayers: 99,
      spawnFromProcess: true,
    );
  }

  throw UnsupportedError(
      'aichat does not support ${Platform.operatingSystem} yet');
}

/// Where the app stores its model bundles and conversation media.
/// Cross-platform via path_provider.
Future<String> getModelsDir() async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory('${docs.path}/models');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  return dir.path;
}

typedef _SetenvNative = Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Int32);
typedef _SetenvDart = int Function(Pointer<Utf8>, Pointer<Utf8>, int);

int _setenv(String key, String value) {
  final fn = DynamicLibrary.process()
      .lookupFunction<_SetenvNative, _SetenvDart>('setenv');
  final k = key.toNativeUtf8();
  final v = value.toNativeUtf8();
  try {
    return fn(k, v, 1);
  } finally {
    malloc.free(k);
    malloc.free(v);
  }
}
