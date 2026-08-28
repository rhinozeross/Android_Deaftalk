import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/eintrag.dart';

/// Persistenz der Chat-Historie.
///
/// Ersetzt das Datei-basierte Save()/Load() der Java-App durch
/// [SharedPreferences], damit dieselbe Logik auf Android, iOS und Web läuft.
class HistoryStore {
  static const _key = 'deaftalk_history';

  Future<void> save(List<Eintrag> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(messages.map((e) => e.toJson()).toList());
    await prefs.setString(_key, data);
  }

  Future<List<Eintrag>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);
    if (data == null || data.isEmpty) return [];
    try {
      final list = jsonDecode(data) as List<dynamic>;
      return list
          .map((e) => Eintrag.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
