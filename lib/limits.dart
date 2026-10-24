import 'additive_db.dart';
import 'ingredient_parser.dart';

/// Wymagania i limity dla składników, które nie są dodatkami z listy E
/// (np. kofeina w napojach).
class LimitNote {
  const LimitNote({
    required this.title,
    required this.lines,
    required this.source,
  });

  final String title;
  final List<String> lines;
  final String source;
}

String _fold(String s) => AdditiveDatabase.fold(s);

double? _num(String s) => double.tryParse(s.replaceAll(',', '.'));

String _fmt(double v) {
  final rounded = (v * 10).round() / 10;
  final r = rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1);
  return r.replaceAll('.', ',');
}

/// Sprawdza wymagania dla kofeiny na podstawie składników i odczytanego tekstu.
List<LimitNote> evaluateLimits(List<Ingredient> ingredients, String rawText) {
  final notes = <LimitNote>[];
  final text = _fold(rawText);

  final caffeine = ingredients.where((i) => _fold(i.name).startsWith('kofein'));
  if (caffeine.isNotEmpty) {
    final amount = caffeineAmount(ingredients, rawText);
    final mgPer100 = amount.mgPer100;
    final how = amount.how;

    final lines = <String>[];
    if (mgPer100 != null) {
      lines.add('Zawartość: ${_fmt(mgPer100)} mg/100 ml '
          '(≈ ${_fmt(mgPer100 * 10)} mg/l), $how.');
    } else {
      lines.add('Nie udało się odczytać zawartości kofeiny (mg/100 ml).');
    }

    final high = mgPer100 != null && mgPer100 * 10 > 150;
    if (high) {
      final hasWarning = text.contains('zawartosc kofein');
      lines.add('Powyżej 150 mg/l napój musi mieć ostrzeżenie: „Wysoka '
          'zawartość kofeiny; nie zaleca się stosowania u dzieci, kobiet '
          'w ciąży i kobiet karmiących piersią” (rozporządzenie (UE) '
          '1169/2011, załącznik III). '
          '${hasWarning ? 'Ostrzeżenie jest w odczytanym tekście.' : 'Nie znaleziono go w odczytanym tekście - sprawdź etykietę (może to błąd OCR).'}');
      final hasLabel = text.contains('napoj energetyzuj') ||
          text.contains('napoj energetyczn');
      lines.add('W Polsce taki napój to „napój energetyzujący”: zakaz '
          'sprzedaży osobom poniżej 18 lat, w szkołach i w automatach, a '
          'opakowanie musi mieć oznaczenie „Napój energetyzujący” lub „Napój '
          'energetyczny” (ustawa o zdrowiu publicznym, art. 12l-12n, od '
          '1.01.2024). '
          '${hasLabel ? 'Takie określenie jest w odczytanym tekście.' : 'Nie znaleziono go w odczytanym tekście.'}');
    }

    final volume = RegExp(r'netto[^0-9]{0,15}(\d{2,4})\s*ml', caseSensitive: false)
        .firstMatch(rawText);
    if (mgPer100 != null && volume != null) {
      final ml = _num(volume.group(1)!);
      if (ml != null) {
        final total = mgPer100 * ml / 100;
        lines.add('W opakowaniu ${_fmt(ml)} ml: ok. ${_fmt(total)} mg kofeiny '
            '(${_fmt(total / 200 * 100)}% jednorazowej dawki 200 mg).');
      }
    }

    lines.add('Punkt odniesienia (EFSA 2015): dorośli do 200 mg jednorazowo i '
        '400 mg dziennie; kobiety w ciąży i karmiące do 200 mg dziennie; '
        'dzieci i młodzież ok. 3 mg/kg masy ciała dziennie. Nie znalazłem '
        'ogólnego górnego limitu kofeiny w napojach - powyższe to wymagania '
        'etykietowe i sprzedażowe.');

    notes.add(LimitNote(
      title: 'Kofeina: limity i wymagania',
      lines: lines,
      source: 'Rozp. (UE) 1169/2011 zał. III; ustawa o zdrowiu publicznym '
          '(Dz.U. 2023 poz. 1718); EFSA 2015. Dane orientacyjne.',
    ));
  }
  return notes;
}

/// Zawartość kofeiny w mg/100 ml: najpierw jawne "32 mg/100 ml" z etykiety,
/// inaczej z procentu (zakładając, że 1 ml waży 1 g).
({double? mgPer100, String? how}) caffeineAmount(
    List<Ingredient> ingredients, String rawText) {
  final caffeine = ingredients.where((i) => _fold(i.name).startsWith('kofein'));
  if (caffeine.isEmpty) return (mgPer100: null, how: null);
  final explicit = RegExp(
    r'(\d+(?:[.,]\d+)?)\s*mg\s*/\s*100\s*ml',
    caseSensitive: false,
  ).firstMatch(rawText);
  if (explicit != null) {
    return (mgPer100: _num(explicit.group(1)!), how: 'z etykiety');
  }
  final pct = caffeine.first.percent;
  if (pct != null) {
    final p = _num(pct.replaceAll('%', ''));
    if (p != null) {
      return (
        mgPer100: p * 1000,
        how: 'z podanego procentu, zakładając gęstość 1 g/ml',
      );
    }
  }
  return (mgPer100: null, how: null);
}
