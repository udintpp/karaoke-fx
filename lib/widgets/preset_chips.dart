import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Scrollable preset chip selector
class PresetChips extends StatefulWidget {
  final List<String> presets;
  final Color color;
  final ValueChanged<int> onSelect;

  const PresetChips({
    super.key,
    required this.presets,
    required this.color,
    required this.onSelect,
  });

  @override
  State<PresetChips> createState() => _PresetChipsState();
}

class _PresetChipsState extends State<PresetChips> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PRESETS',
          style: TextStyle(
            color: widget.color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: widget.presets.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final isSelected = i == _selected;
              return GestureDetector(
                onTap: () {
                  setState(() => _selected = i);
                  widget.onSelect(i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [
                              widget.color,
                              widget.color.withOpacity(0.7)
                            ],
                          )
                        : null,
                    color: isSelected ? null : AppTheme.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? widget.color
                          : AppTheme.cardLight,
                    ),
                  ),
                  child: Text(
                    widget.presets[i],
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
