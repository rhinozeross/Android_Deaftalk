// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get languageLabel => 'Sprache (Vorlesen)';

  @override
  String get readSelectedAloud => 'ausgewählten Text vorlesen';

  @override
  String get deleteMessage => 'Nachricht löschen';

  @override
  String get deleteHistory => 'Historie löschen';

  @override
  String get inputHint => 'Hier gibt man Text ein';

  @override
  String get sendText => 'Text senden';

  @override
  String get speechNotAvailable => 'Spracherkennung nicht verfügbar';

  @override
  String get loadingSpeechModel => 'Sprachmodell wird geladen …';

  @override
  String get listeningTapToStop => 'Höre zu … (zum Stoppen tippen)';

  @override
  String get startSpeechRecognition => 'Spracherkennung starten';

  @override
  String get speakerMe => 'Ich';

  @override
  String get speakerGuest => 'Gast';

  @override
  String get pleaseMakeSelection => 'Bitte treffen Sie eine Auswahl';

  @override
  String get micAccessDenied => 'Mikrofon-Zugriff verweigert.';

  @override
  String get speechLoadFailed => 'Spracherkennung konnte nicht geladen werden.';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsLanguage => 'Sprache';

  @override
  String get languageSystem => 'Systemsprache';
}
