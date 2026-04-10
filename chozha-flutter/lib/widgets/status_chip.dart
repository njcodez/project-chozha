// lib/widgets/status_chip.dart
import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'done'       => ('Done', Colors.green),
      'failed'     => ('Failed', Colors.red),
      'processing' => ('Processing', Colors.orange),
      _            => ('Queued', Colors.blueGrey),
    };
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      backgroundColor: color.withOpacity(0.2),
      side: BorderSide(color: color.withOpacity(0.6)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
      labelStyle: TextStyle(color: color),
    );
  }
}
