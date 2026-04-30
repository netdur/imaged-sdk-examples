import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class Diagnostics {
  Diagnostics._();

  static final List<String> _lines = <String>[];

  static void log(
    String event, {
    Map<String, Object?> fields = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  }) {
    final payload = <String, Object?>{
      'ts': DateTime.now().toIso8601String(),
      'event': event,
      ...fields,
      if (error != null) 'error': error.toString(),
      if (stackTrace != null) 'stack': stackTrace.toString(),
    };
    final line = 'LC_DIAG ${jsonEncode(payload)}';
    _lines.add(line);
    if (_lines.length > 400) {
      _lines.removeRange(0, _lines.length - 400);
    }
    debugPrint(line);
  }

  static String dump() => _lines.join('\n');

  static Future<void> copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: dump()));
  }
}
