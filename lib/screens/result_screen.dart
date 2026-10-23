import 'dart:async';

import 'package:flutter/material.dart';

import '../additive_db.dart';
import '../checker.dart';
import '../ingredient_parser.dart';
import '../scan_store.dart';
import '../status_style.dart';
import '../theme.dart';
import '../widgets.dart';
import 'history_screen.dart';

/// Ekran wyniku: werdykt, liczniki, edytowalny tekst z OCR i lista składników.
class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.initialText,
    required this.db,
    required this.store,
    this.scanId,
  });

  final String initialText;
  final AdditiveDatabase db;
  final ScanStore store;

  /// Id zapisanego skanu (null = nowy skan, zostanie zapisany automatycznie).
  final String? scanId;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final _parser = const IngredientParser();
  late final TextEditingController _controller;
  List<IngredientCheck> _checks = const [];
  String? _scanId;
  Timer? _saveTimer;
  Future<void> _saving = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _scanId = widget.scanId;
    _controller = TextEditingController(text: widget.initialText);
    _checks = _compute();
    if (_scanId == null && widget.initialText.trim().isNotEmpty) {
      _persist(widget.initialText);
    }
  }

  @override
  void dispose() {
    final pending = _saveTimer?.isActive ?? false;
    _saveTimer?.cancel();
    if (pending) _persist(_controller.text);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String _) {
    setState(() => _checks = _compute());
    _saveTimer?.cancel();
    final text = _controller.text;
    _saveTimer = Timer(const Duration(milliseconds: 500), () => _persist(text));
  }

  /// Zapisy idą po kolei, żeby szybkie zmiany nie utworzyły dwóch wpisów.
  void _persist(String text) {
    _saving =
        _saving.then((_) => _save(text)).catchError((Object _) {});
  }

  Future<void> _save(String text) async {
    final id = _scanId;
    if (id != null) {
      await widget.store.updateText(id, text);
    } else if (text.trim().isNotEmpty) {
      final created = await widget.store.create(text);
      _scanId = created.id;
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usunąć skan z pamięci?'),
        content: const Text('Tej operacji nie można cofnąć.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Anuluj'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _saveTimer?.cancel();
    await _saving;
    final id = _scanId;
    if (id != null) await widget.store.delete(id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _openHistory() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => HistoryScreen(store: widget.store, db: widget.db),
      ),
    );
  }

  List<IngredientCheck> _compute() =>
      LabelChecker(widget.db).check(_parser.parse(_controller.text));

  int _count(AdditiveStatus s) => _checks
      .where((c) => c.status == s ||
          (s == AdditiveStatus.notFound && c.status == AdditiveStatus.unverified))
      .length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wynik kontroli'),
        actions: [
          IconButton(
            tooltip: 'Usuń z pamięci',
            icon: const Icon(Icons.delete_outline),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        children: [
          _VerdictBanner(verdict: _verdict(_checks)),
          const SizedBox(height: 16),
          _Counters(
            banned: _count(AdditiveStatus.banned),
            restricted: _count(AdditiveStatus.restricted),
            notFound: _count(AdditiveStatus.notFound),
            allowed: _count(AdditiveStatus.allowed),
          ),
          if (widget.db.isSample) ...[
            const SizedBox(height: 12),
            const SampleBanner(),
          ],
          const SizedBox(height: 12),
          _OcrTextCard(
            controller: _controller,
            startExpanded: widget.initialText.isEmpty,
            onChanged: _onTextChanged,
          ),
          const SizedBox(height: 16),
          Text(
            'Składniki (${_checks.length})',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final c in _checks)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _IngredientCard(check: c),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    foregroundColor: AppColors.green,
                    side: const BorderSide(color: AppColors.green, width: 2),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                    ),
                  ),
                  child: const Text(
                    'Nowe zdjęcie',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 7,
                child: FilledButton(
                  onPressed: _openHistory,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                    ),
                  ),
                  child: const Text(
                    'Historia skanów',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Verdict {
  const _Verdict({
    required this.color,
    required this.icon,
    required this.kicker,
    required this.headline,
    this.detail,
  });

  final Color color;
  final IconData icon;
  final String kicker;
  final String headline;
  final String? detail;
}

_Verdict _verdict(List<IngredientCheck> checks) {
  List<IngredientCheck> byStatus(AdditiveStatus s) => checks
      .where((c) => c.status == s ||
          (s == AdditiveStatus.notFound && c.status == AdditiveStatus.unverified))
      .toList();
  String names(List<IngredientCheck> list) =>
      list.map((c) => c.ingredient.eNumber ?? c.ingredient.name).join(', ');

  final banned = byStatus(AdditiveStatus.banned);
  final restricted = byStatus(AdditiveStatus.restricted);
  final notFound = byStatus(AdditiveStatus.notFound);
  final hasAdditives = checks.any((c) => c.status != null);

  if (checks.isEmpty) {
    return const _Verdict(
      color: Color(0xFF475569),
      icon: Icons.help_outline,
      kicker: 'Brak danych',
      headline: 'Brak składników do sprawdzenia',
    );
  }
  if (banned.isNotEmpty) {
    return _Verdict(
      color: const Color(0xFFB3261E),
      icon: Icons.block,
      kicker: 'Naruszenie',
      headline: banned.length == 1
          ? 'Wykryto niedozwolony dodatek'
          : 'Wykryto niedozwolone dodatki',
      detail: names(banned),
    );
  }
  if (restricted.isNotEmpty) {
    return _Verdict(
      color: const Color(0xFF9A4A00),
      icon: Icons.warning_amber_rounded,
      kicker: 'Uwaga',
      headline: 'Dodatki z ograniczeniami',
      detail: names(restricted),
    );
  }
  if (notFound.isNotEmpty) {
    return _Verdict(
      color: const Color(0xFF475569),
      icon: Icons.help_outline,
      kicker: 'Do weryfikacji',
      headline: 'Nie wszystko udało się sprawdzić',
      detail: names(notFound),
    );
  }
  if (!hasAdditives) {
    return const _Verdict(
      color: Color(0xFF475569),
      icon: Icons.info_outline,
      kicker: 'Informacja',
      headline: 'Nie znaleziono numerów E',
    );
  }
  return const _Verdict(
    color: Color(0xFF1B6B2F),
    icon: Icons.check_circle_outline,
    kicker: 'Bez uwag',
    headline: 'Nie wykryto niedozwolonych dodatków',
  );
}

class _VerdictBanner extends StatelessWidget {
  const _VerdictBanner({required this.verdict});

  final _Verdict verdict;

  @override
  Widget build(BuildContext context) {
    final detail = verdict.detail;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: verdict.color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(verdict.icon, size: 44, color: Colors.white),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  verdict.kicker.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  verdict.headline,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    height: 26 / 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Counters extends StatelessWidget {
  const _Counters({
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
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _CounterTile(
                status: AdditiveStatus.banned,
                count: banned,
                label: 'Niedozwolone',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CounterTile(
                status: AdditiveStatus.restricted,
                count: restricted,
                label: 'Z ograniczeniami',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _CounterTile(
                status: AdditiveStatus.notFound,
                count: notFound,
                label: 'Do weryfikacji',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CounterTile(
                status: AdditiveStatus.allowed,
                count: allowed,
                label: 'Dozwolone',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CounterTile extends StatelessWidget {
  const _CounterTile({
    required this.status,
    required this.count,
    required this.label,
  });

  final AdditiveStatus status;
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    final s = styleFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: s.bg,
        border: Border.all(color: s.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(s.icon, color: s.fg),
          const SizedBox(width: 10),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 26,
              height: 1,
              fontWeight: FontWeight.w700,
              color: s.fg,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                height: 16 / 13,
                fontWeight: FontWeight.w600,
                color: s.fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OcrTextCard extends StatelessWidget {
  const _OcrTextCard({
    required this.controller,
    required this.startExpanded,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool startExpanded;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: startExpanded,
          leading: const Icon(Icons.edit_note, color: AppColors.green),
          title: const Text(
            'Rozpoznany tekst (popraw ręcznie)',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            TextField(
              controller: controller,
              minLines: 3,
              maxLines: 8,
              onChanged: onChanged,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Wpisz lub wklej listę składników',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodeChip extends StatelessWidget {
  const _CodeChip({required this.code, this.style});

  final String code;
  final StatusStyle? style;

  @override
  Widget build(BuildContext context) {
    final s = style;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: s?.bg ?? const Color(0xFFEEF1F4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        code,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: s?.fg ?? AppColors.muted,
        ),
      ),
    );
  }
}

class _IngredientCard extends StatelessWidget {
  const _IngredientCard({required this.check});

  final IngredientCheck check;

  @override
  Widget build(BuildContext context) {
    final i = check.ingredient;
    final status = check.status;
    final s = status == null ? null : styleFor(status);
    final info = check.info;
    final note = info?.note;
    final emphasised = status == AdditiveStatus.banned;
    final code = i.eNumber ?? info?.code;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: emphasised && s != null ? s.border : AppColors.border,
          width: emphasised ? 2 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (s != null) ...[
            Icon(s.icon, color: s.fg),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        i.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (code != null) ...[
                      const SizedBox(width: 8),
                      _CodeChip(code: code, style: s),
                    ],
                  ],
                ),
                if (s != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      info == null ? s.label : '${s.label} · ${info.name}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: s.fg,
                      ),
                    ),
                  ),
                if (i.percent != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Udział: ${i.percent}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                if (note != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      note,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 20 / 14,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                if (info != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Podstawa: ${info.source}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
