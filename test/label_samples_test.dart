import 'package:flutter_test/flutter_test.dart';
import 'package:label_check/additive_db.dart';
import 'package:label_check/checker.dart';
import 'package:label_check/ingredient_parser.dart';

// Tekst jak z OCR puszek (zdjęcia testowe): opis, lista składników, stopka.
const _can1 = '''
Napój energetyzujący gazowany z tauryną i kofeiną i dodatkiem witamin. Produkt pasteryzowany. Wysoka zawartość kofeiny; nie zaleca się stosowania u dzieci (32 mg/100 ml).
Składniki: woda, cukier, kwas: kwas cytrynowy; dwutlenek węgla, regulator kwasowości: cytryniany sodu; 0,35 % tauryna, barwnik: karmel; 0,03 % kofeina, aromat, witaminy: niacyna, kwas pantotenowy, witamina B6, witamina B12. Najlepiej spożyć przed końcem: data i numer partii na spodzie puszki.
''';

const _can2 = '''
Napój energetyczny gazowany z tauryną i kofeiną o smaku granata i śliwki. Zawiera substancję słodzącą.
Składniki: woda, dwutlenek węgla, regulatory kwasowości: kwas cytrynowy, cytryniany sodu; 0,4 % tauryna, aromaty, kofeina, koncentrat z marchwi czarnej, substancja słodząca: sukraloza; witaminy: niacyna, kwas pantotenowy, witamina B6, witamina B12. Najlepiej spożyć przed końcem: data i numer partii na spodzie puszki.
''';

const _json = '''
{"meta":{"sample":true},"additives":[
{"code":"E330","name":"Kwas cytrynowy","status":"allowed","source":"t"},
{"code":"E331","name":"Cytryniany sodu","status":"allowed","source":"t"},
{"code":"E290","name":"Dwutlenek węgla","status":"allowed","source":"t"},
{"code":"E150","name":"Karmel (rodzaj nieokreślony)","status":"restricted","source":"t","aliases":["karmel"]},
{"code":"E955","name":"Sukraloza","status":"restricted","source":"t"}
]}''';

void main() {
  const parser = IngredientParser();
  final checker = LabelChecker(AdditiveDatabase.fromJsonString(_json));

  test('puszka 1: wycina opis i stopkę, rozpoznaje funkcje i procenty', () {
    final r = parser.parse(_can1);
    expect(r.first.name, 'woda');
    expect(r.last.name, 'witamina B12');
    expect(r.length, 13);
    final tauryna = r.firstWhere((i) => i.name == 'tauryna');
    expect(tauryna.percent, '0.35%');
    final karmel = r.firstWhere((i) => i.name == 'karmel');
    expect(karmel.function, 'barwnik');
  });

  test('puszka 1: dodatki rozpoznane po nazwie, bez numerów E', () {
    final c = checker.check(parser.parse(_can1));
    AdditiveStatus? st(String n) =>
        c.firstWhere((x) => x.ingredient.name == n).status;
    expect(st('kwas cytrynowy'), AdditiveStatus.allowed);
    expect(st('cytryniany sodu'), AdditiveStatus.allowed);
    expect(st('dwutlenek węgla'), AdditiveStatus.allowed);
    expect(st('karmel'), AdditiveStatus.restricted);
    expect(st('cukier'), isNull);
    expect(st('kofeina'), isNull);
  });

  test('puszka 2: sukraloza i grupa regulatorów kwasowości', () {
    final r = parser.parse(_can2);
    expect(r.map((i) => i.name), containsAll(['sukraloza', 'cytryniany sodu']));
    final c = checker.check(r);
    expect(
        c.firstWhere((x) => x.ingredient.name == 'sukraloza').status,
        AdditiveStatus.restricted);
    expect(worstStatus(c), AdditiveStatus.restricted);
  });
}
