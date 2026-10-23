import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Prosty magazyn tekstowy klucz -> wartość (łatwy do podmiany w testach).
abstract class KeyValueStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class PrefsStorage implements KeyValueStorage {
  @override
  Future<String?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  @override
  Future<void> write(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }
}

class MemoryStorage implements KeyValueStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;
}

/// Zapisany skan: tekst listy składników (po ewentualnej korekcie).
class SavedScan {
  const SavedScan({
    required this.id,
    required this.createdAt,
    required this.text,
  });

  final String id;
  final DateTime createdAt;
  final String text;

  SavedScan copyWith({String? text}) =>
      SavedScan(id: id, createdAt: createdAt, text: text ?? this.text);

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'text': text,
      };

  factory SavedScan.fromJson(Map<String, dynamic> json) => SavedScan(
        id: json['id'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        text: json['text'] as String,
      );
}

/// Historia skanów zapisywana lokalnie na urządzeniu.
class ScanStore {
  ScanStore({KeyValueStorage? storage}) : _storage = storage ?? PrefsStorage();

  static const _key = 'saved_scans_v1';

  final KeyValueStorage _storage;

  /// Zwraca skany od najnowszego.
  Future<List<SavedScan>> load() async {
    final raw = await _storage.read(_key);
    if (raw == null) return [];
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => SavedScan.fromJson(e as Map<String, dynamic>))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(List<SavedScan> scans) =>
      _storage.write(_key, jsonEncode(scans.map((s) => s.toJson()).toList()));

  Future<SavedScan> create(String text) async {
    final now = DateTime.now();
    final scan = SavedScan(
      id: now.microsecondsSinceEpoch.toString(),
      createdAt: now,
      text: text,
    );
    await _write([scan, ...await load()]);
    return scan;
  }

  /// Zmienia tekst istniejącego skanu. Nieistniejące id jest ignorowane.
  Future<void> updateText(String id, String text) async {
    final all = await load();
    if (!all.any((s) => s.id == id)) return;
    await _write([for (final s in all) s.id == id ? s.copyWith(text: text) : s]);
  }

  Future<void> delete(String id) async {
    final all = await load();
    await _write(all.where((s) => s.id != id).toList());
  }

  /// Przywraca usunięty skan (cofnij).
  Future<void> restore(SavedScan scan) async {
    final all = await load();
    if (all.any((s) => s.id == scan.id)) return;
    await _write([...all, scan]);
  }
}
