/// Pojedynczy rozpoznany składnik z etykiety.
class Ingredient {
  const Ingredient({
    required this.name,
    this.eNumber,
    this.percent,
    this.function,
    this.rawName,
  });

  /// Nazwa składnika po oczyszczeniu (np. "mąka pszenna").
  final String name;

  /// Znormalizowany numer E (np. "E102"), jeśli został rozpoznany.
  final String? eNumber;

  /// Podany na etykiecie udział procentowy (np. "12%"), jeśli był.
  final String? percent;

  /// Funkcja technologiczna podana na etykiecie (np. "barwnik", "regulator kwasowości").
  final String? function;

  /// Nazwa tak jak odczytał OCR, jeśli została poprawiona słownikiem.
  final String? rawName;

  @override
  String toString() => 'Ingredient($name, e: $eNumber, %: $percent, fn: $function)';

  @override
  bool operator ==(Object other) =>
      other is Ingredient &&
      other.name == name &&
      other.eNumber == eNumber &&
      other.percent == percent &&
      other.function == function;

  @override
  int get hashCode => Object.hash(name, eNumber, percent, function);
}

/// Parser tekstu z OCR listy składników.
class IngredientParser {
  const IngredientParser();

  static final RegExp _header = RegExp(
    r'^\s*(sk[łl]adniki|sk[łl]ad|ingredients)\s*[:\-]?\s*',
    caseSensitive: false,
  );

  static final RegExp _headerAnywhere = RegExp(
    r'sk[łl]adniki\s*:\s*',
    caseSensitive: false,
  );

  // E102, E 102, e-102, E160a, E 160 a, E1520
  static final RegExp _eNumber = RegExp(
    r'\bE\s*[-]?\s*(\d{3,4})\s*([a-z]{1,2}\b|(?:\s?\([ivx]+\)))?',
    caseSensitive: false,
  );

  static final RegExp _percent = RegExp(r'(\d{1,3}(?:[.,]\d+)?)\s*%');

  /// Poprawia typowe pomyłki OCR w numerach E (O→0, l/I→1) tylko tam,
  /// gdzie litera "E" stoi tuż przed cyframi podobnymi do liter.
  String fixOcrNoise(String raw) {
    return raw.replaceAllMapped(
      RegExp(r'\b[Ee]\s*[-]?\s*([0-9OoIl]{3,4})([a-z]?)\b'),
      (m) {
        final digits = m
            .group(1)!
            .replaceAll(RegExp('[Oo]'), '0')
            .replaceAll(RegExp('[Il]'), '1');
        return 'E$digits${m.group(2) ?? ''}';
      },
    );
  }

  List<Ingredient> parse(String raw) {
    var text = fixOcrNoise(raw)
        .replaceAll('\r', ' ')
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Zdjęcie puszki/butelki obejmuje też opis produktu przed listą składników:
    // bierzemy tekst po pierwszym "Składniki:" i kończymy na końcu zdania.
    final anywhere = _headerAnywhere.firstMatch(text);
    if (anywhere != null) {
      text = text.substring(anywhere.end);
    } else {
      text = text.replaceFirst(_header, '');
    }
    // Rozmyte zdjęcie: OCR często czyta przecinek jako kropkę ("woda. cukier").
    // Kropka po literze, po której zaczyna się mała litera lub cyfra, to
    // przecinek; kropka przed wielką literą kończy listę.
    text = text.replaceAllMapped(
      RegExp(r'(?<=[a-ząćęłńóśźż])\.(?=\s*[a-ząćęłńóśźż0-9])'),
      (_) => ',',
    );
    // Stopka nawet bez kropki lub z błędnie odczytaną wielkością liter.
    final footer = RegExp(
      r'najlepiej spo[żz]y[ćc]|przechowywa[ćc]|chroni[ćc] przed|data minimalnej|wyprodukowano|producent:',
      caseSensitive: false,
    ).firstMatch(text);
    if (footer != null) text = text.substring(0, footer.start);
    final sentenceEnd = RegExp('\\.(?=[\\s"\'”*]|\$)').firstMatch(text);
    if (sentenceEnd != null) text = text.substring(0, sentenceEnd.start);
    text = text.replaceAll(RegExp(r'[.\s]+$'), '');

    final parts = _splitTopLevel(text);
    final result = <Ingredient>[];
    for (final part in parts) {
      result.addAll(_parseExpanded(part));
    }
    return result;
  }

