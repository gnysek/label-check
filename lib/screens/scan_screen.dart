import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../additive_db.dart';
import '../checker.dart';
import '../ingredient_parser.dart';

/// Ekran: zdjęcie etykiety -> OCR -> edytowalny tekst -> składniki ze statusami.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _picker = ImagePicker();
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final _controller = TextEditingController();
  final _parser = const IngredientParser();

  File? _image;
  bool _busy = false;
  AdditiveDatabase? _db;
  List<IngredientCheck> _checks = const [];

  @override
  void initState() {
    super.initState();
    _loadDb();
  }

  @override
  void dispose() {
    _recognizer.close();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadDb() async {
    try {
      final db = await AdditiveDatabase.loadAsset();
      if (!mounted) return;
      _db = db;
      _reparse();
    } catch (e) {
      _showError('Nie udało się wczytać bazy dodatków: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _capture(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 90);
    if (picked == null) return;

    setState(() {
      _image = File(picked.path);
      _busy = true;
    });

    try {
      final input = InputImage.fromFilePath(picked.path);
      final result = await _recognizer.processImage(input);
      _controller.text = result.text;
      _reparse();
    } catch (e) {
      _showError('Nie udało się odczytać zdjęcia: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _reparse() {
    final ingredients = _parser.parse(_controller.text);
    final db = _db;
    setState(() {
      _checks = db == null
          ? [for (final i in ingredients) IngredientCheck(i, null)]
          : LabelChecker(db).check(ingredients);
    });
  }

  int _count(AdditiveStatus s) => _checks.where((c) => c.status == s).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LabelCheck')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _capture(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Zrób zdjęcie'),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _capture(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Z galerii'),
              ),
            ],
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: LinearProgressIndicator(),
            ),
          if (_image != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(_image!, height: 180, fit: BoxFit.cover),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            minLines: 4,
            maxLines: 10,
            onChanged: (_) => _reparse(),
            decoration: const InputDecoration(
              labelText: 'Rozpoznany tekst (popraw ręcznie)',
              border: OutlineInputBorder(),
            ),
          ),
          if (_db?.isSample == true) ...[
            const SizedBox(height: 16),
            const _SampleDataBanner(),
          ],
          const SizedBox(height: 16),
          if (_checks.isNotEmpty) _SummaryCard(
            banned: _count(AdditiveStatus.banned),
            restricted: _count(AdditiveStatus.restricted),
            notFound: _count(AdditiveStatus.notFound),
            allowed: _count(AdditiveStatus.allowed),
          ),
          const SizedBox(height: 8),
          Text(
            'Składniki (${_checks.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final c in _checks) _IngredientTile(check: c),
        ],
      ),
    );
  }
}

({Color color, IconData icon, String label}) _look(AdditiveStatus s) {
  switch (s) {
    case AdditiveStatus.allowed:
      return (
        color: Colors.green.shade700,
        icon: Icons.check_circle,
        label: 'Dozwolony',
      );
    case AdditiveStatus.restricted:
      return (
        color: Colors.orange.shade800,
        icon: Icons.warning_amber_rounded,
        label: 'Z ograniczeniami',
      );
    case AdditiveStatus.banned:
      return (
        color: Colors.red.shade700,
        icon: Icons.block,
        label: 'Niedozwolony',
      );
    case AdditiveStatus.notFound:
      return (
        color: Colors.blueGrey,
        icon: Icons.help_outline,
        label: 'Brak w bazie, zweryfikuj ręcznie',
      );
  }
}

class _SampleDataBanner extends StatelessWidget {
  const _SampleDataBanner();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.amber.shade100,
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.info_outline),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Baza zawiera tylko dane przykładowe. Wynik nie może być '
                'podstawą decyzji kontrolnej.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.banned,
    required this.restricted,
    required this.notFound,
    required this.allowed,
  });

  final int banned;
  final int restricted;
  final int notFound;
  final int allowed;

  @override
  Widget build(BuildContext context) {
    final AdditiveStatus worst;
    if (banned > 0) {
      worst = AdditiveStatus.banned;
    } else if (restricted > 0) {
      worst = AdditiveStatus.restricted;
    } else if (notFound > 0) {
      worst = AdditiveStatus.notFound;
    } else {
      worst = AdditiveStatus.allowed;
    }
    final look = _look(worst);
    return Card(
      color: look.color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(look.icon, color: look.color, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Niedozwolone: $banned · Z ograniczeniami: $restricted · '
                'Do weryfikacji: $notFound · Dozwolone: $allowed',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IngredientTile extends StatelessWidget {
  const _IngredientTile({required this.check});

  final IngredientCheck check;

  @override
  Widget build(BuildContext context) {
    final status = check.status;
    final look = status == null ? null : _look(status);
    final i = check.ingredient;
    final lines = <String>[
      if (i.percent != null) 'Udział: ${i.percent}',
      if (check.info != null) check.info!.name,
      if (look != null) look.label,
      if (check.info?.note != null) check.info!.note!,
      if (check.info != null) 'Podstawa: ${check.info!.source}',
    ];
    return Card(
      child: ListTile(
        leading: look == null ? null : Icon(look.icon, color: look.color),
        title: Text(i.name),
        subtitle: lines.isEmpty ? null : Text(lines.join('\n')),
        trailing: i.eNumber == null ? null : Chip(label: Text(i.eNumber!)),
      ),
    );
  }
}
