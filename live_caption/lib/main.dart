import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'diagnostics.dart';
import 'llm/caption_engine.dart';
import 'llm/model_assets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LiveCaptionApp());
}

class LiveCaptionApp extends StatelessWidget {
  const LiveCaptionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Live Caption',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff12b886),
          brightness: Brightness.dark,
        ),
      ),
      home: const LiveCaptionScreen(),
    );
  }
}

class LiveCaptionScreen extends StatefulWidget {
  const LiveCaptionScreen({super.key});

  @override
  State<LiveCaptionScreen> createState() => _LiveCaptionScreenState();
}

class _LiveCaptionScreenState extends State<LiveCaptionScreen>
    with WidgetsBindingObserver {
  final _captionEngine = CaptionEngine();

  CameraController? _camera;
  CaptionEngineInfo? _engineInfo;
  StreamSubscription<String>? _captionSub;

  String _phase = 'starting';
  String _caption = '';
  Object? _error;
  bool _booting = true;
  bool _captioning = false;
  bool _loopRunning = false;
  Duration? _lastLatency;
  int _captures = 0;

  bool get _cameraReady => _camera?.value.isInitialized ?? false;
  bool get _ready => !_booting && _cameraReady && _captionEngine.ready;

  @override
  void initState() {
    super.initState();
    Diagnostics.log('app_start');
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _stopCaptioning();
      _disposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _bootstrap() async {
    try {
      Diagnostics.log('bootstrap_start');
      _setPhase('starting camera');
      await _initCamera();

      _setPhase('extracting model');
      final paths = await ensureSmolVlmExtracted(onStatus: _setPhase);

      _setPhase('loading SmolVLM');
      final info = await _captionEngine.load(
        modelPaths: paths,
        onPhase: _setPhase,
      );
      Diagnostics.log(
        'bootstrap_ready',
        fields: {
          'accelerator': info.primaryAcceleratorName,
          'nativeLibraryDir': info.nativeLibraryDir,
          'deviceCount': info.devices.length,
        },
      );

      if (!mounted) return;
      setState(() {
        _engineInfo = info;
        _booting = false;
        _phase = 'ready';
      });
    } catch (e, st) {
      Diagnostics.log('bootstrap_error', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() {
        _booting = false;
        _error = e;
        _phase = 'error';
      });
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      Diagnostics.log(
        'camera_list',
        fields: {
          'count': cameras.length,
          'cameras': cameras
              .map(
                (c) => {
                  'name': c.name,
                  'lensDirection': c.lensDirection.name,
                  'sensorOrientation': c.sensorOrientation,
                },
              )
              .toList(),
        },
      );
      if (cameras.isEmpty) {
        throw StateError('no cameras found');
      }

      final selected = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final old = _camera;
      _camera = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await old?.dispose();
      await _camera!.initialize();
      Diagnostics.log(
        'camera_ready',
        fields: {
          'name': selected.name,
          'lensDirection': selected.lensDirection.name,
          'previewWidth': _camera!.value.previewSize?.width,
          'previewHeight': _camera!.value.previewSize?.height,
        },
      );

      if (mounted) setState(() {});
    } on CameraException catch (e) {
      Diagnostics.log(
        'camera_error',
        fields: {'code': e.code, 'description': e.description},
      );
      throw StateError('${e.code}: ${e.description ?? 'camera error'}');
    }
  }

  void _setPhase(String phase) {
    Diagnostics.log('phase', fields: {'phase': phase});
    if (!mounted) return;
    setState(() => _phase = phase);
  }

  Future<void> _toggleCaptioning() async {
    if (_captioning) {
      await _stopCaptioning();
      return;
    }
    if (!_ready || _loopRunning) return;
    setState(() {
      _captioning = true;
      _caption = '';
      _error = null;
    });
    Diagnostics.log('captioning_start_requested');
    unawaited(_runCaptionLoop());
  }

  Future<void> _stopCaptioning() async {
    if (!_captioning && _captionSub == null) return;
    setState(() => _captioning = false);
    await _captionSub?.cancel();
    _captionSub = null;
    Diagnostics.log('captioning_stop_requested');
  }

  Future<void> _runCaptionLoop() async {
    if (_loopRunning) return;
    _loopRunning = true;
    try {
      while (mounted && _captioning) {
        final camera = _camera;
        if (camera == null || !camera.value.isInitialized) {
          throw StateError('camera is not ready');
        }
        if (camera.value.isTakingPicture) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          continue;
        }

        final image = await camera.takePicture();
        Diagnostics.log(
          'camera_capture',
          fields: {'path': image.path, 'captureIndex': _captures + 1},
        );
        if (!mounted || !_captioning) {
          await _deleteTempImage(image.path);
          break;
        }

        final watch = Stopwatch()..start();
        final done = Completer<void>();
        _captionSub = _captionEngine
            .captionImage(image.path)
            .listen(
              (text) {
                if (!mounted) return;
                setState(() => _caption = text);
              },
              onError: (Object e, StackTrace st) {
                Diagnostics.log('caption_error', error: e, stackTrace: st);
                if (mounted) {
                  setState(() {
                    _error = e;
                    _phase = 'error';
                    _captioning = false;
                  });
                }
                if (!done.isCompleted) done.complete();
              },
              onDone: () {
                if (!done.isCompleted) done.complete();
              },
            );

        await done.future;
        await _captionSub?.cancel();
        _captionSub = null;
        watch.stop();
        await _deleteTempImage(image.path);

        if (!mounted) break;
        setState(() {
          _captures += 1;
          _lastLatency = watch.elapsed;
        });
        Diagnostics.log(
          'caption_loop_iteration_done',
          fields: {
            'captureIndex': _captures,
            'elapsedMs': watch.elapsedMilliseconds,
          },
        );
      }
    } catch (e, st) {
      Diagnostics.log('caption_loop_error', error: e, stackTrace: st);
      if (mounted) {
        setState(() {
          _error = e;
          _phase = 'error';
          _captioning = false;
        });
      }
    } finally {
      _loopRunning = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _deleteTempImage(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<void> _disposeCamera() async {
    final camera = _camera;
    _camera = null;
    await camera?.dispose();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_captionSub?.cancel());
    unawaited(_camera?.dispose());
    unawaited(_captionEngine.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildPreview(),
          _buildTopStatus(theme),
          _buildCaptionOverlay(theme),
          _buildControls(theme),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Center(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: camera.value.previewSize!.height,
          height: camera.value.previewSize!.width,
          child: CameraPreview(camera),
        ),
      ),
    );
  }

  Widget _buildTopStatus(ThemeData theme) {
    final info = _engineInfo;
    final accelerator = info == null
        ? 'loading'
        : (info.primaryAcceleratorName ?? 'none detected');
    final loadTime = info == null ? null : _formatDuration(info.loadTime);
    final latency = _lastLatency == null
        ? null
        : _formatDuration(_lastLatency!);
    final status = _error == null
        ? _phase
        : _error.toString().replaceFirst('Bad state: ', '');

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          color: Colors.black.withValues(alpha: 0.58),
          child: DefaultTextStyle(
            style: theme.textTheme.bodySmall!.copyWith(
              color: Colors.white,
              height: 1.25,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall!.copyWith(
                    color: _error == null
                        ? Colors.white
                        : theme.colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text('accelerator: $accelerator'),
                    if (info != null) Text('devices: ${info.devices.length}'),
                    if (loadTime != null) Text('load: $loadTime'),
                    if (latency != null) Text('last: $latency'),
                    Text('frames: $_captures'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCaptionOverlay(ThemeData theme) {
    final text = _caption.isEmpty ? (_captioning ? '...' : '') : _caption;
    if (text.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 116),
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineSmall!.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            shadows: const [
              Shadow(offset: Offset(0, 1), blurRadius: 12, color: Colors.black),
              Shadow(offset: Offset(0, 2), blurRadius: 20, color: Colors.black),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls(ThemeData theme) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: _ready ? _toggleCaptioning : null,
                icon: Icon(_captioning ? Icons.stop : Icons.play_arrow),
                label: Text(_captioning ? 'Stop' : 'Start'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(144, 54),
                  textStyle: theme.textTheme.titleMedium,
                  backgroundColor: _captioning
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                onPressed: _copyDiagnostics,
                tooltip: 'Copy logs',
                icon: const Icon(Icons.copy),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copyDiagnostics() async {
    await Diagnostics.copyToClipboard();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Diagnostics copied')));
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds >= 1) {
      return '${(duration.inMilliseconds / 1000).toStringAsFixed(1)}s';
    }
    return '${duration.inMilliseconds}ms';
  }
}
