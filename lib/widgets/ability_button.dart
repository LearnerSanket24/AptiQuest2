import 'package:flutter/material.dart';

class AbilityButton extends StatelessWidget {
  final String label;
  final String emoji;
  final bool enabled;
  final VoidCallback onTap;

  const AbilityButton({
    super.key,
    required this.label,
    required this.emoji,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A4A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF5A5A8A)),
          ),
          child: Text(
            '$emoji $label',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
