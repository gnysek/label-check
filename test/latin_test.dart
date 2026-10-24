import 'package:flutter_test/flutter_test.dart';
import 'package:label_check/additive_db.dart';
import 'package:label_check/latin_names.dart';

void main() {
  test('łacińskie nazwy -> polskie z dopełniaczem po "ze"', () {
    final r = latinize('proszek ze Spirulina platensis')!;
    expect(r.name, 'proszek ze spiruliny');
    expect(r.latin, 'Spirulina platensis');
    expect(latinize('Spirulina platensis')!.name, 'spirulina');
    expect(latinize('mąka pszenna'), isNull);
  });

  test('2e -> ze oraz zasada małej litery', () {
    final db = AdditiveDatabase.fromJsonString('{"additives":[]}');
    expect(db.correctText('proszek 2e Spirulina'), 'proszek ze Spirulina');
    expect(db.correctText('estry sacharOzy kKWas SOJOWA Mąka'),
        'estry sacharozy kkwas SOJOWA Mąka');
  });
}
