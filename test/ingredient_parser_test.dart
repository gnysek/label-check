import 'package:flutter_test/flutter_test.dart';
import 'package:label_check/ingredient_parser.dart';

void main() {
  const parser = IngredientParser();

  test('dzieli listę po przecinkach i usuwa nagłówek oraz kropkę', () {
    final result =
        parser.parse('Składniki: mąka pszenna, cukier, barwnik E102, sól.');
    expect(result.map((i) => i.name).toList(),
        ['mąka pszenna', 'cukier', 'barwnik E102', 'sól']);
    expect(result[2].eNumber, 'E102');
  });

  test('nie dzieli wewnątrz nawiasów', () {
    final result = parser.parse('czekolada (kakao, cukier), mleko');
    expect(result.length, 2);
    expect(result.first.name, 'czekolada (kakao, cukier)');
  });

  test('wyciąga procenty', () {
    final result = parser.parse('mąka pszenna 62,5%, woda');
    expect(result.first.name, 'mąka pszenna');
    expect(result.first.percent, '62.5%');
  });

  test('normalizuje numery E (spacja, przyrostek)', () {
    final result =
        parser.parse('regulator kwasowości E 330, przeciwutleniacz E160a');
    expect(result[0].eNumber, 'E330');
    expect(result[1].eNumber, 'E160a');
  });

  test('poprawia typową pomyłkę OCR O zamiast 0 w numerze E', () {
    final result = parser.parse('barwnik E1O2');
    expect(result.single.eNumber, 'E102');
  });

  test('obsługuje nagłówek angielski i łamanie linii', () {
    final result = parser.parse('Ingredients:\nsugar,\nsalt');
    expect(result.map((i) => i.name).toList(), ['sugar', 'salt']);
  });

  test('pusty tekst daje pustą listę', () {
    expect(parser.parse('   '), isEmpty);
  });
}
