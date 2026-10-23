import 'package:flutter_test/flutter_test.dart';
import 'package:label_check/scan_store.dart';

void main() {
  test('tworzy, zmienia i usuwa skan', () async {
    final store = ScanStore(storage: MemoryStorage());
    final a = await store.create('cukier, E330');
    expect((await store.load()).single.text, 'cukier, E330');

    await store.updateText(a.id, 'sól');
    expect((await store.load()).single.text, 'sól');

    await store.delete(a.id);
    expect(await store.load(), isEmpty);
  });

  test('najnowszy skan jest pierwszy', () async {
    final store = ScanStore(storage: MemoryStorage());
    await store.create('pierwszy');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await store.create('drugi');
    final all = await store.load();
    expect(all.map((s) => s.text).toList(), ['drugi', 'pierwszy']);
  });

  test('restore przywraca usunięty skan, a updateText ignoruje nieznane id',
      () async {
    final store = ScanStore(storage: MemoryStorage());
    final a = await store.create('mleko');
    await store.delete(a.id);
    await store.restore(a);
    expect((await store.load()).single.text, 'mleko');

    await store.updateText('nie-ma-takiego', 'x');
    expect((await store.load()).length, 1);
  });
}
