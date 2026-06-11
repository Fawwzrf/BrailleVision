// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/scanner/presentation/screens/scanner_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(AppTheme.systemUiStyle);
  runApp(const ProviderScope(child: BrailleVisionApp()));
}

class BrailleVisionApp extends StatelessWidget {
  const BrailleVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BrailleVision',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const ScannerScreen(),
    );
  }
}
