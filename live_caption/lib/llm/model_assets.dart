import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../diagnostics.dart';

const _nativeChannel = MethodChannel('dev.imaged.examples.live_caption/native');
const smolVlmModelAsset = 'assets/models/SmolVLM-500M-Instruct-Q8_0.gguf';
const smolVlmMmprojAsset =
    'assets/models/mmproj-SmolVLM-500M-Instruct-Q8_0.gguf';

const _modelFileName = 'SmolVLM-500M-Instruct-Q8_0.gguf';
const _mmprojFileName = 'mmproj-SmolVLM-500M-Instruct-Q8_0.gguf';
const _modelBytes = 436806912;
const _mmprojBytes = 108783360;

class ExtractedModelPaths {
  const ExtractedModelPaths({
    required this.modelPath,
    required this.mmprojPath,
  });

  final String modelPath;
  final String mmprojPath;
}

typedef ExtractionStatus = void Function(String status);

Future<ExtractedModelPaths> ensureSmolVlmExtracted({
  ExtractionStatus? onStatus,
}) async {
  final support = await getApplicationSupportDirectory();
  final modelsDir = Directory(p.join(support.path, 'models'));
  if (!modelsDir.existsSync()) {
    modelsDir.createSync(recursive: true);
  }

  final modelPath = p.join(modelsDir.path, _modelFileName);
  final mmprojPath = p.join(modelsDir.path, _mmprojFileName);

  await _extractAssetIfNeeded(
    assetPath: smolVlmModelAsset,
    outputPath: modelPath,
    expectedBytes: _modelBytes,
    label: 'SmolVLM',
    onStatus: onStatus,
  );
  await _extractAssetIfNeeded(
    assetPath: smolVlmMmprojAsset,
    outputPath: mmprojPath,
    expectedBytes: _mmprojBytes,
    label: 'SmolVLM projector',
    onStatus: onStatus,
  );

  return ExtractedModelPaths(modelPath: modelPath, mmprojPath: mmprojPath);
}

Future<void> _extractAssetIfNeeded({
  required String assetPath,
  required String outputPath,
  required int expectedBytes,
  required String label,
  ExtractionStatus? onStatus,
}) async {
  final out = File(outputPath);
  if (out.existsSync() && out.lengthSync() == expectedBytes) {
    Diagnostics.log(
      'model_asset_ready',
      fields: {
        'label': label,
        'path': outputPath,
        'bytes': expectedBytes,
        'extracted': false,
      },
    );
    onStatus?.call('$label ready');
    return;
  }

  if (out.existsSync()) {
    out.deleteSync();
  }

  onStatus?.call('extracting $label');
  Diagnostics.log(
    'model_asset_extract_start',
    fields: {
      'label': label,
      'assetPath': assetPath,
      'outputPath': outputPath,
      'expectedBytes': expectedBytes,
    },
  );
  if (Platform.isAndroid) {
    await _nativeChannel.invokeMethod<void>('extractAsset', {
      'assetPath': assetPath,
      'outputPath': outputPath,
      'expectedBytes': expectedBytes,
    });
    Diagnostics.log(
      'model_asset_ready',
      fields: {
        'label': label,
        'path': outputPath,
        'bytes': expectedBytes,
        'extracted': true,
        'native': true,
      },
    );
    onStatus?.call('$label ready');
    return;
  }

  final data = await rootBundle.load(assetPath);
  final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  final tmp = File('$outputPath.tmp');
  if (tmp.existsSync()) {
    tmp.deleteSync();
  }
  await tmp.writeAsBytes(bytes, flush: true);

  final written = tmp.lengthSync();
  if (written != expectedBytes) {
    tmp.deleteSync();
    throw StateError(
      '$label extraction wrote $written bytes, expected $expectedBytes',
    );
  }

  await tmp.rename(outputPath);
  Diagnostics.log(
    'model_asset_ready',
    fields: {
      'label': label,
      'path': outputPath,
      'bytes': expectedBytes,
      'extracted': true,
      'native': false,
    },
  );
  onStatus?.call('$label ready');
}
