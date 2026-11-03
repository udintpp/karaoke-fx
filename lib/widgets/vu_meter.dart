import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Animated VU Meter bar
class VuMeter extends StatelessWidget {
  final double level; // 0.0 - 1.0
  final Color color;
  final String label;

  const VuMeter({
    super.key,
    required this.level,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
            Text(
              '${(level * 100).toInt()}%',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _VuMeterBar(level: level, color: color),
      ],
    );
  }
}

class _VuMeterBar extends StatelessWidget {
  final double level;
  final Color color;

  const _VuMeterBar({required this.level, required this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final total = 24; // number of segments
        final active = (level * total).round();

        return Row(
          children: List.generate(total, (i) {
            final isActive = i < active;
            // Color gradient: green -> yellow -> red
            Color segColor;
            if (i < total * 0.6) {
              segColor = color; // Normal range
            } else if (i < total * 0.8) {
              segColor = AppTheme.warning; // Warning
            } else {
              segColor = AppTheme.error; // Clip zone
            }

            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 60),
                height: 16,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: isActive
                      ? segColor
                      : segColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: isActive && i >= total * 0.8
                      ? [BoxShadow(color: segColor.withOpacity(0.6), blurRadius: 4)]
                      : null,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