  /// Dzieli po przecinkach i średnikach, ale nie wewnątrz nawiasów
  /// (np. "czekolada (kakao, cukier)" zostaje jednym składnikiem).
  static final RegExp _functionPrefix = RegExp(
    r'^(emulgator|stabilizator|regulator|barwnik|konserwant|przeciwutleniacz|zag[ęe]szczacz|substancj|wzmacniacz|przeciwzbrylaj|[śs]rodek|[śs]rodki)[^(]{0,40}$',
    caseSensitive: false,
  );

  /// "emulgatory (A, B)" -> osobne składniki A i B z funkcją "emulgatory".
  List<Ingredient> _parseExpanded(String part, {String? function}) {
    final p = part.trim();
    final open = p.indexOf('(');
    if (open > 0 && p.endsWith(')')) {
      final prefix = p.substring(0, open).trim();
      if (_functionPrefix.hasMatch(prefix)) {
        final inner = p.substring(open + 1, p.length - 1);
        return [
          for (final c in _splitTopLevel(inner))
            ..._parseExpanded(c, function: prefix),
        ];
      }
    }
    final ing = _parsePart(part);
    if (ing == null) return [];
    if (function != null && ing.function == null) {
      return [
        Ingredient(
          name: ing.name,
          eNumber: ing.eNumber,
          percent: ing.percent,
          function: function,
        ),
      ];
    }
    return [ing];
  }

  List<String> _splitTopLevel(String text) {
    final parts = <String>[];
    final buffer = StringBuffer();
    var depth = 0;
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch == '(' || ch == '[') depth++;
      if ((ch == ')' || ch == ']') && depth > 0) depth--;
      // Przecinek dziesiętny ("62,5%") nie dzieli składników.
      final isDecimalComma = ch == ',' &&
          i > 0 &&
          i < text.length - 1 &&
          _isDigit(text[i - 1]) &&
          _isDigit(text[i + 1]);
      if ((ch == ',' || ch == ';') && depth == 0 && !isDecimalComma) {
        parts.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
    parts.add(buffer.toString());
    return parts;
  }

  static bool _isDigit(String c) => RegExp(r'\d').hasMatch(c);

  Ingredient? _parsePart(String part) {
    var p = part.trim();
    if (p.isEmpty) return null;

    String? percent;
    final pm = _percent.firstMatch(p);
    if (pm != null) {
      percent = '${pm.group(1)!.replaceAll(',', '.')}%';
      p = p.replaceFirst(pm.group(0)!, ' ');
    }

    // Etykiety podają procent z co najwyżej dwoma miejscami po przecinku, więc
    // liczba typu 6,976 to prawie na pewno "6,97%" z błędnie odczytanym znakiem %
    // (OCR czyta % jako 6). Jednostki wagi (g, mg, ml...) wyłączamy.
    if (percent == null) {
      final m = RegExp(
        r'(?<![\d.,])(\d{1,3})[.,](\d{2})6(?![\d])(?!\s*(?:g|mg|kg|ml|l|kcal|kj)\b)',
        caseSensitive: false,
      ).firstMatch(p);
      if (m != null) {
        percent = '${m.group(1)}.${m.group(2)}%';
        p = p.replaceFirst(m.group(0)!, ' ');
      }
    }

    String? eNumber;
    final em = _eNumber.firstMatch(p);
    if (em != null) {
      final suffix = (em.group(2) ?? '').replaceAll(RegExp(r'[\s()]'), '');
      eNumber = 'E${em.group(1)}${suffix.toLowerCase()}';
    }

    p = p.replaceAll(RegExp(r'\(\s*\)'), '');
    p = p.replaceAll(RegExp(r'\s+'), ' ').trim();
    p = p.replaceAll(RegExp(r'^[\-–•*\s]+|[\-–•*\s]+$'), '');

    // "regulator kwasowości: kwas cytrynowy" -> funkcja + nazwa.
    String? function;
    final colon = p.indexOf(':');
    if (colon > 0 && p.substring(0, colon).trim().split(' ').length <= 4) {
      final before = p.substring(0, colon).trim();
      final after = p.substring(colon + 1).trim();
      if (after.isNotEmpty) {
        function = before;
        p = after;
      }
    }
    if (p.isEmpty) return null;

    return Ingredient(
        name: p, eNumber: eNumber, percent: percent, function: function);
  }
}
