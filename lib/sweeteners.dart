import 'package:flutter/material.dart';

import 'additive_db.dart';

/// Rodzaj składnika słodzącego.
enum SweetKind {
  sugar('cukier', Icons.cake_outlined),
  sweetener('słodzik', Icons.science_outlined);

  const SweetKind(this.label, this.icon);
  final String label;
  final IconData icon;
}

const _sugarStems = [
  'cukier', 'cukru', 'glukoz', 'fruktoz', 'sacharoz', 'trehaloz', 'maltoz',
  'laktoz', 'dekstroz', 'galaktoz', 'miod', 'melas', 'syrop', 'maltodekstryn',
  'slodow', 'agaw', 'izoglukoz',
];

const _sweetenerStems = [
  'slodzik', 'slodzac', 'stewi', 'stewiol', 'aspartam', 'acesulfam', 'sukraloz',
  'sacharyn', 'cyklaminian', 'sorbitol', 'ksylitol', 'erytryt', 'maltitol',
  'mannitol', 'izomalt', 'laktitol', 'neotam', 'taumatyn',
];

const _sweetenerCodes = {
  'E420', 'E421', 'E950', 'E951', 'E952', 'E953', 'E954', 'E955', 'E957',
  'E959', 'E960', 'E961', 'E962', 'E964', 'E965', 'E966', 'E967', 'E968',
  'E969',
};

/// Rozpoznaje cukry proste/syropy i słodziki po nazwie lub numerze E.
/// Zwraca null, jeśli składnik nie jest słodzący.
SweetKind? detectSweet(String name, {String? code}) {
  final c = code?.toUpperCase().replaceAll(' ', '');
  if (c != null && _sweetenerCodes.contains(c)) return SweetKind.sweetener;
  final f = AdditiveDatabase.fold(name);
  // Emulgatory: "estry sacharozy i kwasów tłuszczowych" to nie cukier.
  if (f.contains('estry') || f.contains('kwas')) return null;
  final words = RegExp(r'[a-z]+').allMatches(f).map((m) => m.group(0)!);
  for (final w in words) {
    for (final s in _sweetenerStems) {
      if (w.startsWith(s)) return SweetKind.sweetener;
    }
  }
  for (final w in AdditiveDatabase.fold(name).split(RegExp(r'[^a-z]+'))) {
    for (final s in _sugarStems) {
      if (w.startsWith(s)) return SweetKind.sugar;
    }
  }
  return null;
}
