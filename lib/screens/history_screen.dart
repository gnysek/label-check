import 'package:flutter/material.dart';

import '../additive_db.dart';
import '../checker.dart';
import '../ingredient_parser.dart';
import '../scan_store.dart';
import '../status_style.dart';
import '../theme.dart';
import 'result_screen.dart';

/// Historia skanów: otwórz, popraw lub usuń zapisany skan.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.store, required this.db});

  final ScanStore store;
  final AdditiveDatabase db;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _parser = const IngredientParser();
  List<SavedScan>? _scans;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final scans = await widget.store.load();
    if (!mounted) return;
    setState(() => _scans = scans);
  }

  Future<void> _open(SavedScan scan) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ResultScreen(
          initialText: scan.text,
          db: widget.db,
          store: widget.store,
          scanId: scan.id,
        ),
      ),
    );
    await _reload();
  }

  Future<void> _delete(SavedScan scan) async {
    setState(() => _scans = _scans?.where((s) => s.id != scan.id).toList());
    await widget.store.delete(scan.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Usunięto skan'),
        action: SnackBarAction(
          label: 'Cofnij',
          onPressed: () async {
            await widget.store.restore(scan);
            await _reload();
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final scans = _scans;
    final Widget body;
    if (scans == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (scans.isEmpty) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Brak zapisanych skanów.\n'
            'Po zrobieniu zdjęcia etykiety skan pojawi się tutaj.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: AppColors.muted),
          ),
        ),
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        itemCount: scans.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _tile(scans[index]),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Historia skanów')),
      body: body,
    );
  }

  Widget _tile(SavedScan scan) {
    final parsed = _parser.parse(scan.text);
    final worst = worstStatus(LabelChecker(widget.db).check(parsed));
    final title = parsed.isEmpty
        ? 'Pusty skan'
        : parsed.take(4).map((i) => i.name).join(', ');
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppColors.border),
    );
    return Dismissible(
      key: ValueKey(scan.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _delete(scan),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFB3261E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Material(
        color: Colors.white,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: () => _open(scan),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatDate(scan.createdAt)} · '
                        'składników: ${parsed.length}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _VerdictChip(status: worst),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VerdictChip extends StatelessWidget {
  const _VerdictChip({required this.status});

  final AdditiveStatus? status;

  @override
  Widget build(BuildContext context) {
    final s = status;
    final style = s == null ? null : styleFor(s);
    final label = switch (s) {
      AdditiveStatus.banned => 'Naruszenie',
      AdditiveStatus.restricted => 'Uwaga',
      AdditiveStatus.notFound => 'Do weryfikacji',
      AdditiveStatus.allowed => 'Bez uwag',
      null => 'Brak E',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: style?.bg ?? const Color(0xFFEEF1F4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: style?.fg ?? AppColors.muted,
        ),
      ),
    );
  }
}
