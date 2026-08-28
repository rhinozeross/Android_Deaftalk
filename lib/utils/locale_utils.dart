/// Reine Hilfsfunktionen rund um die Locale-Codes der TTS-Engine.
///
/// Bewusst frei von Flutter-/Plugin-Abhängigkeiten, damit unit-testbar.
library;

/// Einheitliches Anzeige-Format im Schema "de-DE":
/// Sprache klein, Region groß. eSpeak-Sondervarianten wie
/// "en-GB-gbclan", "en-US-x-lvariant-nyc" oder "vi-VN-central" werden auf
/// die Basis-Locale (Sprache[-Region]) gekürzt.
String normalizeLocale(String code) {
  final parts = code.split(RegExp('[-_]'));
  final lang = parts[0].toLowerCase();
  if (parts.length >= 2) {
    final region = parts[1];
    // nur echte Regionen (2 Buchstaben oder 3 Ziffern) übernehmen,
    // Erweiterungs-Marker wie "x" ignorieren
    final isRegion = RegExp(r'^[A-Za-z]{2}$').hasMatch(region) ||
        RegExp(r'^[0-9]{3}$').hasMatch(region);
    if (isRegion) return '$lang-${region.toUpperCase()}';
  }
  return lang;
}

/// Baut aus den Roh-Codes der Engine eine deduplizierte, nach Anzeige
/// sortierte Liste repräsentativer Codes. Anzeige via [normalizeLocale];
/// pro Anzeige-Label bleibt der erste echte Engine-Code erhalten.
List<String> buildLanguageList(Iterable<String> rawCodes) {
  final byLabel = <String, String>{};
  for (final code in rawCodes) {
    byLabel.putIfAbsent(normalizeLocale(code), () => code);
  }
  return byLabel.values.toList()
    ..sort((a, b) => normalizeLocale(a).compareTo(normalizeLocale(b)));
}

/// Wählt initial die System-Standard-Locale.
/// Reihenfolge: exakte System-Locale (z.B. de-DE) -> gleiche Sprache mit
/// anderer Region -> Fallback Englisch (en-US bzw. irgendein en-*) ->
/// erster verfügbarer Eintrag. Vergleich case-insensitiv.
String? pickInitialLanguage(
  List<String> list, {
  required String languageCode,
  String? countryCode,
}) {
  if (list.isEmpty) return null;
  final lang = languageCode.toLowerCase();
  final sysFull = (countryCode != null && countryCode.isNotEmpty)
      ? '$lang-${countryCode.toLowerCase()}'
      : lang;
  final lower = list.map((e) => e.toLowerCase()).toList();

  // 1) exakte System-Locale, z.B. de-DE
  var i = lower.indexOf(sysFull);
  if (i >= 0) return list[i];

  // 2) gleiche Sprache, andere Region, z.B. de-AT wenn de-DE fehlt
  i = lower.indexWhere((e) => e == lang || e.startsWith('$lang-'));
  if (i >= 0) return list[i];

  // 3) Fallback Englisch
  i = lower.indexOf('en-us');
  if (i >= 0) return list[i];
  i = lower.indexWhere((e) => e == 'en' || e.startsWith('en-'));
  if (i >= 0) return list[i];

  // 4) sonst erster Eintrag
  return list.first;
}
