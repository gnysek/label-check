import 'package:flutter_test/flutter_test.dart';
import 'package:label_check/e_groups.dart';

void main() {
  test('grupy wg numeru E', () {
    expect(groupForCode('E102'), 'barwnik');
    expect(groupForCode('E211'), 'konserwant');
    expect(groupForCode('E951'), 'substancja słodząca');
    expect(groupForCode('E1442'), 'skrobia modyfikowana');
    expect(groupForCode('E160a'), 'barwnik');
    expect(groupForCode('abc'), isNull);
  });
}
