import 'additive_db.dart';
import 'ingredient_parser.dart';

/// Wynik sprawdzenia jednego składnika.
class IngredientCheck {
  const IngredientCheck(this.ingredient, this.status, {this.info});

  final Ingredient ingredient;

  /// null = zwykły składnik bez numeru E (nie podlega sprawdzeniu dodatków).
  final AdditiveStatus? status;

  final AdditiveInfo? info;
}

class LabelChecker {
  const LabelChecker(this.db);

  final AdditiveDatabase db;

  List<IngredientCheck> check(List<Ingredient> ingredients) =>
      [for (final i in ingredients) _check(i)];

  IngredientCheck _check(Ingredient i) {
    final code = i.eNumber;
    if (code == null) {
      // Etykiety często podają nazwę ("cytryniany sodu") bez numeru E.
      final byName = db.lookupByName(i.name);
      if (byName == null) return IngredientCheck(i, null);
      return IngredientCheck(i, byName.status, info: byName);
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
    AdditiveStatus.allowed,
  ];
  for (final s in order) {
    if (checks.any((c) => c.status == s)) return s;
  }
  return null;
}
