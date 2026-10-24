import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../image_warp.dart';
import '../theme.dart';

/// Podgląd zdjęcia przed odczytem: suwak prostowania, trapez i rozwinięcie
/// puszki (walca). Zwraca ścieżkę do pliku, z którego ma pójść OCR.
class StraightenScreen extends StatefulWidget {
  const StraightenScreen({super.key, required this.imagePath});

  final String imagePath;

  @override
  State<StraightenScreen> createState() => _StraightenScreenState();
}

class _StraightenScreenState extends State<StraightenScreen> {
  ui.Image? _img;
  double _angleDeg = 0;
  int _mode = modeNone;
  List<Pt> _pts = const [];
  int? _drag;
  bool _busy = false;
  String? _error;

  // Układ obrazu w widżecie (zapamiętany w build, używany przy dotyku).
  double _scale = 1;
  Offset _offset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 2400);
      final frame = await codec.getNextFrame();
      final img = frame.image;
      if (!mounted) return;
      final w = img.width.toDouble();
      final h = img.height.toDouble();
      setState(() {
        _img = img;
        _pts = [
          Pt(w * 0.15, h * 0.25),
          Pt(w * 0.85, h * 0.25),
          Pt(w * 0.85, h * 0.65),
          Pt(w * 0.15, h * 0.65),
          Pt(w * 0.5, h * 0.25),
          Pt(w * 0.5, h * 0.65),
        ];
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Nie udało się wczytać zdjęcia: $e');
    }
  }

  int get _activeHandles => _mode == modeCylinder ? 6 : (_mode == modeTrapezoid ? 4 : 0);

  Offset _toScreen(Pt p) => _offset + Offset(p.x * _scale, p.y * _scale);

  void _onPanStart(DragStartDetails d) {
    var best = -1;
    var bestDist = 44.0;
    for (var i = 0; i < _activeHandles; i++) {
      final dist = (_toScreen(_pts[i]) - d.localPosition).distance;
      if (dist < bestDist) {
        bestDist = dist;
        best = i;
      }
    }
    _drag = best >= 0 ? best : null;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final i = _drag;
    final img = _img;
    if (i == null || img == null) return;
    final x = ((d.localPosition.dx - _offset.dx) / _scale)
        .clamp(0.0, img.width.toDouble());
    final y = ((d.localPosition.dy - _offset.dy) / _scale)
        .clamp(0.0, img.height.toDouble());
    setState(() {
      final next = List<Pt>.of(_pts);
      // Wygięcie góry i dołu (odległość środkowej kropki od cięciwy) zostaje
      // zachowane, gdy ktoś rusza rogiem - kropki podążają za rogami.
      Pt chordMid(Pt a, Pt b) => Pt((a.x + b.x) / 2, (a.y + b.y) / 2);
      final topBulge = _pts[4] - chordMid(_pts[0], _pts[1]);
      final botBulge = _pts[5] - chordMid(_pts[3], _pts[2]);
      next[i] = Pt(x, y);
      if (i < 4 && _mode == modeCylinder) {
        final w = _img?.width.toDouble() ?? x;
        final h = _img?.height.toDouble() ?? y;
        Pt clampPt(Pt p) => Pt(p.x.clamp(0.0, w), p.y.clamp(0.0, h));
        next[4] = clampPt(chordMid(next[0], next[1]) + topBulge);
        next[5] = clampPt(chordMid(next[3], next[2]) + botBulge);
      }
      _pts = next;
    });
  }

  void _setMode(int mode) {
    final img = _img;
    if (img == null) return;
    setState(() {
      _mode = mode;
      if (mode == modeCylinder) {
        _pts = [
          for (var i = 0; i < 4; i++) _pts[i],
          Pt((_pts[0].x + _pts[1].x) / 2, (_pts[0].y + _pts[1].y) / 2),
          Pt((_pts[3].x + _pts[2].x) / 2, (_pts[3].y + _pts[2].y) / 2),
        ];
      }
    });
  }

  Future<void> _apply() async {
    final img = _img;
    if (img == null) return;
    if (_mode == modeNone && _angleDeg == 0) {
      Navigator.of(context).pop(widget.imagePath);
      return;
    }
    setState(() => _busy = true);
    try {
      final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) throw StateError('brak danych obrazu');
      final req = WarpRequest(
        bytes: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        srcW: img.width,
        srcH: img.height,
        angle: _angleDeg * math.pi / 180,
        mode: _mode,
        coords: [for (final p in _pts) ...[p.x, p.y]],
      );
      final out = await compute(warpPixels, req);
      final png = await _encodePng(out);
      final file = File(
          '${Directory.systemTemp.path}/labelcheck_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(png);
      if (!mounted) return;
      Navigator.of(context).pop(file.path);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Nie udało się przekształcić zdjęcia: $e';
      });
    }
  }

  Future<Uint8List> _encodePng(WarpResult r) async {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      r.bytes,
      r.width,
      r.height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final image = await completer.future;
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  @override
  void dispose() {
    _img?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final img = _img;
    return Scaffold(
      appBar: AppBar(title: const Text('Wyprostuj zdjęcie')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: img == null
                  ? Center(
                      child: _error != null
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(_error!),
                            )
                          : const CircularProgressIndicator(),
                    )
                  : LayoutBuilder(
                      builder: (context, box) {
                        final w = img.width.toDouble();
                        final h = img.height.toDouble();
                        _scale = math.min(box.maxWidth / w, box.maxHeight / h);
                        _offset = Offset((box.maxWidth - w * _scale) / 2,
                            (box.maxHeight - h * _scale) / 2);
                        return GestureDetector(
                          onPanStart: _onPanStart,
                          onPanUpdate: _onPanUpdate,
                          child: CustomPaint(
                            size: Size(box.maxWidth, box.maxHeight),
                            painter: _EditorPainter(
                              image: img,
                              angle: _angleDeg * math.pi / 180,
                              mode: _mode,
                              pts: _pts,
                              scale: _scale,
                              offset: _offset,
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (_error != null && img != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  const Icon(Icons.rotate_right, color: AppColors.muted),
                  Expanded(
                    child: Slider(
                      value: _angleDeg,
                      min: -15,
                      max: 15,
                      divisions: 60,
                      label: '${_angleDeg.toStringAsFixed(1)}°',
                      onChanged:
                          img == null ? null : (v) => setState(() => _angleDeg = v),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text('${_angleDeg.toStringAsFixed(1)}°',
                        textAlign: TextAlign.end),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: modeNone, label: Text('Bez zmian')),
                  ButtonSegment(value: modeTrapezoid, label: Text('Trapez')),
                  ButtonSegment(value: modeCylinder, label: Text('Puszka')),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => _setMode(s.first),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(
                switch (_mode) {
                  modeTrapezoid =>
                    'Przeciągnij rogi na narożniki listy składników.',
                  modeCylinder =>
                    'Rogi ustaw na krawędziach puszki, a środkowe kropki tak, '
                        'by linie pasowały do zakrzywionej góry i dołu etykiety.',
                  _ => 'Suwakiem wyprostuj zdjęcie, potem odczytaj tekst.',
                },
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (img == null || _busy) ? null : _apply,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Odczytaj tekst'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorPainter extends CustomPainter {
  _EditorPainter({
    required this.image,
    required this.angle,
    required this.mode,
    required this.pts,
    required this.scale,
    required this.offset,
  });

  final ui.Image image;
  final double angle;
  final int mode;
  final List<Pt> pts;
  final double scale;
  final Offset offset;

  Offset _s(Pt p) => offset + Offset(p.x * scale, p.y * scale);

  @override
  void paint(Canvas canvas, Size size) {
    final w = image.width.toDouble();
    final h = image.height.toDouble();
    canvas.save();
    canvas.clipRect(
        Rect.fromLTWH(offset.dx, offset.dy, w * scale, h * scale));
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);
    canvas.translate(w / 2, h / 2);
    canvas.rotate(angle);
    canvas.translate(-w / 2, -h / 2);
    canvas.drawImage(image, Offset.zero, Paint()..filterQuality = FilterQuality.medium);
    canvas.restore();

    if (mode == modeNone || pts.length < 4) return;

    final line = Paint()
      ..color = AppColors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final path = Path();
    final tl = _s(pts[0]);
    final tr = _s(pts[1]);
    final br = _s(pts[2]);
    final bl = _s(pts[3]);
    path.moveTo(tl.dx, tl.dy);
    if (mode == modeCylinder && pts.length >= 6) {
      final c1 = _s(controlPoint(pts[0], pts[4], pts[1]));
      path.quadraticBezierTo(c1.dx, c1.dy, tr.dx, tr.dy);
      path.lineTo(br.dx, br.dy);
      final c2 = _s(controlPoint(pts[3], pts[5], pts[2]));
      path.quadraticBezierTo(c2.dx, c2.dy, bl.dx, bl.dy);
      path.close();
    } else {
      path.lineTo(tr.dx, tr.dy);
      path.lineTo(br.dx, br.dy);
      path.lineTo(bl.dx, bl.dy);
      path.close();
    }
    // Przyciemnij wszystko poza zaznaczonym obszarem.
    final outer = Path()
      ..addRect(Rect.fromLTWH(offset.dx, offset.dy, w * scale, h * scale));
    canvas.drawPath(
      Path.combine(PathOperation.difference, outer, path),
      Paint()..color = const Color(0x99000000),
    );
    canvas.drawPath(path, line);

    final active = mode == modeCylinder ? 6 : 4;
    final fill = Paint()..color = Colors.white;
    for (var i = 0; i < active && i < pts.length; i++) {
      final c = _s(pts[i]);
      canvas.drawCircle(c, 13, fill);
      canvas.drawCircle(c, 13, line);
    }
  }

  @override
  bool shouldRepaint(covariant _EditorPainter old) => true;
}
