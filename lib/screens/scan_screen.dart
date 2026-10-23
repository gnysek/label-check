import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../additive_db.dart';
import '../scan_store.dart';
import '../theme.dart';
import 'additives_screen.dart';
import 'history_screen.dart';
import 'result_screen.dart';

/// Ekran startowy: zdjęcie etykiety -> OCR -> ekran wyniku.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _picker = ImagePicker();
  final _store = ScanStore();
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  late final Future<AdditiveDatabase> _dbFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _dbFuture = AdditiveDatabase.loadAsset();
  }

  @override
  void dispose() {
    _recognizer.close();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _scan(ImageSource source) async {
    String? text;
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 90);
      if (picked == null) return;
      if (mounted) setState(() => _busy = true);
      final input = InputImage.fromFilePath(picked.path);
      final result = await _recognizer.processImage(input);
      text = result.text;
    } catch (e) {
      _showError('Nie udało się odczytać zdjęcia: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (text == null) return;
    await _openResult(text);
  }

  Future<void> _openResult(String text) async {
    try {
      final db = await _dbFuture;
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ResultScreen(
            initialText: text,
            db: db,
            store: _store,
          ),
        ),
      );
    } catch (e) {
      _showError('Nie udało się wczytać bazy dodatków: $e');
    }
  }

  Future<void> _openHistory() async {
    try {
      final db = await _dbFuture;
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => HistoryScreen(store: _store, db: db),
        ),
      );
    } catch (e) {
      _showError('Nie udało się wczytać bazy dodatków: $e');
    }
  }

  Future<void> _openAdditives() async {
    try {
      final db = await _dbFuture;
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => AdditivesScreen(db: db)),
      );
    } catch (e) {
      _showError('Nie udało się wczytać bazy dodatków: $e');
    }
  }

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                'LabelCheck',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.history, color: AppColors.green),
              title: const Text('Historia skanów'),
              onTap: () {
                Navigator.of(context).pop();
                _openHistory();
              },
            ),
            ListTile(
              leading: const Icon(Icons.list_alt, color: AppColors.green),
              title: const Text('Baza dodatków'),
              onTap: () {
                Navigator.of(context).pop();
                _openAdditives();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Header(),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Zeskanuj listę składników',
                    style: TextStyle(
                      fontSize: 26,
                      height: 32 / 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Zrób zdjęcie etykiety. Rozpoznany tekst poprawisz '
                    'przed sprawdzeniem.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 22 / 15,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _Viewfinder(busy: _busy),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RoundAction(
                    icon: Icons.photo_library_outlined,
                    label: 'Galeria',
                    onTap: _busy ? null : () => _scan(ImageSource.gallery),
                  ),
                  _ShutterButton(
                    onTap: _busy ? null : () => _scan(ImageSource.camera),
                  ),
                  _RoundAction(
                    icon: Icons.keyboard_outlined,
                    label: 'Ręcznie',
                    onTap: _busy ? null : () => _openResult(''),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Menu',
            iconSize: 28,
            color: AppColors.green,
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu),
          ),
          const SizedBox(width: 4),
          const DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.green,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(Icons.manage_search, color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'LabelCheck',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _Viewfinder extends StatelessWidget {
  const _Viewfinder({required this.busy});

  final bool busy;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: ColoredBox(
        color: const Color(0xFF1E2A24),
        child: Stack(
          children: [
            const Positioned(left: 28, top: 28, child: _Corner(0)),
            const Positioned(right: 28, top: 28, child: _Corner(1)),
            const Positioned(right: 28, bottom: 28, child: _Corner(2)),
            const Positioned(left: 28, bottom: 28, child: _Corner(3)),
            Positioned.fill(
              child: Center(
                child: busy
                    ? const CircularProgressIndicator(color: Color(0xFF8FD3A8))
                    : const Opacity(
                        opacity: 0.35,
                        child: SizedBox(
                          width: 220,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _Bar(1),
                              _Bar(0.86),
                              _Bar(0.94),
                              _Bar(0.6),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 64,
              child: Text(
                busy ? 'Rozpoznaję tekst…' : 'Ustaw listę składników w ramce',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar(this.factor);

  final double factor;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: factor,
        child: Container(
          height: 10,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(5),
          ),
        ),
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  const _Corner(this.quarterTurns);

  final int quarterTurns;

  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: quarterTurns,
      child: const SizedBox(
        width: 36,
        height: 36,
        child: CustomPaint(painter: _CornerPainter()),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF8FD3A8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, 12)
      ..quadraticBezierTo(0, 0, 12, 0)
      ..lineTo(size.width, 0);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: AppColors.border),
    );
    return SizedBox(
      width: 84,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: label,
            child: Material(
              color: Colors.white,
              shape: shape,
              child: InkWell(
                customBorder: shape,
                onTap: onTap,
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: Icon(icon, size: 26, color: AppColors.green),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: 'Zrób zdjęcie',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Container(
                width: 84,
                height: 84,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: AppColors.green, width: 4),
                ),
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.green,
                  ),
                  child: const Icon(
                    Icons.photo_camera,
                    size: 30,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Zrób zdjęcie',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.green,
            ),
          ),
        ],
      ),
    );
  }
}
