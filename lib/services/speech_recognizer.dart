import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:vosk_flutter_service/vosk_flutter_service.dart';

typedef ResultCallback = void Function(String text);
typedef ErrorCallback = void Function(String message);

/// Abstraktion über die Spracherkennung.
///
/// Android nutzt Vosk (offline), da dort oft ein System-RecognitionService
/// fehlt (z.B. LineageOS ohne Google-Dienste). iOS/Web verwenden den
/// System-Recognizer via speech_to_text.
abstract class SpeechRecognizer {
  /// true, wenn das Mikrofon-Feature grundsätzlich nutzbar ist.
  bool get available;

  /// true, wenn vor dem ersten Start ein Modell geladen werden muss (Vosk).
  bool get requiresPreparation;

  /// true, sobald [prepare] erfolgreich war (bei System-Recognizer immer true).
  bool get isPrepared;

  /// Grundinitialisierung; setzt [available].
  Future<void> initialize();

  /// Lädt bei Bedarf das Modell (nur Vosk). Gibt Erfolg zurück.
  Future<bool> prepare();

  Future<void> start();
  Future<void> stop();
  Future<void> dispose();
}

/// Erzeugt den zur Plattform passenden Recognizer.
SpeechRecognizer createSpeechRecognizer({
  required ResultCallback onResult,
  required VoidCallback onListeningStopped,
  ErrorCallback? onError,
  String voskModelAsset = 'assets/models/vosk-model-small-de-0.15.zip',
}) {
  final useVosk = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  return useVosk
      ? VoskSpeechRecognizer(
          modelAsset: voskModelAsset,
          onResult: onResult,
          onError: onError,
        )
      : SystemSpeechRecognizer(
          onResult: onResult,
          onListeningStopped: onListeningStopped,
        );
}

/// Offline-Spracherkennung über Vosk (Android).
class VoskSpeechRecognizer implements SpeechRecognizer {
  VoskSpeechRecognizer({
    required this.modelAsset,
    required this.onResult,
    this.onError,
  });

  final String modelAsset;
  final ResultCallback onResult;
  final ErrorCallback? onError;

  SpeechService? _service;
  StreamSubscription<String>? _partialSub;
  StreamSubscription<String>? _resultSub;
  bool _available = false;
  bool _prepared = false;

  @override
  bool get available => _available;
  @override
  bool get requiresPreparation => true;
  @override
  bool get isPrepared => _prepared;

  @override
  Future<void> initialize() async {
    // Offline immer verfügbar; das Modell wird erst in [prepare] geladen.
    _available = true;
  }

  @override
  Future<bool> prepare() async {
    if (_prepared) return true;
    try {
      final modelPath = await ModelLoader().loadFromAssets(modelAsset);
      final vosk = VoskFlutterPlugin.instance();
      final model = await vosk.createModel(modelPath);
      final recognizer =
          await vosk.createRecognizer(model: model, sampleRate: 16000);
      final service = await vosk.initSpeechService(recognizer);
      _partialSub = service.onPartial().listen((json) => _emit(json, 'partial'));
      _resultSub = service.onResult().listen((json) => _emit(json, 'text'));
      _service = service;
      _prepared = true;
      return true;
    } on MicrophoneAccessDeniedException {
      _available = false;
      onError?.call('Mikrofon-Zugriff verweigert.');
      return false;
    } catch (_) {
      onError?.call('Spracherkennung konnte nicht geladen werden.');
      return false;
    }
  }

  /// Extrahiert das jeweilige Feld aus dem Vosk-JSON (z.B. {"partial":"..."}).
  void _emit(String json, String field) {
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      final text = (map[field] as String?)?.trim() ?? '';
      if (text.isNotEmpty) onResult(text);
    } catch (_) {
      // ungültiges JSON ignorieren
    }
  }

  @override
  Future<void> start() async => _service?.start();

  @override
  Future<void> stop() async => _service?.stop();

  @override
  Future<void> dispose() async {
    await _partialSub?.cancel();
    await _resultSub?.cancel();
    await _service?.stop();
    await _service?.dispose();
  }
}

/// System-Spracherkennung via speech_to_text (iOS/Web).
class SystemSpeechRecognizer implements SpeechRecognizer {
  SystemSpeechRecognizer({
    required this.onResult,
    required this.onListeningStopped,
  });

  final ResultCallback onResult;
  final VoidCallback onListeningStopped;

  final SpeechToText _speech = SpeechToText();
  bool _available = false;

  @override
  bool get available => _available;
  @override
  bool get requiresPreparation => false;
  @override
  bool get isPrepared => true;

  @override
  Future<void> initialize() async {
    try {
      _available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            onListeningStopped();
          }
        },
        onError: (_) => onListeningStopped(),
      );
    } catch (_) {
      _available = false;
    }
  }

  @override
  Future<bool> prepare() async => true;

  @override
  Future<void> start() async {
    await _speech.listen(
      onResult: (result) => onResult(result.recognizedWords),
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        localeId: 'de_DE',
      ),
    );
  }

  @override
  Future<void> stop() async => _speech.stop();

  @override
  Future<void> dispose() async => _speech.stop();
}
