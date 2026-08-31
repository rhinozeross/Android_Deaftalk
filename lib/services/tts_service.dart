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

  /// Lädt die verfügbaren Sprachen und wählt die passende Locale vor.
  Future<void> loadLanguages(Locale locale) async {
    try {
      final langs = await _tts.getLanguages;
      final raw = (langs as List).map((e) => e.toString());
      languages = buildLanguageList(raw);
      selectForLocale(locale);
    } catch (_) {
      // getLanguages kann auf manchen Plattformen fehlschlagen
    }
  }

  /// Wählt (ohne Neuladen) die zur [locale] passende Sprache aus der bereits
  /// geladenen Liste – z.B. wenn die App-Sprache umgestellt wird.
  void selectForLocale(Locale locale) {
    if (languages.isEmpty) return;
    selectedLanguage = pickInitialLanguage(
      languages,
      languageCode: locale.languageCode,
      countryCode: locale.countryCode,
    );
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
