import 'package:flutter/material.dart';

import 'additive_db.dart';

/// Wygląd statusu: kolor tekstu/ikony, tło, ramka, ikona i etykieta.
class StatusStyle {
  const StatusStyle({
    required this.fg,
    required this.bg,
    required this.border,
    required this.icon,
    required this.label,
  });

  final Color fg;
  final Color bg;
  final Color border;
  final IconData icon;
  final String label;
}

StatusStyle styleFor(AdditiveStatus status) {
  switch (status) {
    case AdditiveStatus.banned:
      return const StatusStyle(
        fg: Color(0xFFB3261E),
        bg: Color(0xFFFDECEA),
        border: Color(0xFFF1B8B3),
        icon: Icons.block,
        label: 'Niedozwolony',
      );
    case AdditiveStatus.restricted:
      return const StatusStyle(
        fg: Color(0xFF9A4A00),
        bg: Color(0xFFFFF3E0),
        border: Color(0xFFF2C98F),
        icon: Icons.warning_amber_rounded,
        label: 'Z ograniczeniami',
      );
    case AdditiveStatus.allowed:
      return const StatusStyle(
        fg: Color(0xFF1B6B2F),
        bg: Color(0xFFE8F5E9),
        border: Color(0xFFA9D5B2),
        icon: Icons.check_circle_outline,
        label: 'Dozwolony',
      );
    case AdditiveStatus.notFound:
      return const StatusStyle(
        fg: Color(0xFF475569),
        bg: Color(0xFFEEF1F4),
        border: Color(0xFFC7CED6),
        icon: Icons.help_outline,
        label: 'Brak w bazie, zweryfikuj ręcznie',
      );
  }
}
