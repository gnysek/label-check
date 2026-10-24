import 'additive_db.dart';
import 'ingredient_parser.dart';

/// Wynik sprawdzenia jednego składnika.
class IngredientCheck {
  const IngredientCheck(this.ingredient, this.status,
      {this.info, this.approximate = false});

  final Ingredient ingredient;

  /// null = zwykły składnik bez numeru E (nie podlega sprawdzeniu dodatków).
  final AdditiveStatus? status;

  final AdditiveInfo? info;

  /// True, gdy dopasowano po nazwie z przybliżeniem (możliwa literówka OCR).
  final bool approximate;
}

class LabelChecker {
  const LabelChecker(this.db);

  final AdditiveDatabase db;

  List<IngredientCheck> check(List<Ingredient> ingredients) =>
      [for (final i in ingredients) _check(i)];

  IngredientCheck _check(Ingredient original) {
    final fixedName = db.correctText(original.name);
    final i = fixedName == original.name
        ? original
        : Ingredient(
            name: fixedName,
            eNumber: original.eNumber,
            percent: original.percent,
            function: original.function,
            rawName: original.name,
          );
    final code = i.eNumber;
    if (code == null) {
      // Etykiety często podają nazwę ("cytryniany sodu") bez numeru E.
      final m = db.matchByName(i.name);
      if (m == null) return IngredientCheck(i, null);
      // Pokaż poprawną nazwę dodatku (np. "kKWas cytrynowy" -> "kwas
      // cytrynowy"), a odczyt z OCR zachowaj w rawName.
      var shown = m.matched;
      if (shown.length > 1 && shown[1] == shown[1].toLowerCase()) {
        shown = shown[0].toLowerCase() + shown.substring(1);
      }
      final changed = shown != i.name;
      final shownIngredient = changed
          ? Ingredient(
              name: shown,
              eNumber: i.eNumber,
              percent: i.percent,
              function: i.function,
              rawName: i.rawName ?? i.name,
            )
          : i;
      return IngredientCheck(shownIngredient, m.info.status,
          info: m.info, approximate: !m.exact);
    }
    final info = db.lookup(code);
    return IngredientCheck(
      i,
      info?.status ?? AdditiveStatus.notFound,
      info: info,
    );
  }
}

/// Najgorszy status na liście (zakaz > ograniczenia > brak w bazie > dozwolony).
/// null, jeśli żaden składnik nie ma numeru E.
AdditiveStatus? worstStatus(List<IngredientCheck> checks) {
  const order = [
    AdditiveStatus.banned,
    AdditiveStatus.restricted,
    AdditiveStatus.notFound,
    AdditiveStatus.unverified,
    AdditiveStatus.allowed,
  ];
  for (final s in order) {
    if (checks.any((c) => c.status == s)) return s;
  }
  return null;
}
