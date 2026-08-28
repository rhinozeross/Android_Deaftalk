import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initTts();
    _initSpeech();
    _loadHistory();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tts.stop();
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
      final list = (langs as List).map((e) => e.toString()).toSet().toList()
        ..sort();
      String? initial;
      if (list.contains('de-DE')) {
        initial = 'de-DE';
      } else if (list.length > 3) {
        initial = list[3]; // Original: spinner.setSelection(3)
      } else if (list.isNotEmpty) {
        initial = list.first;
      }
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

  Future<void> _initSpeech() async {
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
    return Scaffold(
      appBar: AppBar(title: const Text('Deaftalk')),
      body: SafeArea(
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
                onPressed: _speechAvailable ? _onMic : null,
                icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                label: Text(
                  !_speechAvailable
                      ? 'Spracherkennung nicht verfügbar'
                      : _isListening
                          ? 'Höre zu … (zum Stoppen tippen)'
                          : 'Spracherkennung starten',
                ),
              ),
            ],
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
          .map((l) => DropdownMenuItem(value: l, child: Text(l)))
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
