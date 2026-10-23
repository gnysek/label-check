import 'package:flutter_test/flutter_test.dart';
import 'package:label_check/additive_db.dart';
import 'package:label_check/checker.dart';
import 'package:label_check/ingredient_parser.dart';

const _json = '''
{
  "meta": {"sample": true},
  "additives": [
    {"code": "E171", "name": "Dwutlenek tytanu", "status": "banned", "source": "test"},
    {"code": "E330", "name": "Kwas cytrynowy", "status": "allowed", "source": "test"},
    {"code": "E160a", "name": "Karoteny", "status": "allowed", "source": "test"},
    {"code": "E250", "name": "Azotyn sodu", "status": "restricted", "source": "test"}
  ]
}
''';

void main() {
  final db = AdditiveDatabase.fromJsonString(_json);
  final checker = LabelChecker(db);
  const parser = IngredientParser();

  test('baza wczytuje wpisy i flagę danych przykładowych', () {
    expect(db.length, 4);
    expect(db.isSample, isTrue);
  });

  test('normalizacja kodów przy wyszukiwaniu', () {
    expect(db.lookup('e 330')?.name, 'Kwas cytrynowy');
    expect(db.lookup('E160A')?.name, 'Karoteny');
  });

  test('statusy: zakazany, dozwolony, z ograniczeniami, brak w bazie', () {
    final result = checker.check(parser.parse(
        'cukier, barwnik E171, kwas cytrynowy E330, azotyn sodu E250, E999'));
    expect(result[0].status, isNull);
    expect(result[1].status, AdditiveStatus.banned);
    expect(result[2].status, AdditiveStatus.allowed);
    expect(result[3].status, AdditiveStatus.restricted);
    expect(result[4].status, AdditiveStatus.notFound);
  });
}
