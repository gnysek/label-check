import 'package:flutter/material.dart';

import '../additive_db.dart';
import '../status_style.dart';
import '../theme.dart';
import '../widgets.dart';

/// Przeglądarka bazy dodatków: wyszukiwanie i filtr po statusie.
class AdditivesScreen extends StatefulWidget {
  const AdditivesScreen({super.key, required this.db});

  final AdditiveDatabase db;

  @override
  State<AdditivesScreen> createState() => _AdditivesScreenState();
}

class _AdditivesScreenState extends State<AdditivesScreen> {
  String _query = '';
  AdditiveStatus? _filter;

  List<AdditiveInfo> get _items {
    final q = _query.trim().toLowerCase().replaceAll(' ', '');
    return widget.db.items.where((i) {
      if (_filter != null && i.status != _filter) return false;
      if (q.isEmpty) return true;
      return i.code.toLowerCase().contains(q) ||
          i.name.toLowerCase().replaceAll(' ', '').contains(q);
    }).toList();
  }

  void _showDetails(AdditiveInfo info) {
    final s = styleFor(info.status);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${info.code} · ${info.name}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(s.icon, color: s.fg),
                const SizedBox(width: 8),
                Text(
                  s.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: s.fg,
                  ),
                ),
              ],
            ),
            if (info.note != null) ...[
              const SizedBox(height: 12),
              Text(
                info.note!,
                style: const TextStyle(fontSize: 15, height: 22 / 15),
              ),
            ],
            if (info.plNote != null) ...[
              const SizedBox(height: 12),
              Text(
                'W Polsce: ${info.plNote!}',
                style: const TextStyle(fontSize: 14, color: AppColors.muted),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Podstawa: ${info.source}',
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: Text('Baza dodatków (${widget.db.length})')),
      body: Column(
        children: [
          if (widget.db.isSample)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: SampleBanner(),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Szukaj po numerze E lub nazwie',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Row(
              children: [
                _chip('Wszystkie', null),
                _chip('Niedozwolone', AdditiveStatus.banned),
                _chip('Z ograniczeniami', AdditiveStatus.restricted),
                _chip('Dozwolone', AdditiveStatus.allowed),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Text(
                      'Nic nie znaleziono.',
                      style: TextStyle(fontSize: 16, color: AppColors.muted),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    itemCount: items.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) => _tile(items[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, AdditiveStatus? status) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _filter == status,
        onSelected: (_) => setState(() => _filter = status),
      ),
    );
  }

  Widget _tile(AdditiveInfo info) {
    final s = styleFor(info.status);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppColors.border),
    );
    return Material(
      color: Colors.white,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: () => _showDetails(info),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(s.icon, color: s.fg),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: s.fg,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: s.bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  info.code,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: s.fg,
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
