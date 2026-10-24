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

const _ice = '''
PL Deser mrożony o smaku winogronowym 75 g. FRU CHI SOTI NATURAL.
Składniki: woda, cukier, olej palmowy, mąka SOJOWA, koncentrat soku z czerwonych winogron (6,97%), olej kokosowy, syrop fruktozowy, maltodekstryna, enzymatycznie hydrolizowana mąka OWSIANA, skrobia modyfikowana (E 1442), emulgatory (mono- i diglicerydy kwasów tłuszczowych, estry sacharozy i kwasów tłuszczowych, lecytyny z SOI), stabilizatory (guma celulozowa, guma ksantanowa, karagen, guma guar), regulatory kwasowości (cytryniany sodu, kwas cytrynowy, kwas jabłkowy), barwniki (czerwień buraczana, antocyjany), proszek ze Spirulina platensis, olej słonecznikowy, trehaloza*, aromaty. *Trehaloza jest źródłem glukozy. Może zawierać: mleko, jaja. Najlepiej spożyć przed / Numer partii: nadruk na opakowaniu.
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

  test('rozmyte zdjęcie: kropki zamiast przecinków nie ucinają listy', () {
    final r = parser.parse(
        'Składniki: woda. cukier.kwas cytrynowy. cytryniany sodu, aromat. Najlepiej spożyć przed końcem: data');
    expect(r.map((i) => i.name),
        ['woda', 'cukier', 'kwas cytrynowy', 'cytryniany sodu', 'aromat']);
  });

  test('deser mrożony: grupy w nawiasach rozbijane na składniki, E 1442', () {
    final r = parser.parse(_ice);
    expect(r.length, 26);
    expect(r.first.name, 'woda');
    expect(r.last.name, 'aromaty');
    final skrobia = r.firstWhere((i) => i.name.startsWith('skrobia'));
    expect(skrobia.eNumber, 'E1442');
    final guar = r.firstWhere((i) => i.name == 'guma guar');
    expect(guar.function, 'stabilizatory');
    final koncentrat = r.firstWhere((i) => i.name.startsWith('koncentrat'));
    expect(koncentrat.percent, '6.97%');
    expect(koncentrat.name, 'koncentrat soku z czerwonych winogron');
  });

  test('błędy OCR z prawdziwego zdjęcia: literówki, S01, cudzysłów po kropce', () {
    final db = AdditiveDatabase.fromJsonString('''
{"meta":{},"additives":[
{"code":"E322","name":"Lecytyny","status":"allowed","source":"t","aliases":["lecytyny z soi"]},
{"code":"E162","name":"Czerwień buraczana","status":"allowed","source":"t"},
{"code":"E471","name":"Mono- i diglicerydy kwasów tłuszczowych","status":"allowed","source":"t"}
]}''');
    final c = LabelChecker(db).check(parser.parse(
        'Składniki: woda, mono- i diglicerydy kwasów thuszczowych, lecytyny z S01, zerwień buraczana, trehaloza*, aromaty."Trehaloza jest źródłem glukozy.'));
    expect(c.map((x) => x.ingredient.name).last, 'aromaty');
    AdditiveInfo? info(String n) =>
        c.firstWhere((x) => x.ingredient.name == n).info;
    expect(info('lecytyny z soi')?.code, 'E322');
    expect(info('czerwień buraczana')?.code, 'E162');
    expect(info('mono- i diglicerydy kwasów tłuszczowych')?.code, 'E471');
    final beet = c.firstWhere((x) => x.ingredient.name == 'czerwień buraczana');
    expect(beet.approximate, isTrue);
    expect(beet.ingredient.rawName, 'zerwień buraczana');
    expect(c.firstWhere((x) => x.ingredient.name == 'lecytyny z soi').approximate, isFalse);
  });

  test('słownik poprawia literówki OCR w zwykłych składnikach', () {
    final db = AdditiveDatabase.fromJsonString(_json, dictionary: const [
      'mąka sojowa',
      'proszek',
      'tłuszczowych',
      'olej słonecznikowy',
      'koncentrat soku',
    ]);
    expect(db.correctText('maka SOJOWA'), 'mąka SOJOWA');
    expect(db.correctText('prosSzek'), 'proszek');
    expect(db.correctText('thuszczowych'), 'tłuszczowych');
    expect(db.correctText('olej sloneczmikowy'), 'olej słonecznikowy');
    // nieznane słowo zostaje bez zmian
    expect(db.correctText('Spirulina platensis'), 'Spirulina platensis');
    final c = LabelChecker(db).check(parser.parse('Składniki: prosSzek, woda'));
    expect(c.first.ingredient.name, 'proszek');
    expect(c.first.ingredient.rawName, 'prosSzek');
  });

  test('trzy miejsca po przecinku kończące się na 6 to procent z błędnym %', () {
    final r = parser.parse(
        'Składniki: koncentrat soku z winogron (6,976), cukier, sól 0,5 g, woda 12,346 g');
    expect(r[0].percent, '6.97%');
    expect(r[0].name, 'koncentrat soku z winogron');
    expect(r[2].percent, isNull);
    expect(r[3].percent, isNull);
  });

  test('procent odczytany jako "96" (6,9796 -> 6,97%)', () {
    final r = parser.parse('Składniki: woda, koncentrat soku z winogron (6,9796), olej');
    expect(r[1].percent, '6.97%');
    expect(r[1].name, 'koncentrat soku z winogron');
  });

  test('mieszana wielkość liter w słowie jest poprawiana', () {
    final db = AdditiveDatabase.fromJsonString(
        '{"additives":[{"code":"E473","name":"Estry sacharozy i kwasów tłuszczowych","status":"restricted","source":"t"}]}',
        dictionary: ['estry sacharozy i kwasów tłuszczowych']);
    expect(db.correctText('estry sacharOzy i kwasów'), contains('sacharozy'));
  });

  test('brak nagłówka: wybiera zdanie z listą, odcina zniekształconą stopkę', () {
    final r = parser.parse(
        'Npój energetyzujący gazowany z tauryną i kofeiną. Produkt pasteryzowany. Woda, cukier, kwas cytrynowy, dwutlenek węgla, tauryna. Chronić przed słońcem');
    expect(r.map((i) => i.name),
        ['Woda', 'cukier', 'kwas cytrynowy', 'dwutlenek węgla', 'tauryna']);
    final f = parser.parse(
        'Sktadniki: woda, aromaty, witamina B6, Mo hethowvwatw chłodnym, zacienionym miejscu');
    expect(f.last.name, 'witamina B6');
  });
}
