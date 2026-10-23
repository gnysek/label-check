import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../ingredient_parser.dart';

/// Ekran: zdjęcie etykiety -> OCR -> edytowalny tekst -> lista składników.
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
  List<Ingredient> _ingredients = const [];

  @override
  void dispose() {
    _recognizer.close();
    _controller.dispose();
    super.dispose();
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się odczytać zdjęcia: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _reparse() {
    setState(() => _ingredients = _parser.parse(_controller.text));
  }

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
          if (_busy) const Padding(
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
          const SizedBox(height: 16),
          Text(
            'Składniki (${_ingredients.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final i in _ingredients)
            Card(
              child: ListTile(
                title: Text(i.name),
                subtitle: i.percent == null ? null : Text('Udział: ${i.percent}'),
                trailing: i.eNumber == null
                    ? null
                    : Chip(label: Text(i.eNumber!)),
              ),
            ),
        ],
      ),
    );
  }
}
