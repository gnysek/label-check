import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:label_check/image_warp.dart';

void main() {
  test('homografia przenosi rogi kwadratu na rogi czworokąta', () {
    const a = Pt(10, 20);
    const b = Pt(110, 30);
    const c = Pt(100, 130);
    const d = Pt(5, 120);
    final h = Homography(a, b, c, d);
    for (final (u, v, p) in [(0.0, 0.0, a), (1.0, 0.0, b), (1.0, 1.0, c), (0.0, 1.0, d)]) {
      final m = h.map(u, v);
      expect(m.x, closeTo(p.x, 1e-6));
      expect(m.y, closeTo(p.y, 1e-6));
    }
  });

  test('walec: środek wyniku to środek między krawędziami', () {
    const pts = [Pt(0, 0), Pt(100, 0), Pt(100, 50), Pt(0, 50), Pt(50, 0), Pt(50, 50)];
    final m = warpMap(modeCylinder, pts, 0.5, 0.5);
    expect(m.x, closeTo(50, 1e-6));
    expect(m.y, closeTo(25, 1e-6));
    final left = warpMap(modeCylinder, pts, 0.0, 0.0);
    expect(left.x, closeTo(0, 1e-6));
  });

  test('bez zmian i bez obrotu obraz zostaje taki sam', () {
    final bytes = Uint8List.fromList([
      for (var i = 0; i < 4 * 4; i++) ...[i * 10, 100, 200, 255],
    ]);
    final r = warpPixels(WarpRequest(
      bytes: bytes,
      srcW: 4,
      srcH: 4,
      angle: 0,
      mode: modeNone,
      coords: const [0, 0, 4, 0, 4, 4, 0, 4, 2, 0, 2, 4],
    ));
    expect(r.width, 4);
    expect(r.height, 4);
    expect(r.bytes[0], closeTo(0, 40));
  });
}
