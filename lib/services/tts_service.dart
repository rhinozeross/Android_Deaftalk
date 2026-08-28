import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../utils/locale_utils.dart';

/// Kapselt Text-to-Speech (Vorlesen): Engine-Initialisierung,
/// aufbereitete Sprachliste und Ausgabe.
class TtsService {
  final FlutterTts _tts = FlutterTts();

  /// Deduplizierte, sortierte Liste repräsentativer Engine-Codes.
  List<String> languages = [];

  /// Aktuell gewählter Engine-Code (Wert der Auswahl).
  String? selectedLanguage;

  /// Handler registrieren. [onSpeakingDone] wird gerufen, sobald die
  /// Ausgabe endet, abgebrochen wird oder fehlschlägt.
  void init({required VoidCallback onSpeakingDone}) {
    _tts.setCompletionHandler(onSpeakingDone);
    _tts.setCancelHandler(onSpeakingDone);
    _tts.setErrorHandler((_) => onSpeakingDone());
  }

  /// Lädt die verfügbaren Sprachen und wählt die System-Locale vor.
  Future<void> loadLanguages(Locale systemLocale) async {
    try {
      final langs = await _tts.getLanguages;
      final raw = (langs as List).map((e) => e.toString());
      languages = buildLanguageList(raw);
      selectedLanguage = pickInitialLanguage(
        languages,
        languageCode: systemLocale.languageCode,
        countryCode: systemLocale.countryCode,
      );
    } catch (_) {
      // getLanguages kann auf manchen Plattformen fehlschlagen
    }
  }

  /// Liest [text] in der gewählten Sprache vor.
  Future<void> speak(String text) async {
    if (selectedLanguage != null) {
      await _tts.setLanguage(selectedLanguage!);
    }
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();
}
