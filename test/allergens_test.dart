import 'package:flutter_test/flutter_test.dart';
import 'package:label_check/allergens.dart';

void main() {
  test('rozpoznaje typowe alergeny po nazwie', () {
    expect(detectAllergens('mąka pszenna'), {Allergen.gluten});
    expect(detectAllergens('mąka SOJOWA'), {Allergen.soy});
    expect(detectAllergens('lecytyny z soi'), {Allergen.soy});
    expect(detectAllergens('jaja'), {Allergen.eggs});
    expect(detectAllergens('serwatka w proszku'), {Allergen.milk});
    expect(detectAllergens('ser żółty'), {Allergen.milk});
    expect(detectAllergens('orzechy laskowe'), {Allergen.nuts});
    expect(detectAllergens('orzechy ziemne'), {Allergen.peanuts});
    expect(detectAllergens('dwutlenek siarki'), {Allergen.sulphites});
    expect(detectAllergens('pirosiarczyn potasu', code: 'E224'),
        {Allergen.sulphites});
  });

  test('nie myli podobnych składników', () {
    expect(detectAllergens('masło kakaowe'), isEmpty);
    expect(detectAllergens('mleko kokosowe'), isEmpty);
    expect(detectAllergens('mąka kokosowa'), isEmpty);
    expect(detectAllergens('woda'), isEmpty);
    expect(detectAllergens('cukier'), isEmpty);
    expect(detectAllergens('serce'), isEmpty);
    expect(detectAllergens('ryboflawina'), isEmpty);
    expect(detectAllergens('kwas mlekowy'), isEmpty);
    expect(detectAllergens('mleczan sodu'), isEmpty);
    expect(detectAllergens('syrop słodki'), isEmpty);
    expect(detectAllergens('olej słonecznikowy'), isEmpty);
  });
}
