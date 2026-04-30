import 'package:flutter/foundation.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

import '../data/models/model_bundle.dart';
import 'platform_paths.dart';

/// Singleton owner of the active [LlamaEngine]. At most one engine is
/// alive at a time. Switching the active model requires [activate]ing the
/// new bundle; that disposes the old engine and spawns a new one.
class EngineHolder extends ChangeNotifier {
  EngineHolder._();
  static final EngineHolder _i = EngineHolder._();
  static EngineHolder get instance => _i;

  LlamaEngine? _engine;
  ModelBundle? _activeBundle;
  bool _busy = false;
  String _phase = 'idle';
  Object? _error;

  LlamaEngine? get engine => _engine;
  ModelBundle? get activeBundle => _activeBundle;
  bool get busy => _busy;
  bool get ready => _engine != null && !_busy;
  String get phase => _phase;
  Object? get error => _error;

  List<BackendDevice> get devices => _engine?.devices ?? const [];
  String? get primaryAcceleratorName => _engine?.primaryAcceleratorName;

  void _setPhase(String p, {Object? error}) {
    _phase = p;
    _error = error;
    notifyListeners();
  }

  /// Spawn (or respawn) the engine for [bundle]. Idempotent if [bundle] is
  /// already active.
  Future<void> activate(ModelBundle bundle) async {
    if (_activeBundle?.id == bundle.id && _engine != null) return;
    if (_busy) {
      throw StateError('engine activation already in flight');
    }
    _busy = true;
    _setPhase('disposing previous');
    try {
      await _engine?.dispose();
      _engine = null;

      _setPhase('resolving platform');
      final cfg = await resolvePlatformConfig();

      _setPhase('loading lib');
      if (!cfg.spawnFromProcess) {
        LlamaLibrary.load(path: cfg.libraryPath);
      }

      _setPhase('spawning engine');
      final modelParams =
          ModelParams(path: bundle.modelPath, gpuLayers: cfg.gpuLayers);
      final contextParams = ContextParams(
        nCtx: bundle.nCtx,
        nBatch: bundle.nBatch,
        nUbatch: bundle.nUbatch,
        flashAttn: switch (bundle.flashAttn) {
          FlashAttnMode.auto => FlashAttention.auto,
          FlashAttnMode.on => FlashAttention.on,
          FlashAttnMode.off => FlashAttention.off,
        },
      );
      final mmproj = bundle.mmprojPath == null
          ? null
          : MultimodalParams(mmprojPath: bundle.mmprojPath!);

      final eng = cfg.spawnFromProcess
          ? await LlamaEngine.spawnFromProcess(
              modelParams: modelParams,
              contextParams: contextParams,
              multimodalParams: mmproj,
            )
          : await LlamaEngine.spawn(
              libraryPath: cfg.libraryPath,
              modelParams: modelParams,
              contextParams: contextParams,
              multimodalParams: mmproj,
            );

      _engine = eng;
      _activeBundle = bundle;
      _setPhase('ready');
    } catch (e) {
      _setPhase('error', error: e);
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> shutdown() async {
    await _engine?.dispose();
    _engine = null;
    _activeBundle = null;
    _setPhase('idle');
  }
}
