// lib/features/scanner/services/tts_service.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../../core/constants/app_constants.dart';

enum TtsState { idle, playing, stopped, paused }

class TtsService {
  TtsService();

  final FlutterTts _flutterTts = FlutterTts();
  TtsState _state = TtsState.idle;
  TtsState get state => _state;

  ValueNotifier<TtsState> stateNotifier = ValueNotifier(TtsState.idle);

  Future<void> initialize() async {
    await _flutterTts.setLanguage(AppConstants.ttsDefaultLanguage);
    await _flutterTts.setSpeechRate(AppConstants.ttsDefaultRate);
    await _flutterTts.setVolume(AppConstants.ttsDefaultVolume);
    await _flutterTts.setPitch(AppConstants.ttsDefaultPitch);

    _flutterTts.setStartHandler(() {
      _state = TtsState.playing;
      stateNotifier.value = _state;
    });

    _flutterTts.setCompletionHandler(() {
      _state = TtsState.idle;
      stateNotifier.value = _state;
    });

    _flutterTts.setCancelHandler(() {
      _state = TtsState.stopped;
      stateNotifier.value = _state;
    });

    _flutterTts.setErrorHandler((msg) {
      debugPrint('[TtsService] Error: $msg');
      _state = TtsState.idle;
      stateNotifier.value = _state;
    });
  }

  /// Speaks the provided text. If TTS is already playing, it stops first.
  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    if (_state == TtsState.playing) {
      await stop();
    }
    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    _state = TtsState.stopped;
    stateNotifier.value = _state;
  }

  /// Sets TTS language. Useful for multi-language Braille support.
  ///
  /// ─── INTEGRATION POINT ──────────────────────────────────────
  /// Call this if your ML model detects document language.
  Future<void> setLanguage(String languageCode) async {
    await _flutterTts.setLanguage(languageCode);
  }

  Future<void> dispose() async {
    await _flutterTts.stop();
    stateNotifier.dispose();
  }
}
