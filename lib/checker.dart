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
    if (code == null) return IngredientCheck(i, null);
    final info = db.lookup(code);
    return IngredientCheck(
      i,
      info?.status ?? AdditiveStatus.notFound,
      info: info,
    );
  }
}
