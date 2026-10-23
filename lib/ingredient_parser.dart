/// Pojedynczy rozpoznany składnik z etykiety.
class Ingredient {
  const Ingredient({
    required this.name,
    this.eNumber,
    this.percent,
  });

  /// Nazwa składnika po oczyszczeniu (np. "mąka pszenna").
  final String name;

  /// Znormalizowany numer E (np. "E102"), jeśli został rozpoznany.
  final String? eNumber;

  /// Podany na etykiecie udział procentowy (np. "12%"), jeśli był.
  final String? percent;

  @override
  String toString() => 'Ingredient($name, e: $eNumber, %: $percent)';

  @override
  bool operator ==(Object other) =>
      other is Ingredient &&
      other.name == name &&
      other.eNumber == eNumber &&
      other.percent == percent;

  @override
  int get hashCode => Object.hash(name, eNumber, percent);
}

/// Parser tekstu z OCR listy składników.
class IngredientParser {
  const IngredientParser();

  static final RegExp _header = RegExp(
    r'^\s*(sk[łl]adniki|sk[łl]ad|ingredients)\s*[:\-]?\s*',
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

    text = text.replaceFirst(_header, '');
    text = text.replaceAll(RegExp(r'[.\s]+$'), '');

    final parts = _splitTopLevel(text);
    final result = <Ingredient>[];
    for (final part in parts) {
      final ingredient = _parsePart(part);
      if (ingredient != null) result.add(ingredient);
    }
    return result;
  }

  /// Dzieli po przecinkach i średnikach, ale nie wewnątrz nawiasów
  /// (np. "czekolada (kakao, cukier)" zostaje jednym składnikiem).
  List<String> _splitTopLevel(String text) {
    final parts = <String>[];
    final buffer = StringBuffer();
    var depth = 0;
    for (final rune in text.runes) {
      final ch = String.fromCharCode(rune);
      if (ch == '(' || ch == '[') depth++;
      if ((ch == ')' || ch == ']') && depth > 0) depth--;
      if ((ch == ',' || ch == ';') && depth == 0) {
        parts.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
    parts.add(buffer.toString());
    return parts;
  }

  Ingredient? _parsePart(String part) {
    var p = part.trim();
    if (p.isEmpty) return null;

    String? percent;
    final pm = _percent.firstMatch(p);
    if (pm != null) {
      percent = '${pm.group(1)!.replaceAll(',', '.')}%';
      p = p.replaceFirst(pm.group(0)!, ' ');
    }

    String? eNumber;
    final em = _eNumber.firstMatch(p);
    if (em != null) {
      final suffix = (em.group(2) ?? '').replaceAll(RegExp(r'[\s()]'), '');
      eNumber = 'E${em.group(1)}${suffix.toLowerCase()}';
    }

    p = p.replaceAll(RegExp(r'\s+'), ' ').trim();
    p = p.replaceAll(RegExp(r'^[\-–•*\s]+|[\-–•*\s]+$'), '');
    if (p.isEmpty) return null;

    return Ingredient(name: p, eNumber: eNumber, percent: percent);
  }
}
