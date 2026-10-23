import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Status dodatku względem przepisów.
enum AdditiveStatus {
  /// Dozwolony.
  allowed,

  /// Dozwolony z ograniczeniami (limity, kategorie, ostrzeżenia na etykiecie).
  restricted,

  /// Niedozwolony.
  banned,

  /// Brak w bazie: wymaga ręcznej weryfikacji.
  notFound,
}

class AdditiveInfo {
  const AdditiveInfo({
    required this.code,
    required this.name,
    required this.status,
    required this.source,
    this.note,
    this.plNote,
    this.aliases = const [],
  });

  final String code;
  final String name;
  final AdditiveStatus status;
  final String source;
  final String? note;

  /// Uwaga o stanie w Polsce (nadpisanie/uzupełnienie krajowe).
  final String? plNote;

  /// Alternatywne polskie nazwy używane na etykietach (np. "karmel").
  final List<String> aliases;

  factory AdditiveInfo.fromJson(Map<String, dynamic> json,
          {String? defaultPlNote}) =>
      AdditiveInfo(
        code: json['code'] as String,
        name: json['name'] as String,
        status: AdditiveStatus.values.byName(json['status'] as String),
        source: json['source'] as String,
        note: json['note'] as String?,
        plNote: (json['plNote'] as String?) ?? defaultPlNote,
        aliases: [for (final a in (json['aliases'] as List? ?? [])) a as String],
      );
}

/// Lokalna baza dodatków (np. ładowana z assets/additives.json).
class AdditiveDatabase {
  AdditiveDatabase(Iterable<AdditiveInfo> items, {this.isSample = false})
      : _byCode = {for (final i in items) normalizeCode(i.code): i},
        _byName = {
          for (final i in items)
            for (final n in [i.name, ...i.aliases]) normalizeName(n): i,
        };

  final Map<String, AdditiveInfo> _byCode;
  final Map<String, AdditiveInfo> _byName;

  /// True, jeśli baza zawiera tylko dane przykładowe.
  final bool isSample;

  int get length => _byCode.length;

  /// Wszystkie wpisy posortowane po numerze E.
  List<AdditiveInfo> get items {
    int numberOf(String code) =>
        int.tryParse(RegExp(r'\d+').firstMatch(code)?.group(0) ?? '') ?? 0;
    final list = _byCode.values.toList();
    list.sort((a, b) {
      final byNumber = numberOf(a.code).compareTo(numberOf(b.code));
      return byNumber != 0 ? byNumber : a.code.compareTo(b.code);
    });
    return list;
  }

  /// "e 330" -> "E330", "E160A" -> "E160a".
  static String normalizeCode(String code) {
    final c = code.trim().replaceAll(RegExp(r'\s+'), '');
    final m = RegExp(r'^[Ee](\d+)(.*)$').firstMatch(c);
    if (m == null) return c.toUpperCase();
    return 'E${m.group(1)}${m.group(2)!.toLowerCase()}';
  }

  AdditiveInfo? lookup(String code) => _byCode[normalizeCode(code)];

  /// Małe litery, bez polskich znaków, pojedyncze spacje.
  static String normalizeName(String name) {
    const from = 'ąćęłńóśźż';
    const to = 'acelnoszz';
    final b = StringBuffer();
    for (final ch in name.toLowerCase().trim().split('')) {
      final i = from.indexOf(ch);
      b.write(i >= 0 ? to[i] : ch);
    }
    return b.toString().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Dodatek podany nazwą zamiast numeru E (np. "cytryniany sodu").
  AdditiveInfo? lookupByName(String name) => _byName[normalizeName(name)];

  factory AdditiveDatabase.fromJsonString(String source) {
    final data = jsonDecode(source) as Map<String, dynamic>;
    final meta = data['meta'] as Map<String, dynamic>?;
    final items = (data['additives'] as List).map((e) => AdditiveInfo.fromJson(
        e as Map<String, dynamic>,
        defaultPlNote: meta?['defaultPlNote'] as String?));
    return AdditiveDatabase(items, isSample: meta?['sample'] == true);
  }

  static Future<AdditiveDatabase> loadAsset(
      [String path = 'assets/additives.json']) async {
    return AdditiveDatabase.fromJsonString(await rootBundle.loadString(path));
  }
}
