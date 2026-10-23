import 'package:flutter/material.dart';

import 'screens/scan_screen.dart';
import 'theme.dart';

void main() => runApp(const LabelCheckApp());

class LabelCheckApp extends StatelessWidget {
  const LabelCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LabelCheck',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const ScanScreen(),
    );
  }
}
