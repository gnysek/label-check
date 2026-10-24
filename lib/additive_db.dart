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

  /// Numer jest w bazie, ale bez potwierdzonego statusu (brak danych).
  unverified,
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
        },
        _displayByKey = {
          for (final i in items)
            for (final n in [i.name, ...i.aliases]) normalizeName(n): n,
        };

  final Map<String, AdditiveInfo> _byCode;
  final Map<String, AdditiveInfo> _byName;
  final Map<String, String> _displayByKey;

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
    // OCR myli litery z cyframi (S01 -> SOI) - poprawiamy tylko w słowach z literami.
    final fixed = b.toString().split(RegExp(r'\s+')).map((w) {
      if (!RegExp(r'[a-z]').hasMatch(w)) return w;
      return w
          .replaceAll('0', 'o')
          .replaceAll('1', 'i')
          .replaceAll('5', 's');
    });
    return fixed.join(' ');
  }

  static int _distance(String a, String b) {
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        final best = [prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost]
            .reduce((x, y) => x < y ? x : y);
        cur[j] = best;
      }
      prev = cur;
    }
    return prev[b.length];
  }

  // --- Słownik słów do poprawiania literówek OCR (assets/ingredients.txt). ---
  final Map<String, String> _words = {};
  bool _wordsReady = false;

  static final RegExp _wordRe = RegExp(r'[A-Za-ząćęłńóśźżĄĆĘŁŃÓŚŹŻ]+');

  /// Małe litery bez polskich znaków (bez poprawek cyfr).
  static String fold(String s) {
    const from = 'ąćęłńóśźż';
    const to = 'acelnoszz';
    final b = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      final i = from.indexOf(ch);
      b.write(i >= 0 ? to[i] : ch);
    }
    return b.toString();
  }

  /// Dodaje frazy (z pliku słownika) oraz nazwy i aliasy dodatków jako znane słowa.
  void loadDictionary(Iterable<String> phrases) {
    void addPhrase(String p) {
      for (final m in _wordRe.allMatches(p)) {
        final w = m.group(0)!.toLowerCase();
        if (w.length < 3) continue;
        final k = fold(w);
        // Wersja z polskimi znakami wygrywa z gołą.
        if (!_words.containsKey(k) || (_words[k] == k && w != k)) {
          _words[k] = w;
        }
      }
    }

    for (final line in phrases) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('#')) continue;
      addPhrase(t);
    }
    for (final i in _byCode.values) {
      addPhrase(i.name);
      for (final a in i.aliases) {
        addPhrase(a);
      }
    }
    _wordsReady = true;
  }

  String _restyle(String original, String canon) {
    if (original.length > 1 && original == original.toUpperCase()) {
      return canon.toUpperCase();
    }
    final first = original[0];
    if (first == first.toUpperCase() && first != first.toLowerCase() &&
        original.substring(1) == original.substring(1).toLowerCase()) {
      return canon[0].toUpperCase() + canon.substring(1);
    }
    return canon;
  }

  String _correctWord(String w) {
    if (w.length < 4) return w;
    final k = fold(w);
    final exact = _words[k];
    if (exact != null) {
      return w.toLowerCase() == exact ? w : _restyle(w, exact);
    }
    if (w.length < 5) return w;
    // Dłuższe wyrazy ("substangia" -> "substancja") tolerują dwie pomyłki.
    final maxDist = k.length >= 9 ? 2 : 1;
    String? best;
    var ambiguous = false;
    var bestDist = maxDist + 1;
    for (final e in _words.entries) {
      if ((e.key.length - k.length).abs() > maxDist || e.key.length < 5) {
        continue;
      }
      final d = _distance(k, e.key);
      if (d == 0 || d > maxDist) continue;
      if (d > bestDist) continue;
      if (d < bestDist) {
        bestDist = d;
        best = null;
        ambiguous = false;
      }
      if (best != null && best != e.value) ambiguous = true;
      best = e.value;
    }
    if (best == null || ambiguous) return w;
    return _restyle(w, best);
  }

  /// Poprawia literówki OCR słowo po słowie (np. "prosSzek" -> "proszek",
  /// "maka" -> "mąka"). Bez słownika zwraca tekst bez zmian.
  String correctText(String text) {
    if (!_wordsReady) return text;
    return text.replaceAllMapped(_wordRe, (m) => _correctWord(m.group(0)!));
  }

  /// Dodatek podany nazwą zamiast numeru E (np. "cytryniany sodu").
  AdditiveInfo? lookupByName(String name) => matchByName(name)?.info;

  /// Dopasowanie po nazwie; `exact` = false, gdy użyto przybliżenia
  /// (literówki z OCR, np. "zerwień buraczana").
  ({AdditiveInfo info, bool exact, String matched})? matchByName(String name) {
    final key = normalizeName(name);
    final direct = _byName[key];
    if (direct != null) {
      return (info: direct, exact: true, matched: _displayByKey[key] ?? name);
    }
    if (key.length < 7) return null;
    final maxDist = key.length >= 14 ? 2 : 1;
    var best = maxDist + 1;
    final found = <AdditiveInfo>{};
    String? foundKey;
    for (final e in _byName.entries) {
      if (e.key.length < 7 || (e.key.length - key.length).abs() > maxDist) {
        continue;
      }
      final d = _distance(key, e.key);
      if (d > maxDist) continue;
      if (d < best) {
        best = d;
        found
          ..clear()
          ..add(e.value);
        foundKey = e.key;
      } else if (d == best) {
        found.add(e.value);
      }
    }
    if (found.length != 1) return null;
    return (
      info: found.first,
      exact: false,
      matched: _displayByKey[foundKey] ?? found.first.name,
    );
  }

  factory AdditiveDatabase.fromJsonString(String source,
      {Iterable<String>? dictionary}) {
    final data = jsonDecode(source) as Map<String, dynamic>;
    final meta = data['meta'] as Map<String, dynamic>?;
    final items = (data['additives'] as List).map((e) => AdditiveInfo.fromJson(
        e as Map<String, dynamic>,
        defaultPlNote: meta?['defaultPlNote'] as String?));
    final db = AdditiveDatabase(items, isSample: meta?['sample'] == true);
    if (dictionary != null) db.loadDictionary(dictionary);
    return db;
  }

  static Future<AdditiveDatabase> loadAsset(
      [String path = 'assets/additives.json']) async {
    final dict = await rootBundle.loadString('assets/ingredients.txt');
    return AdditiveDatabase.fromJsonString(
      await rootBundle.loadString(path),
      dictionary: dict.split('\n'),
    );
  }
}
