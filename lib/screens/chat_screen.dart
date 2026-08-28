import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:vosk_flutter_service/vosk_flutter_service.dart';

import '../main.dart';
import '../models/eintrag.dart';
import '../services/history_store.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _speech = SpeechToText();
  final HistoryStore _store = HistoryStore();
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  final List<Eintrag> _messages = [];

  List<String> _languages = [];
  String? _selectedLanguage;

  bool _fromMeOrYou = true; // true = Ich, false = Gast
  String _vorleseText = ''; // aktuell ausgewählter Text zum Vorlesen
  bool _isSpeaking = false; // Vorlesen-Button während Ausgabe deaktivieren

  bool _speechAvailable = false;
  bool _isListening = false;

  // --- Offline-Spracherkennung (Vosk) für Android ---
  // Auf Android fehlt oft ein System-RecognitionService (z.B. LineageOS ohne
  // Google-Dienste). Daher nutzen wir dort Vosk offline. iOS/Web verwenden
  // weiterhin den System-Recognizer via speech_to_text.
  static const String _voskModelAsset =
      'assets/models/vosk-model-small-de-0.15.zip';
  bool get _useVosk =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  SpeechService? _voskService;
  bool _voskReady = false; // Modell + Service initialisiert
  bool _voskLoading = false; // Modell wird gerade geladen
  StreamSubscription<String>? _voskPartialSub;
  StreamSubscription<String>? _voskResultSub;

  String _appVersion = ''; // App-Version aus pubspec (zur Laufzeit gelesen)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initTts();
    _initSpeech();
    _initVersion();
    _loadHistory();
  }

  Future<void> _initVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _appVersion = 'v${info.version} (${info.buildNumber})');
      }
    } catch (_) {
      // Version optional – bei Fehler einfach nicht anzeigen
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tts.stop();
    _voskPartialSub?.cancel();
    _voskResultSub?.cancel();
    _voskService?.stop();
    _voskService?.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // entspricht onStop() -> Save() im Original
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _store.save(_messages);
    }
  }

  Future<void> _initTts() async {
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _tts.setCancelHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _tts.setErrorHandler((_) {
      if (mounted) setState(() => _isSpeaking = false);
    });

    try {
      final langs = await _tts.getLanguages;
      final raw = (langs as List).map((e) => e.toString()).toList();
      // Auf einheitliches Schema normalisieren und deduplizieren.
      // byLabel: normalisiertes Label (z.B. "en-GB") -> erster echter
      // Engine-Code (den die Engine sicher akzeptiert).
      final byLabel = <String, String>{};
      for (final code in raw) {
        byLabel.putIfAbsent(_displayLocale(code), () => code);
      }
      final list = byLabel.values.toList()
        ..sort((a, b) => _displayLocale(a).compareTo(_displayLocale(b)));
      final initial = _pickInitialLanguage(list);
      if (mounted) {
        setState(() {
          _languages = list;
          _selectedLanguage = initial;
        });
      }
    } catch (_) {
      // getLanguages kann auf manchen Plattformen fehlschlagen
    }
  }

  /// Wählt initial die System-Standard-Locale des Geräts.
  /// Reihenfolge: exakte System-Locale (z.B. de-DE) -> gleiche Sprache mit
  /// anderer Region -> Fallback Englisch (en-US bzw. irgendein en-*) ->
  /// erster verfügbarer Eintrag. Vergleich case-insensitiv.
  String? _pickInitialLanguage(List<String> list) {
    if (list.isEmpty) return null;
    final sys = WidgetsBinding.instance.platformDispatcher.locale;
    final lang = sys.languageCode.toLowerCase();
    final sysFull = (sys.countryCode != null && sys.countryCode!.isNotEmpty)
        ? '$lang-${sys.countryCode!.toLowerCase()}'
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

  /// Einheitliches Anzeige-Format im Schema "de-DE":
  /// Sprache klein, Region groß. eSpeak-Sondervarianten wie
  /// "en-GB-gbclan", "en-US-x-lvariant-nyc" oder "vi-VN-central" werden auf
  /// die Basis-Locale (Sprache[-Region]) gekürzt.
  String _displayLocale(String code) {
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

  Future<void> _initSpeech() async {
    // Android: Vosk (offline). Das Modell wird erst beim ersten Mikrofon-Tipp
    // geladen (spart Startzeit); der Button ist trotzdem sofort aktiv.
    if (_useVosk) {
      if (mounted) setState(() => _speechAvailable = true);
      return;
    }
    // iOS/Web: System-Recognizer via speech_to_text
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _isListening = false);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _isListening = false);
        },
      );
      if (mounted) setState(() => _speechAvailable = available);
    } catch (_) {
      if (mounted) setState(() => _speechAvailable = false);
    }
  }

  /// Lädt das gebündelte deutsche Vosk-Modell und startet den Sprachdienst.
  /// Wird nur einmal (lazy) beim ersten Mikrofon-Tipp ausgeführt.
  Future<void> _initVosk() async {
    if (_voskReady || _voskLoading) return;
    setState(() => _voskLoading = true);
    try {
      final modelPath = await ModelLoader().loadFromAssets(_voskModelAsset);
      final vosk = VoskFlutterPlugin.instance();
      final model = await vosk.createModel(modelPath);
      final recognizer =
          await vosk.createRecognizer(model: model, sampleRate: 16000);
      final service = await vosk.initSpeechService(recognizer);

      // Live-Zwischenergebnisse ins Eingabefeld schreiben.
      _voskPartialSub = service.onPartial().listen((json) {
        final text = _extractVoskText(json, 'partial');
        if (text.isNotEmpty && mounted) {
          setState(() => _input.text = text);
        }
      });
      // Endergebnis übernehmen.
      _voskResultSub = service.onResult().listen((json) {
        final text = _extractVoskText(json, 'text');
        if (text.isNotEmpty && mounted) {
          setState(() => _input.text = text);
        }
      });

      _voskService = service;
      if (mounted) {
        setState(() {
          _voskReady = true;
          _voskLoading = false;
        });
      }
    } on MicrophoneAccessDeniedException {
      if (mounted) {
        setState(() {
          _voskLoading = false;
          _speechAvailable = false;
        });
        _showSnack('Mikrofon-Zugriff verweigert.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _voskLoading = false);
        _showSnack('Spracherkennung konnte nicht geladen werden.');
      }
    }
  }

  /// Extrahiert das jeweilige Feld aus dem Vosk-JSON (z.B. {"partial":"..."}).
  String _extractVoskText(String json, String field) {
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return (map[field] as String?)?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _loadHistory() async {
    final loaded = await _store.load();
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(loaded);
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  // ---- Aktionen (entsprechen den onClick-Methoden im Original) ----

  void _onSend() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(Eintrag(
        eintrag: text,
        fromMeOrYou: _fromMeOrYou,
        markiert: false,
      ));
      _input.clear();
    });
    _store.save(_messages);
    _scrollToBottom();
  }

  Future<void> _onMic() async {
    if (!_speechAvailable) return;

    // --- Android: Vosk offline ---
    if (_useVosk) {
      if (_voskLoading) return;
      if (!_voskReady) {
        await _initVosk();
        if (!_voskReady) return; // Laden fehlgeschlagen
      }
      if (_isListening) {
        await _voskService?.stop();
        if (mounted) setState(() => _isListening = false);
      } else {
        if (mounted) setState(() => _isListening = true);
        await _voskService?.start();
      }
      return;
    }

    // --- iOS/Web: System-Recognizer ---
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }
    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        if (mounted) {
          setState(() => _input.text = result.recognizedWords);
        }
      },
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        localeId: 'de_DE',
      ),
    );
  }

  Future<void> _onVorlesen() async {
    var text = _vorleseText;
    if (text.isEmpty) {
      text = 'Bitte treffen Sie eine Auswahl';
    }
    if (_selectedLanguage != null) {
      await _tts.setLanguage(_selectedLanguage!);
    }
    setState(() => _isSpeaking = true);
    await _tts.speak(text);
  }

  void _onDelMessage() {
    setState(() {
      _messages.removeWhere((e) => e.markiert);
    });
    _store.save(_messages);
  }

  void _onDelAll() {
    setState(() => _messages.clear());
    _store.save(_messages);
  }

  void _onSelect(int index) {
    setState(() {
      for (var i = 0; i < _messages.length; i++) {
        _messages[i].markiert = i == index;
      }
      _vorleseText = _messages[index].eintrag;
    });
  }

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    // Höhe der eingeblendeten Tastatur.
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      // Layout NICHT stauchen, wenn die Tastatur kommt – wir schieben den
      // Inhalt stattdessen nach oben, damit das Chatfenster seine Größe behält.
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Deaftalk'),
        actions: [
          if (_appVersion.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  _appVersion,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: ClipRect(
          child: Transform.translate(
            // Gesamten Inhalt um die Tastaturhöhe nach oben verschieben:
            // Eingabezeile bleibt über der Tastatur, oberer Block wandert
            // nach oben aus dem sichtbaren Bereich.
            offset: Offset(0, -keyboardInset),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
              _buildLanguageSpinner(),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _isSpeaking ? null : _onVorlesen,
                child: const Text('ausgewählten Text vorlesen'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _onDelMessage,
                      child: const Text('Nachricht löschen'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _onDelAll,
                      child: const Text('Historie löschen'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildChatView()),
              _buildSpeakerRadios(),
              TextField(
                controller: _input,
                decoration: const InputDecoration(
                  hintText: 'Hier gibt man Text ein',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _onSend(),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _onSend,
                icon: const Icon(Icons.send),
                label: const Text('Text senden'),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: (_speechAvailable && !_voskLoading) ? _onMic : null,
                icon: _voskLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_isListening ? Icons.mic : Icons.mic_none),
                label: Text(
                  !_speechAvailable
                      ? 'Spracherkennung nicht verfügbar'
                      : _voskLoading
                          ? 'Sprachmodell wird geladen …'
                          : _isListening
                              ? 'Höre zu … (zum Stoppen tippen)'
                              : 'Spracherkennung starten',
                ),
              ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageSpinner() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedLanguage,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Sprache (Vorlesen)',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: _languages
          .map((l) =>
              DropdownMenuItem(value: l, child: Text(_displayLocale(l))))
          .toList(),
      onChanged: (v) => setState(() => _selectedLanguage = v),
    );
  }

  Widget _buildSpeakerRadios() {
    return RadioGroup<bool>(
      groupValue: _fromMeOrYou,
      onChanged: (v) => setState(() => _fromMeOrYou = v ?? true),
      child: const Row(
        children: [
          Expanded(
            child: RadioListTile<bool>(
              title: Text('Ich'),
              value: true,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
          Expanded(
            child: RadioListTile<bool>(
              title: Text('Gast'),
              value: false,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatView() {
    return Container(
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/images/jungle.png'),
          fit: BoxFit.cover,
        ),
        border: Border.all(color: DeaftalkColors.primaryDark, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: _messages.isEmpty
          ? const SizedBox.expand()
          : ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(6),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final e = _messages[index];
                return GestureDetector(
                  onTap: () => _onSelect(index),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: e.markiert
                          ? DeaftalkColors.accent.withValues(alpha: 0.95)
                          : Colors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(8),
                      border: e.markiert
                          ? Border.all(
                              color: DeaftalkColors.primaryDark, width: 2)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${e.fromMeOrYou ? "Ich" : "Gast"}: ',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold),
                        ),
                        Expanded(child: Text(e.eintrag)),
                        if (e.markiert)
                          const Icon(Icons.volume_up, size: 18),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
