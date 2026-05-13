import 'package:flutter/material.dart';

class HpBar extends StatelessWidget {
  final String label;
  final double percent;
  final Color barColor;

  const HpBar({
    super.key,
    required this.label,
    required this.percent,
    this.barColor = Colors.red,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percent.clamp(0.0, 1.0),
            minHeight: 14,
            backgroundColor: Colors.grey[800],
            valueColor: AlwaysStoppedAnimation<Color>(
              percent > 0.5 ? barColor : Colors.red[900]!,
            ),
          ),
        ),
      ],
    );
  }
}