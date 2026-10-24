import 'package:flutter_test/flutter_test.dart';
import 'package:label_check/additive_db.dart';
import 'package:label_check/checker.dart';
import 'package:label_check/ingredient_parser.dart';
import 'package:label_check/summary.dart';

const _json = '''
{"meta":{},"additives":[
{"code":"E120","name":"Koszenila","status":"restricted","source":"t"},
{"code":"E102","name":"Tartrazyna","status":"restricted","source":"t"},
{"code":"E471","name":"Mono- i diglicerydy","status":"allowed","source":"t"},
{"code":"E330","name":"Kwas cytrynowy","status":"allowed","source":"t"}
]}''';

void main() {
  const parser = IngredientParser();
  final checker = LabelChecker(AdditiveDatabase.fromJsonString(_json));

  List<SummaryRow> run(String raw) =>
      buildSummary(checker.check(parser.parse(raw)), raw);

  SummaryRow row(List<SummaryRow> r, String label) =>
      r.firstWhere((x) => x.label.startsWith(label));

  test('koszenila: nie dla wegetarian, mleko: nie dla wegan', () {
    final r = run('Składniki: woda, mleko, barwnik E120');
    expect(row(r, 'Wegetarianie').mark, Mark.bad);
    expect(row(r, 'Weganie').mark, Mark.bad);
    expect(row(r, 'Alergeny').text, contains('mleko'));
  });

  test('E471 bywa zwierzęce: niepewne, a prosty skład jest ok', () {
    final r = run('Składniki: woda, cukier, emulgator E471');
    expect(row(r, 'Wegetarianie').mark, Mark.unsure);
    final simple = run('Składniki: woda, cukier, kwas cytrynowy');
    expect(row(simple, 'Wegetarianie').mark, Mark.ok);
    expect(row(simple, 'Weganie').mark, Mark.ok);
    expect(row(simple, 'Ostrzeżenia').mark, Mark.ok);
  });

  test('barwnik E102 bez ostrzeżenia w tekście jest błędem, z ostrzeżeniem ok', () {
    final bad = run('Składniki: woda, barwnik E102');
    expect(row(bad, 'Barwniki').mark, Mark.bad);
    final ok = run(
        'Składniki: woda, barwnik E102. Może mieć szkodliwy wpływ na aktywność i uwagę u dzieci');
    expect(row(ok, 'Barwniki').mark, Mark.ok);
  });
}
