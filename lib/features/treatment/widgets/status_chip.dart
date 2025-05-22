// lib/features/treatment/widgets/status_chip.dart
import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final double? fontSize;

  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: fontSize ?? 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
