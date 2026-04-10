// lib/widgets/status_stepper.dart
import 'package:flutter/material.dart';

class StatusStepper extends StatelessWidget {
  final String status;
  const StatusStepper(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final steps = ['queued', 'processing', 'done'];
    final isFailed = status == 'failed';
    final currentIndex = isFailed ? 2 : steps.indexOf(status);

    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          // Connector line
          final stepIndex = (i + 1) ~/ 2;
          final active = stepIndex <= currentIndex;
          return Expanded(
            child: Container(
              height: 2,
              color: active ? cs.primary : cs.surfaceContainerHighest,
            ),
          );
        }
        final stepIndex = i ~/ 2;
        final done = stepIndex < currentIndex;
        final active = stepIndex == currentIndex;
        final label = steps[stepIndex];

        Color color;
        Widget icon;
        if (isFailed && stepIndex == 2) {
          color = Colors.red;
          icon = const Icon(Icons.close, size: 14, color: Colors.red);
        } else if (done) {
          color = cs.primary;
          icon = Icon(Icons.check, size: 14, color: cs.onPrimary);
        } else if (active) {
          color = cs.primary;
          icon = SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: cs.onPrimary,
            ),
          );
        } else {
          color = cs.surfaceContainerHighest;
          icon = const SizedBox.shrink();
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Center(child: icon),
            ),
            const SizedBox(height: 4),
            Text(
              label[0].toUpperCase() + label.substring(1),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: (done || active) ? cs.primary : cs.onSurfaceVariant,
                  ),
            ),
          ],
        );
      }),
    );
  }
}
