import 'dart:math' as math;
import 'dart:typed_data';

/// Punkt w układzie pikseli obrazu.
class Pt {
  const Pt(this.x, this.y);

  final double x;
  final double y;

  Pt operator +(Pt o) => Pt(x + o.x, y + o.y);
  Pt operator -(Pt o) => Pt(x - o.x, y - o.y);
  Pt operator *(double k) => Pt(x * k, y * k);
  double get length => math.sqrt(x * x + y * y);
}

/// Przekształcenie rzutowe kwadratu jednostkowego na dowolny czworokąt
/// (p0 = lewy górny, p1 = prawy górny, p2 = prawy dolny, p3 = lewy dolny).
class Homography {
  Homography(Pt p0, Pt p1, Pt p2, Pt p3) {
    final dx1 = p1.x - p2.x;
    final dx2 = p3.x - p2.x;
    final dx3 = p0.x - p1.x + p2.x - p3.x;
    final dy1 = p1.y - p2.y;
    final dy2 = p3.y - p2.y;
    final dy3 = p0.y - p1.y + p2.y - p3.y;
    if (dx3.abs() < 1e-9 && dy3.abs() < 1e-9) {
      g = 0;
      h = 0;
      a = p1.x - p0.x;
      b = p2.x - p1.x;
      d = p1.y - p0.y;
      e = p2.y - p1.y;
    } else {
      final det = dx1 * dy2 - dx2 * dy1;
      g = (dx3 * dy2 - dx2 * dy3) / det;
      h = (dx1 * dy3 - dx3 * dy1) / det;
      a = p1.x - p0.x + g * p1.x;
      b = p3.x - p0.x + h * p3.x;
      d = p1.y - p0.y + g * p1.y;
      e = p3.y - p0.y + h * p3.y;
    }
    c = p0.x;
    f = p0.y;
  }

  late final double a, b, c, d, e, f, g, h;

  Pt map(double u, double v) {
    final w = g * u + h * v + 1;
    return Pt((a * u + b * v + c) / w, (d * u + e * v + f) / w);
  }
}

/// Krzywa (parabola) od [p0] do [p2] przechodząca przez punkt [m] dla t = 0.5.
Pt quadThrough(Pt p0, Pt m, Pt p2, double t) {
  final c = controlPoint(p0, m, p2);
  final s = 1 - t;
  return p0 * (s * s) + c * (2 * s * t) + p2 * (t * t);
}

/// Punkt kontrolny krzywej Beziera, która przechodzi przez [m] w środku.
Pt controlPoint(Pt p0, Pt m, Pt p2) => m * 2 - (p0 + p2) * 0.5;

/// Połowa kąta widoku puszki zakładana między lewą a prawą krawędzią.
const double cylinderHalfAngle = 80 * math.pi / 180;

/// Tryby przekształcenia.
const int modeNone = 0;
const int modeTrapezoid = 1;
const int modeCylinder = 2;

/// Punkty: 0=LG, 1=PG, 2=PD, 3=LD, 4=środek górnej krawędzi, 5=środek dolnej.
Pt warpMap(int mode, List<Pt> pts, double u, double v) {
  if (mode == modeCylinder) {
    final th = (u - 0.5) * 2 * cylinderHalfAngle;
    final t = (1 + math.sin(th) / math.sin(cylinderHalfAngle)) / 2;
    final top = quadThrough(pts[0], pts[4], pts[1], t);
    final bot = quadThrough(pts[3], pts[5], pts[2], t);
    return top + (bot - top) * v;
  }
  return Homography(pts[0], pts[1], pts[2], pts[3]).map(u, v);
}

