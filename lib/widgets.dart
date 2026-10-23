import 'package:flutter/material.dart';

/// Ostrzeżenie, że baza dodatków zawiera tylko dane przykładowe.
class SampleBanner extends StatelessWidget {
  const SampleBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        border: Border.all(color: const Color(0xFFF0D58A)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 22, color: Color(0xFF5C4400)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Dane przykładowe. Wynik nie może być podstawą decyzji '
              'kontrolnej.',
              style: TextStyle(
                fontSize: 14,
                height: 20 / 14,
                color: Color(0xFF5C4400),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
