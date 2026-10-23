import 'package:flutter/material.dart';

import 'screens/scan_screen.dart';

void main() => runApp(const LabelCheckApp());

class LabelCheckApp extends StatelessWidget {
  const LabelCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LabelCheck',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E7D32),
        useMaterial3: true,
      ),
      home: const ScanScreen(),
    );
  }
}
