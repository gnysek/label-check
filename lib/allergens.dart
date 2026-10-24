import 'package:flutter/material.dart';

import 'additive_db.dart';

/// 14 alergenów z załącznika II rozporządzenia (UE) nr 1169/2011.
enum Allergen {
  gluten('gluten', Icons.grain),
  crustaceans('skorupiaki', Icons.set_meal_outlined),
  eggs('jaja', Icons.egg_outlined),
  fish('ryby', Icons.set_meal_outlined),
  peanuts('orzeszki ziemne', Icons.eco_outlined),
  soy('soja', Icons.eco_outlined),
  milk('mleko', Icons.local_drink_outlined),
  nuts('orzechy', Icons.nature_outlined),
  celery('seler', Icons.grass_outlined),
  mustard('gorczyca', Icons.grass_outlined),
  sesame('sezam', Icons.grain),
  sulphites('siarczyny', Icons.science_outlined),
  lupin('łubin', Icons.local_florist_outlined),
  molluscs('mięczaki', Icons.set_meal_outlined);

  const Allergen(this.label, this.icon);

  final String label;
  final IconData icon;
}

// Początki wyrazów (po złożeniu do małych liter bez polskich znaków).
const Map<Allergen, List<String>> _stems = {
  Allergen.gluten: [
    'pszen', 'zyt', 'jeczmien', 'owsian', 'owies', 'owsa', 'orkisz', 'kamut',
    'gluten', '=slod', 'slodu', 'slodow', 'semolin',
  ],
  Allergen.crustaceans: ['skorupiak', 'krewet', 'krab', 'homar', 'langust'],
  Allergen.eggs: ['jaj', 'jajk', 'zoltk', 'jajeczn', 'albumin'],
  Allergen.fish: [
    '=ryb', '=ryba', '=ryby', '=rybie', 'rybn', 'rybi', 'losos', 'tunczyk', 'sledz', 'dorsz', 'makrel', 'sardyn',
    'anchois', 'sandacz', 'karp', 'pstrag', 'mintaj',
  ],
  Allergen.peanuts: ['orzeszk', 'arachid'],
  Allergen.soy: ['soj', 'soi'],
  Allergen.milk: [
    '=mleko', '=mleka', '=mleku', '=mlekiem', 'mleczn', 'smietan', 'serwatk',
    'kazein', 'laktoz', 'jogurt', 'kefir', 'maslank', 'twarog', '=maslo',
    '=masla', '=ser', '=sery', '=sera', '=serem',
  ],
  Allergen.nuts: [
    'migdal', 'laskow', 'nerkowc', 'pistacj', 'pekan', 'makadami',
    'brazylijsk', 'orzech',
  ],
  Allergen.celery: ['seler'],
  Allergen.mustard: ['gorczyc', 'musztard'],
  Allergen.sesame: ['sezam'],
  Allergen.sulphites: ['siarczyn'],
  Allergen.lupin: ['lubin'],
  Allergen.molluscs: [
    'mieczak', 'malz', 'ostryg', 'kalmar', 'osmiornic', 'slimak',
  ],
};

/// Wykrywa możliwe alergeny po nazwie składnika (i kodzie E dla siarczynów).
/// To wskazówka, nie gwarancja - zawsze sprawdź pełną etykietę.
Set<Allergen> detectAllergens(String name, {String? code}) {
  final folded = AdditiveDatabase.fold(name);
  final tokens =
      RegExp(r'[a-z]+').allMatches(folded).map((m) => m.group(0)!).toList();
  final found = <Allergen>{};

  final isCoconut = tokens.any((t) => t.startsWith('kokos'));
  final isCocoaOrShea =
      tokens.any((t) => t.startsWith('kakao') || t.startsWith('shea'));

  bool hasStem(List<String> stems) => tokens.any((t) => stems.any((s) =>
      s.startsWith('=') ? t == s.substring(1) : t.startsWith(s)));

  for (final entry in _stems.entries) {
    final match = hasStem(entry.value);
    if (!match) continue;
    // Mleko/masło kokosowe i masło kakaowe to nie nabiał.
    if (entry.key == Allergen.milk && (isCoconut || isCocoaOrShea)) continue;
    if (entry.key == Allergen.nuts && isCoconut) continue;
    // Orzeszki ziemne liczone osobno od orzechów.
    if (entry.key == Allergen.nuts &&
        tokens.any((t) => t.startsWith('orzech')) &&
        tokens.any((t) => t.startsWith('ziemn'))) {
      continue;
    }
    found.add(entry.key);
  }
  if (tokens.any((t) => t.startsWith('orzech')) &&
      tokens.any((t) => t.startsWith('ziemn'))) {
    found.add(Allergen.peanuts);
  }
  if (folded.contains('dwutlenek siarki')) found.add(Allergen.sulphites);

  if (code != null) {
    final n = int.tryParse(RegExp(r'\d+').firstMatch(code)?.group(0) ?? '');
    if (n != null && n >= 220 && n <= 228) found.add(Allergen.sulphites);
    if (code.toUpperCase() == 'E1105') found.add(Allergen.eggs); // lizozym
    if (code.toUpperCase() == 'E322' && tokens.any((t) => t.startsWith('soj'))) {
      found.add(Allergen.soy);
    }
  }
  return found;
}
