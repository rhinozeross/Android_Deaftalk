import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Verwaltet die manuell gewählte App-Sprache.
///
/// `null` bedeutet "Systemsprache folgen". Die Auswahl wird persistiert,
/// damit sie einen Neustart übersteht.
class LocaleController extends ChangeNotifier {
  static const _key = 'app_locale';

  Locale? _locale;
  Locale? get locale => _locale;

  /// Gespeicherte Auswahl laden (beim App-Start aufrufen).
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    if (code != null && code.isNotEmpty) {
      _locale = Locale(code);
      notifyListeners();
    }
  }

  /// Sprache setzen ([locale] == null → Systemsprache) und speichern.
  Future<void> setLocale(Locale? locale) async {
    if (_locale?.languageCode == locale?.languageCode) return;
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, locale.languageCode);
    }
  }
}
