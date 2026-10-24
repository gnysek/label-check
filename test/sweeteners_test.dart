import 'package:flutter_test/flutter_test.dart';
import 'package:label_check/sweeteners.dart';

void main() {
  test('cukry i słodziki', () {
    expect(detectSweet('cukier'), SweetKind.sugar);
    expect(detectSweet('syrop fruktozowy'), SweetKind.sugar);
    expect(detectSweet('maltodekstryna'), SweetKind.sugar);
    expect(detectSweet('trehaloza*'), SweetKind.sugar);
    expect(detectSweet('aspartam', code: 'E951'), SweetKind.sweetener);
    expect(detectSweet('sorbitol'), SweetKind.sweetener);
    expect(detectSweet('x', code: 'E960'), SweetKind.sweetener);
    expect(detectSweet('estry sacharozy i kwasów tłuszczowych'), isNull);
    expect(detectSweet('woda'), isNull);
    expect(detectSweet('kwas cytrynowy'), isNull);
  });
}
