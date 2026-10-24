import 'package:flutter_test/flutter_test.dart';
import 'package:label_check/ingredient_parser.dart';
import 'package:label_check/limits.dart';

void main() {
  const parser = IngredientParser();
  const text = '''
Napój energetyzujący gazowany z tauryną i kofeiną. Wysoka zawartość kofeiny; nie zaleca się stosowania u dzieci (32 mg/100 ml).
Składniki: woda, cukier, 0,35 % tauryna, 0,03 % kofeina, aromat. Najlepiej spożyć przed końcem. Objętość netto: 250 ml
''';

  test('kofeina: zawartość z etykiety, ostrzeżenie, ustawa, opakowanie', () {
    final notes = evaluateLimits(parser.parse(text), text);
    expect(notes, hasLength(1));
    final all = notes.first.lines.join('\n');
    expect(all, contains('32 mg/100 ml'));
    expect(all, contains('320 mg/l'));
    expect(all, contains('Ostrzeżenie jest w odczytanym tekście'));
    expect(all, contains('poniżej 18 lat'));
    expect(all, contains('80 mg kofeiny'));
  });

  test('bez kofeiny brak notatek, z procentu przy braku mg/100 ml', () {
    expect(evaluateLimits(parser.parse('Składniki: woda, cukier'), 'woda'), isEmpty);
    const raw = 'Składniki: woda, 0,03 % kofeina';
    final n = evaluateLimits(parser.parse(raw), raw);
    expect(n.first.lines.first, contains('30 mg/100 ml'));
  });
}
