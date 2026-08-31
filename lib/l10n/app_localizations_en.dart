// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get languageLabel => 'Language (read aloud)';

  @override
  String get readSelectedAloud => 'Read selected text aloud';

  @override
  String get deleteMessage => 'Delete message';

  @override
  String get deleteHistory => 'Delete history';

  @override
  String get inputHint => 'Enter your text here';

  @override
  String get sendText => 'Send text';

  @override
  String get speechNotAvailable => 'Speech recognition not available';

  @override
  String get loadingSpeechModel => 'Loading speech model …';

  @override
  String get listeningTapToStop => 'Listening … (tap to stop)';

  @override
  String get startSpeechRecognition => 'Start speech recognition';

  @override
  String get speakerMe => 'Me';

  @override
  String get speakerGuest => 'Guest';

  @override
  String get pleaseMakeSelection => 'Please make a selection';

  @override
  String get micAccessDenied => 'Microphone access denied.';

  @override
  String get speechLoadFailed => 'Could not load speech recognition.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageSystem => 'System default';
}
