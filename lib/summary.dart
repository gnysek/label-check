import 'additive_db.dart';
import 'allergens.dart';
import 'checker.dart';
import 'limits.dart';

enum Mark { ok, bad, unsure, warn }

/// Jedna linijka podsumowania (ikona + etykieta + opis).
class SummaryRow {
  const SummaryRow(this.mark, this.label, this.text);

  final Mark mark;
  final String label;
  final String text;
}

String _fold(String s) => AdditiveDatabase.fold(s);

// Dodatki zwierzęce (niewegetariańskie lub niewegańskie).
const Map<String, String> _notVegetarian = {
  'E120': 'koszenila (barwnik z owadów)',
  'E542': 'fosforan kostny',
};
const Map<String, String> _notVegan = {
  'E901': 'wosk pszczeli',
  'E904': 'szelak (wydzielina owadów)',
  'E913': 'lanolina',
  'E966': 'laktitol (z mleka)',
  'E1105': 'lizozym (z jaj)',
};
// Dodatki, które bywają roślinne lub zwierzęce.
const Set<String> _maybeAnimal = {
  'E422', 'E470a', 'E470b', 'E471', 'E472a', 'E472b', 'E472c', 'E472d',
  'E472e', 'E472f', 'E473', 'E474', 'E475', 'E476', 'E477', 'E479b', 'E481',
  'E482', 'E483', 'E491', 'E492', 'E493', 'E494', 'E495', 'E570', 'E627',
  'E631', 'E635', 'E920',
};

const Set<String> _southampton = {
  'E102', 'E104', 'E110', 'E122', 'E124', 'E129',
};
const Set<String> _aspartame = {'E951', 'E962'};
const Set<String> _polyols = {'E420', 'E421', 'E953', 'E965', 'E966', 'E967'};

const List<String> _meatStems = [
  'mies', 'wieprzow', 'wolow', 'kurczak', 'indyk', 'szynk', 'boczek',
  'slonin', 'smalec', 'kielbas', 'parowk', 'zelatyn',
];
const Set<String> _meatTokens = {
  'drob', 'drobiu', 'drobiowy', 'drobiowe', 'drobiowa', 'loj', 'lojem',
};

Set<String> _codes(List<IngredientCheck> checks) => {
      for (final c in checks)
        if (c.ingredient.eNumber != null || c.info != null)
          AdditiveDatabase.normalizeCode(
              c.ingredient.eNumber ?? c.info!.code),
    };

List<String> _tokens(String name) =>
    RegExp(r'[a-z]+').allMatches(_fold(name)).map((m) => m.group(0)!).toList();

