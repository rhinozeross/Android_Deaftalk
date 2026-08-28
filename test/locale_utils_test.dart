import 'package:deaftalk/utils/locale_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeLocale', () {
    test('reine Sprache bleibt klein', () {
      expect(normalizeLocale('de'), 'de');
      expect(normalizeLocale('DE'), 'de');
    });

    test('Region wird großgeschrieben', () {
      expect(normalizeLocale('en-GB'), 'en-GB');
      expect(normalizeLocale('en-gb'), 'en-GB');
      expect(normalizeLocale('pt_br'), 'pt-BR');
    });

    test('eSpeak-Sondervarianten werden auf Basis gekürzt', () {
      expect(normalizeLocale('en-GB-gbclan'), 'en-GB');
      expect(normalizeLocale('en-US-x-lvariant-nyc'), 'en-US');
      expect(normalizeLocale('vi-VN-central'), 'vi-VN');
    });

    test('numerische UN-Region wird beibehalten', () {
      expect(normalizeLocale('es-419'), 'es-419');
    });
  });

  group('buildLanguageList', () {
    test('dedupliziert nach Anzeige-Label und sortiert', () {
      final result = buildLanguageList(
        ['de', 'en-GB', 'en-GB-gbclan', 'vi-VN-central', 'vi-VN-south'],
      );
      // en-GB-gbclan -> en-GB (Dublette), vi-VN-* -> vi-VN (eine)
      expect(result.map(normalizeLocale).toList(), ['de', 'en-GB', 'vi-VN']);
    });

    test('behält ersten echten Engine-Code pro Label', () {
      final result = buildLanguageList(['vi-VN-central', 'vi-VN-south']);
      expect(result, ['vi-VN-central']); // Anzeige wäre vi-VN
    });
  });

  group('pickInitialLanguage', () {
    test('exakte System-Locale gewinnt', () {
      final list = ['de', 'de-DE', 'en-US'];
      expect(
        pickInitialLanguage(list, languageCode: 'de', countryCode: 'DE'),
        'de-DE',
      );
    });

    test('gleiche Sprache ohne passende Region', () {
      final list = ['de', 'en-US', 'fr-FR'];
      expect(
        pickInitialLanguage(list, languageCode: 'de', countryCode: 'DE'),
        'de',
      );
    });

    test('Fallback Englisch, wenn Sprache fehlt', () {
      final list = ['fr-FR', 'en-US', 'it'];
      expect(
        pickInitialLanguage(list, languageCode: 'pt', countryCode: 'BR'),
        'en-US',
      );
    });

    test('sonst erster Eintrag', () {
      final list = ['af', 'zu'];
      expect(
        pickInitialLanguage(list, languageCode: 'pt', countryCode: 'BR'),
        'af',
      );
    });

    test('leere Liste -> null', () {
      expect(
        pickInitialLanguage([], languageCode: 'de', countryCode: 'DE'),
        isNull,
      );
    });
  });
}