/// Rozmiar wyniku w pikselach (ograniczony, żeby nie zjadać pamięci).
({int w, int h}) warpSize(int mode, List<Pt> pts, int srcW, int srcH) {
  if (mode == modeNone) return (w: srcW, h: srcH);
  final h = ((pts[3] - pts[0]).length + (pts[2] - pts[1]).length) / 2;
  double w;
  if (mode == modeCylinder) {
    final chord = ((pts[1] - pts[0]).length + (pts[2] - pts[3]).length) / 2;
    final r = chord / (2 * math.sin(cylinderHalfAngle));
    w = 2 * cylinderHalfAngle * r;
  } else {
    w = ((pts[1] - pts[0]).length + (pts[2] - pts[3]).length) / 2;
  }
  var k = 1.0;
  final maxDim = math.max(w, h);
  if (maxDim > 3000) k = 3000 / maxDim;
  if (w * h * k * k > 3.0e6) k = math.min(k, math.sqrt(3.0e6 / (w * h)));
  return (w: math.max(16, (w * k).round()), h: math.max(16, (h * k).round()));
}

/// Dane dla funkcji uruchamianej w osobnym wątku (compute).
class WarpRequest {
  const WarpRequest({
    required this.bytes,
    required this.srcW,
    required this.srcH,
    required this.angle,
    required this.mode,
    required this.coords,
  });

  /// Piksele RGBA źródła.
  final Uint8List bytes;
  final int srcW;
  final int srcH;

  /// Obrót w radianach (zgodnie z ruchem wskazówek zegara).
  final double angle;
  final int mode;

  /// Współrzędne punktów: x0, y0, x1, y1, ... (6 punktów).
  final List<double> coords;
}

class WarpResult {
  const WarpResult(this.bytes, this.width, this.height);

  final Uint8List bytes;
  final int width;
  final int height;
}

/// Przekształca obraz: obrót, a potem trapez albo rozwinięcie walca.
WarpResult warpPixels(WarpRequest r) {
  final pts = [
    for (var i = 0; i + 1 < r.coords.length; i += 2)
      Pt(r.coords[i], r.coords[i + 1]),
  ];
  final size = warpSize(r.mode, pts, r.srcW, r.srcH);
  final out = Uint8List(size.w * size.h * 4);
  final cx = r.srcW / 2;
  final cy = r.srcH / 2;
  final cosA = math.cos(-r.angle);
  final sinA = math.sin(-r.angle);
  final hom = r.mode == modeTrapezoid
      ? Homography(pts[0], pts[1], pts[2], pts[3])
      : null;

  for (var j = 0; j < size.h; j++) {
    final v = (j + 0.5) / size.h;
    for (var i = 0; i < size.w; i++) {
      final u = (i + 0.5) / size.w;
      final Pt p;
      if (r.mode == modeNone) {
        p = Pt(u * r.srcW, v * r.srcH);
      } else if (hom != null) {
        p = hom.map(u, v);
      } else {
        p = warpMap(r.mode, pts, u, v);
      }
      // Odwrotny obrót: widok -> źródło.
      final dx = p.x - cx;
      final dy = p.y - cy;
      final sx = cx + dx * cosA - dy * sinA;
      final sy = cy + dx * sinA + dy * cosA;
      _sample(r.bytes, r.srcW, r.srcH, sx, sy, out, (j * size.w + i) * 4);
    }
  }
  return WarpResult(out, size.w, size.h);
}

void _sample(Uint8List src, int w, int h, double x, double y, Uint8List out,
    int o) {
  if (x < 0 || y < 0 || x > w - 1 || y > h - 1) {
    out[o] = 128;
    out[o + 1] = 128;
    out[o + 2] = 128;
    out[o + 3] = 255;
    return;
  }
  final x0 = x.floor();
  final y0 = y.floor();
  final x1 = math.min(x0 + 1, w - 1);
  final y1 = math.min(y0 + 1, h - 1);
  final fx = x - x0;
  final fy = y - y0;
  for (var c = 0; c < 3; c++) {
    final a = src[(y0 * w + x0) * 4 + c];
    final b = src[(y0 * w + x1) * 4 + c];
    final cc = src[(y1 * w + x0) * 4 + c];
    final d = src[(y1 * w + x1) * 4 + c];
    final top = a + (b - a) * fx;
    final bottom = cc + (d - cc) * fx;
    out[o + c] = (top + (bottom - top) * fy).round().clamp(0, 255);
  }
  out[o + 3] = 255;
}
