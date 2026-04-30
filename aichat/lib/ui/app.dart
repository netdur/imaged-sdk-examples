import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';

import '../llm/engine_holder.dart';
import 'common/theme.dart';
import 'common/theme_controller.dart';
import 'home/home_screen.dart';

class AiChatApp extends StatefulWidget {
  const AiChatApp({super.key});

  @override
  State<AiChatApp> createState() => _AiChatAppState();
}

class _AiChatAppState extends State<AiChatApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onExitRequested: _onExitRequested);
    ThemeController.instance.addListener(_onThemeChange);
  }

  void _onThemeChange() {
    if (mounted) setState(() {});
  }

  Future<AppExitResponse> _onExitRequested() async {
    try {
      await EngineHolder.instance.shutdown();
    } catch (_) {}
    return AppExitResponse.exit;
  }

  @override
  void dispose() {
    ThemeController.instance.removeListener(_onThemeChange);
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'aichat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeController.instance.mode,
      themeAnimationDuration: const Duration(milliseconds: 240),
      themeAnimationCurve: Curves.easeOutCubic,
      home: const HomeScreen(),
    );
  }
}
