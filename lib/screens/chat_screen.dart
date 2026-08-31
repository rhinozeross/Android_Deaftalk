import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../l10n/app_localizations.dart';
import '../models/eintrag.dart';
import '../services/history_store.dart';
import '../services/locale_controller.dart';
import '../services/speech_recognizer.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import '../utils/locale_utils.dart';
import '../widgets/keyboard_inset_shifter.dart';
import 'settings_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.localeController});

  final LocaleController localeController;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TtsService _tts = TtsService();
  final HistoryStore _store = HistoryStore();
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  late final SpeechRecognizer _recognizer;

  final List<Eintrag> _messages = [];
  int? _selectedIndex; // ausgewählter Eintrag (für Vorlesen/Löschen)

  bool _fromMeOrYou = true; // true = Ich, false = Gast
  bool _isSpeaking = false; // Vorlesen-Button während Ausgabe deaktivieren

  bool _isListening = false; // Spracherkennung läuft
  bool _sttLoading = false; // Vosk-Modell wird geladen

  String _appVersion = ''; // App-Version aus pubspec (zur Laufzeit gelesen)

  /// Aktive Locale: manuelle Auswahl (Einstellungen) oder System.
  Locale get _effectiveLocale =>
      widget.localeController.locale ??
      WidgetsBinding.instance.platformDispatcher.locale;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.localeController.addListener(_onLocaleChanged);
    _tts.init(onSpeakingDone: () {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _initRecognizer();
    _loadLanguages();
    _initVersion();
    _loadHistory();
  }

  /// Bei App-Sprachwechsel die Vorlese-Sprache passend nachziehen.
  void _onLocaleChanged() {
    if (mounted) setState(() => _tts.selectForLocale(_effectiveLocale));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.localeController.removeListener(_onLocaleChanged);
    _tts.stop();
    _recognizer.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // entspricht onStop() -> Save() im Original
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _persist();
    }
  }

  // ---- Initialisierung ----

  void _initRecognizer() {
    _recognizer = createSpeechRecognizer(
      onResult: (text) {
        if (mounted) setState(() => _input.text = text);
      },
      onListeningStopped: () {
        if (mounted) setState(() => _isListening = false);
      },
      onError: _onSpeechError,
    );
    _recognizer.initialize().then((_) {
      if (mounted) setState(() {}); // Button-Verfügbarkeit aktualisieren
    });
  }

  Future<void> _loadLanguages() async {
    await _tts.loadLanguages(_effectiveLocale);
    if (mounted) setState(() {});
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

  Future<void> _loadHistory() async {
    final loaded = await _store.load();
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(loaded);
      _selectedIndex = null;
    });
    _scrollToBottom();
  }

  // ---- Hilfen ----

  void _persist() => _store.save(_messages);

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  void _onSpeechError(SpeechError error) {
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    _showSnack(switch (error) {
      SpeechError.micDenied => l.micAccessDenied,
      SpeechError.loadFailed => l.speechLoadFailed,
    });
  }

  // ---- Aktionen (entsprechen den onClick-Methoden im Original) ----

  void _onSend() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(Eintrag(eintrag: text, fromMeOrYou: _fromMeOrYou));
      _input.clear();
    });
    _persist();
    _scrollToBottom();
  }

  Future<void> _onMic() async {
    if (!_recognizer.available || _sttLoading) return;

    // Modell bei Bedarf laden (nur Vosk, einmalig)
    if (_recognizer.requiresPreparation && !_recognizer.isPrepared) {
      setState(() => _sttLoading = true);
      final ok = await _recognizer.prepare();
      if (mounted) setState(() => _sttLoading = false);
      if (!ok) return;
    }

    if (_isListening) {
      await _recognizer.stop();
      if (mounted) setState(() => _isListening = false);
    } else {
      if (mounted) setState(() => _isListening = true);
      await _recognizer.start();
    }
  }

  Future<void> _onVorlesen() async {
    final sel = _selectedIndex;
    final text = (sel != null && sel < _messages.length)
        ? _messages[sel].eintrag
        : AppLocalizations.of(context).pleaseMakeSelection;
    setState(() => _isSpeaking = true);
    await _tts.speak(text);
  }

  void _onDelMessage() {
    final sel = _selectedIndex;
    if (sel == null || sel >= _messages.length) return;
    setState(() {
      _messages.removeAt(sel);
      _selectedIndex = null;
    });
    _persist();
  }

  void _onDelAll() {
    setState(() {
      _messages.clear();
      _selectedIndex = null;
    });
    _persist();
  }

  void _onSelect(int index) => setState(() => _selectedIndex = index);

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Layout NICHT stauchen, wenn die Tastatur kommt – der Inhalt wird
      // stattdessen nach oben geschoben (siehe KeyboardInsetShifter).
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Deaftalk'),
        actions: [
          if (_appVersion.isNotEmpty)
            Center(
              child: Text(_appVersion, style: const TextStyle(fontSize: 12)),
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: AppLocalizations.of(context).settingsTitle,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    SettingsScreen(controller: widget.localeController),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: KeyboardInsetShifter(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final l = AppLocalizations.of(context);
    return Column(
      children: [
        _buildLanguageSpinner(),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _isSpeaking ? null : _onVorlesen,
          child: Text(l.readSelectedAloud),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _onDelMessage,
                child: Text(l.deleteMessage),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: _onDelAll,
                child: Text(l.deleteHistory),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(child: _buildChatView()),
        _buildSpeakerRadios(),
        TextField(
          controller: _input,
          decoration: InputDecoration(
            hintText: l.inputHint,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _onSend(),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _onSend,
          icon: const Icon(Icons.send),
          label: Text(l.sendText),
        ),
        const SizedBox(height: 8),
        _buildMicButton(),
      ],
    );
  }

  Widget _buildLanguageSpinner() {
    return DropdownButtonFormField<String>(
      initialValue: _tts.selectedLanguage,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context).languageLabel,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: _tts.languages
          .map((l) =>
              DropdownMenuItem(value: l, child: Text(normalizeLocale(l))))
          .toList(),
      onChanged: (v) => setState(() => _tts.selectedLanguage = v),
    );
  }

  Widget _buildSpeakerRadios() {
    final l = AppLocalizations.of(context);
    return RadioGroup<bool>(
      groupValue: _fromMeOrYou,
      onChanged: (v) => setState(() => _fromMeOrYou = v ?? true),
      child: Row(
        children: [
          Expanded(
            child: RadioListTile<bool>(
              title: Text(l.speakerMe),
              value: true,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
          Expanded(
            child: RadioListTile<bool>(
              title: Text(l.speakerGuest),
              value: false,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicButton() {
    final l = AppLocalizations.of(context);
    final available = _recognizer.available;
    return ElevatedButton.icon(
      onPressed: (available && !_sttLoading) ? _onMic : null,
      icon: _sttLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(_isListening ? Icons.mic : Icons.mic_none),
      label: Text(
        !available
            ? l.speechNotAvailable
            : _sttLoading
                ? l.loadingSpeechModel
                : _isListening
                    ? l.listeningTapToStop
                    : l.startSpeechRecognition,
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
              itemBuilder: (context, index) =>
                  _buildMessageTile(index, _messages[index]),
            ),
    );
  }

  Widget _buildMessageTile(int index, Eintrag e) {
    final l = AppLocalizations.of(context);
    final selected = index == _selectedIndex;
    return GestureDetector(
      onTap: () => _onSelect(index),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? DeaftalkColors.accent.withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(8),
          border: selected
              ? Border.all(color: DeaftalkColors.primaryDark, width: 2)
              : null,
        ),
        child: Row(
          children: [
            Text(
              '${e.fromMeOrYou ? l.speakerMe : l.speakerGuest}: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Expanded(child: Text(e.eintrag)),
            if (selected) const Icon(Icons.volume_up, size: 18),
          ],
        ),
      ),
    );
  }
}