/// Podsumowanie całego produktu: dieta, alergeny, wymagane ostrzeżenia.
List<SummaryRow> buildSummary(List<IngredientCheck> checks, String rawText) {
  final text = _fold(rawText);
  final codes = _codes(checks);
  final rows = <SummaryRow>[];

  // --- Dieta ---
  final notVeg = <String>[];
  final notVegan = <String>[];
  final maybe = <String>[];
  for (final c in checks) {
    final name = c.ingredient.name;
    final tokens = _tokens(name);
    final al = detectAllergens(name, code: c.ingredient.eNumber ?? c.info?.code);
    final isMeat = al.contains(Allergen.fish) ||
        al.contains(Allergen.crustaceans) ||
        al.contains(Allergen.molluscs) ||
        tokens.any((t) => _meatTokens.contains(t) ||
            _meatStems.any((s) => t.startsWith(s)));
    if (isMeat) {
      notVeg.add(name);
      notVegan.add(name);
    } else if (al.contains(Allergen.milk) || al.contains(Allergen.eggs) ||
        tokens.any((t) => t.startsWith('miod') || t.startsWith('pszczel') ||
            t.startsWith('propolis'))) {
      notVegan.add(name);
    }
  }
  for (final code in codes) {
    final a = _notVegetarian[code];
    if (a != null) {
      notVeg.add('$code ($a)');
      notVegan.add('$code ($a)');
    }
    final b = _notVegan[code];
    if (b != null) notVegan.add('$code ($b)');
    if (_maybeAnimal.contains(code)) maybe.add(code);
  }

  String unique(List<String> l) => l.toSet().join(', ');
  if (notVeg.isNotEmpty) {
    rows.add(SummaryRow(Mark.bad, 'Wegetarianie', 'Nie: ${unique(notVeg)}.'));
  } else if (maybe.isNotEmpty) {
    rows.add(SummaryRow(Mark.unsure, 'Wegetarianie',
        'Prawdopodobnie tak, ale ${unique(maybe)} może mieć pochodzenie zwierzęce.'));
  } else {
    rows.add(const SummaryRow(Mark.ok, 'Wegetarianie',
        'Wg składu bez mięsa, ryb i żelatyny.'));
  }
  if (notVegan.isNotEmpty) {
    rows.add(SummaryRow(Mark.bad, 'Weganie', 'Nie: ${unique(notVegan)}.'));
  } else if (maybe.isNotEmpty) {
    rows.add(SummaryRow(Mark.unsure, 'Weganie',
        'Niepewne: ${unique(maybe)} może mieć pochodzenie zwierzęce.'));
  } else {
    rows.add(const SummaryRow(
        Mark.ok, 'Weganie', 'Wg składu bez składników zwierzęcych.'));
  }

  // --- Alergeny ---
  final allergens = <Allergen>{};
  for (final c in checks) {
    allergens.addAll(
        detectAllergens(c.ingredient.name, code: c.ingredient.eNumber ?? c.info?.code));
  }
  rows.add(allergens.isEmpty
      ? const SummaryRow(
          Mark.ok, 'Alergeny', 'Nie wykryto po nazwach składników.')
      : SummaryRow(Mark.warn, 'Alergeny',
          allergens.map((a) => a.label).join(', ')));

  // --- Wymagane ostrzeżenia na etykiecie ---
  final reqs = <SummaryRow>[];
  final sc = codes.where(_southampton.contains).toList()..sort();
  if (sc.isNotEmpty) {
    final found = text.contains('aktywnosc') && text.contains('uwag');
    reqs.add(SummaryRow(
        found ? Mark.ok : Mark.bad,
        'Barwniki ${sc.join(', ')}',
        found
            ? 'Ostrzeżenie o wpływie na aktywność i uwagę dzieci jest w odczycie.'
            : 'Wymagane ostrzeżenie o wpływie na aktywność i uwagę dzieci - nie znaleziono w odczycie.'));
  }
  final asp = codes.where(_aspartame.contains).toList()..sort();
  if (asp.isNotEmpty) {
    final found = text.contains('fenyloalanin');
    reqs.add(SummaryRow(
        found ? Mark.ok : Mark.bad,
        asp.join(', '),
        found
            ? 'Informacja o źródle fenyloalaniny jest w odczycie.'
            : 'Wymagany napis „zawiera źródło fenyloalaniny” - nie znaleziono w odczycie.'));
  }
  final pol = codes.where(_polyols.contains).toList()..sort();
  if (pol.isNotEmpty) {
    final found = text.contains('przeczyszczaj');
    reqs.add(SummaryRow(
        found ? Mark.ok : Mark.unsure,
        pol.join(', '),
        found
            ? 'Ostrzeżenie o działaniu przeczyszczającym jest w odczycie.'
            : 'Poliole: jeśli stanowią ponad 10% produktu, wymagane ostrzeżenie o działaniu przeczyszczającym - nie znaleziono w odczycie.'));
  }
  final caf = caffeineAmount(
      [for (final c in checks) c.ingredient], rawText);
  if (caf.mgPer100 != null && caf.mgPer100! * 10 > 150) {
    final found = text.contains('zawartosc kofein');
    reqs.add(SummaryRow(
        found ? Mark.ok : Mark.bad,
        'Kofeina powyżej 150 mg/l',
        found
            ? 'Ostrzeżenie dla dzieci i kobiet w ciąży jest w odczycie.'
            : 'Wymagane ostrzeżenie „Wysoka zawartość kofeiny…” - nie znaleziono w odczycie.'));
  }
  if (reqs.isEmpty) {
    rows.add(const SummaryRow(Mark.ok, 'Ostrzeżenia',
        'Nie znaleziono składników wymagających dodatkowych napisów (z tych, które znam).'));
  } else {
    rows.addAll(reqs);
  }
  return rows;
}
