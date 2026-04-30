import 'package:llama_cpp_dart/llama_cpp_dart.dart';

import '../diagnostics.dart';
import 'model_assets.dart';
import 'platform_config.dart';

const _captionPrompt =
    'Write one short present-tense caption for this camera image. '
    'Use fewer than 20 tokens. Mention only visible things.\n<__media__>';

class CaptionEngineInfo {
  const CaptionEngineInfo({
    required this.loadTime,
    required this.supportsVision,
    required this.primaryAcceleratorName,
    required this.devices,
    required this.nativeLibraryDir,
  });

  final Duration loadTime;
  final bool supportsVision;
  final String? primaryAcceleratorName;
  final List<BackendDevice> devices;
  final String? nativeLibraryDir;
}

class CaptionEngine {
  LlamaEngine? _engine;
  CaptionEngineInfo? _info;

  CaptionEngineInfo? get info => _info;
  bool get ready => _engine != null && (_info?.supportsVision ?? false);

  Future<CaptionEngineInfo> load({
    required ExtractedModelPaths modelPaths,
    void Function(String phase)? onPhase,
  }) async {
    if (_engine != null && _info != null) {
      return _info!;
    }

    final watch = Stopwatch()..start();
    onPhase?.call('resolving platform');
    final platform = await resolvePlatformConfig();

    onPhase?.call('loading native runtime');
    Diagnostics.log(
      'load_native_start',
      fields: {
        'libraryPath': platform.libraryPath,
        'backendDirectory': platform.nativeLibraryDir,
        'llamaLibraryAlreadyLoaded': LlamaLibrary.isLoaded,
      },
    );
    if (!LlamaLibrary.isLoaded) {
      LlamaLibrary.load(
        path: platform.libraryPath,
        backendDirectory: platform.nativeLibraryDir,
      );
    }

    onPhase?.call('loading SmolVLM');
    Diagnostics.log(
      'load_model_start',
      fields: {
        'modelPath': modelPaths.modelPath,
        'mmprojPath': modelPaths.mmprojPath,
      },
    );
    final engine = await LlamaEngine.spawn(
      libraryPath: platform.libraryPath,
      backendDirectory: platform.nativeLibraryDir,
      modelParams: ModelParams(
        path: modelPaths.modelPath,
        gpuLayers: platform.gpuLayers,
      ),
      contextParams: const ContextParams(nCtx: 2048, nBatch: 512, nUbatch: 512),
      multimodalParams: MultimodalParams(mmprojPath: modelPaths.mmprojPath),
    );
    watch.stop();

    final info = CaptionEngineInfo(
      loadTime: watch.elapsed,
      supportsVision: engine.supportsVision,
      primaryAcceleratorName: engine.primaryAcceleratorName,
      devices: engine.devices,
      nativeLibraryDir: platform.nativeLibraryDir,
    );
    Diagnostics.log(
      'engine_ready',
      fields: {
        'loadMs': watch.elapsedMilliseconds,
        'supportsVision': engine.supportsVision,
        'supportsAudio': engine.supportsAudio,
        'audioSampleRate': engine.audioSampleRate,
        'canShift': engine.canShift,
        'multimodalLoaded': engine.multimodalLoaded,
        'accelerator': engine.primaryAcceleratorName,
        'deviceCount': engine.devices.length,
        'devices': engine.devices
            .map(
              (d) => {
                'registryName': d.registryName,
                'name': d.name,
                'type': d.type.name,
              },
            )
            .toList(),
      },
    );

    if (!engine.supportsVision) {
      await engine.dispose();
      throw StateError('SmolVLM projector loaded, but vision is unavailable');
    }

    _engine = engine;
    _info = info;
    onPhase?.call('ready');
    return info;
  }

  Stream<String> captionImage(String imagePath) async* {
    final engine = _engine;
    if (engine == null) {
      throw StateError('CaptionEngine is not loaded');
    }

    final session = await engine.createSession();
    final buffer = StringBuffer();
    final watch = Stopwatch()..start();
    Diagnostics.log('caption_start', fields: {'imagePath': imagePath});
    try {
      await for (final event in session.generate(
        prompt: _captionPrompt,
        addSpecial: true,
        parseSpecial: true,
        sampler: SamplerParams.greedyDefault,
        maxTokens: 20,
        media: [LlamaMedia.imageFile(imagePath)],
      )) {
        switch (event) {
          case TokenEvent():
            if (event.text.isNotEmpty) {
              buffer.write(event.text);
              yield _normalizeCaption(buffer.toString(), partial: true);
            }
          case ShiftEvent():
            break;
          case DoneEvent():
            if (event.trailingText.isNotEmpty) {
              buffer.write(event.trailingText);
            }
            yield _normalizeCaption(buffer.toString());
        }
      }
      watch.stop();
      Diagnostics.log(
        'caption_done',
        fields: {
          'elapsedMs': watch.elapsedMilliseconds,
          'text': _normalizeCaption(buffer.toString()),
        },
      );
    } finally {
      await session.dispose();
    }
  }

  Future<void> dispose() async {
    await _engine?.dispose();
    _engine = null;
    _info = null;
  }
}

String _normalizeCaption(String raw, {bool partial = false}) {
  var text = raw
      .replaceAll('<__media__>', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (text.isEmpty) return text;

  final sentenceEnd = text.indexOf(RegExp(r'[.!?]'));
  if (sentenceEnd >= 0) {
    text = text.substring(0, sentenceEnd + 1).trim();
  }

  if (!partial) {
    final words = text.split(RegExp(r'\s+'));
    if (words.length > 18) {
      text = '${words.take(18).join(' ')}.';
    } else if (!RegExp(r'[.!?]$').hasMatch(text)) {
      text = '$text.';
    }
  }
  return text;
}
