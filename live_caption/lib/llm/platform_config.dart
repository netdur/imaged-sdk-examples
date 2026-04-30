import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';

import '../diagnostics.dart';

class PlatformConfig {
  const PlatformConfig({
    required this.libraryPath,
    required this.gpuLayers,
    this.nativeLibraryDir,
  });

  final String libraryPath;
  final int gpuLayers;
  final String? nativeLibraryDir;
}

const _nativeChannel = MethodChannel('dev.imaged.examples.live_caption/native');

Future<PlatformConfig> resolvePlatformConfig() async {
  if (!Platform.isAndroid) {
    throw UnsupportedError('live_caption currently targets Android only');
  }

  String? nativeLibraryDir;
  try {
    nativeLibraryDir = await _nativeChannel.invokeMethod<String>(
      'nativeLibraryDir',
    );
  } catch (_) {
    nativeLibraryDir = null;
  }
  Diagnostics.log(
    'native_library_dir',
    fields: {'nativeLibraryDir': nativeLibraryDir},
  );

  if (nativeLibraryDir != null && nativeLibraryDir.isNotEmpty) {
    _setenv('ADSP_LIBRARY_PATH', nativeLibraryDir);
    _setenv('LD_LIBRARY_PATH', nativeLibraryDir);
    Diagnostics.log(
      'hexagon_env_set',
      fields: {
        'ADSP_LIBRARY_PATH': nativeLibraryDir,
        'LD_LIBRARY_PATH': nativeLibraryDir,
      },
    );
  }

  return PlatformConfig(
    libraryPath: 'libllama.so',
    gpuLayers: 0,
    nativeLibraryDir: nativeLibraryDir,
  );
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
