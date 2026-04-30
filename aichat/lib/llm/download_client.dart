import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

class DownloadProgress {
  DownloadProgress({
    required this.bytesDownloaded,
    required this.bytesTotal,
    required this.bytesPerSecond,
  });
  final int bytesDownloaded;
  final int? bytesTotal;
  final double bytesPerSecond;

  double? get fraction =>
      bytesTotal == null || bytesTotal == 0 ? null : bytesDownloaded / bytesTotal!;
}

/// Streamed HTTP GET with progress events. Writes to `<dest>.partial` and
/// renames to `dest` atomically on completion.
class FileDownload {
  FileDownload({
    required this.url,
    required this.destPath,
    this.headers,
  });

  final Uri url;
  final String destPath;
  final Map<String, String>? headers;

  final _ctl = StreamController<DownloadProgress>.broadcast();
  Stream<DownloadProgress> get progress => _ctl.stream;

  http.Client? _client;
  bool _cancelled = false;

  Future<void> run() async {
    _client = http.Client();
    final partialPath = '$destPath.partial';
    final partialFile = File(partialPath);
    if (partialFile.existsSync()) await partialFile.delete();

    try {
      final req = http.Request('GET', url);
      if (headers != null) req.headers.addAll(headers!);
      final resp = await _client!.send(req);

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw HttpException(
            'GET $url: status ${resp.statusCode}');
      }

      final total = resp.contentLength;
      final sink = partialFile.openWrite();
      var downloaded = 0;
      var lastTick = DateTime.now();
      var lastTickBytes = 0;

      try {
        await for (final chunk in resp.stream) {
          if (_cancelled) {
            sink.add([]);
            await sink.close();
            await partialFile.delete().catchError((_) => partialFile);
            throw const _Cancelled();
          }
          sink.add(chunk);
          downloaded += chunk.length;
          final now = DateTime.now();
          final dt = now.difference(lastTick).inMilliseconds;
          if (dt >= 250) {
            final bps = (downloaded - lastTickBytes) / (dt / 1000.0);
            _ctl.add(DownloadProgress(
              bytesDownloaded: downloaded,
              bytesTotal: total,
              bytesPerSecond: bps,
            ));
            lastTick = now;
            lastTickBytes = downloaded;
          }
        }
        await sink.close();
      } catch (e) {
        await sink.close();
        await partialFile.delete().catchError((_) => partialFile);
        rethrow;
      }

      // Final progress + atomic rename.
      _ctl.add(DownloadProgress(
        bytesDownloaded: downloaded,
        bytesTotal: total,
        bytesPerSecond: 0,
      ));
      await partialFile.rename(destPath);
      await _ctl.close();
    } finally {
      _client?.close();
    }
  }

  void cancel() {
    _cancelled = true;
    _client?.close();
    if (!_ctl.isClosed) _ctl.close();
  }
}

class _Cancelled implements Exception {
  const _Cancelled();
  @override
  String toString() => 'download cancelled';
}
