import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

/// Collapsible FX card with toggle switch
class FxToggleCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final List<Widget> children;

  const FxToggleCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onToggle,
    required this.children,
  });

  @override
  State<FxToggleCard> createState() => _FxToggleCardState();
}

class _FxToggleCardState extends State<FxToggleCard> {
  bool _expanded = false;

  @override
  void didUpdateWidget(FxToggleCard old) {
    super.didUpdateWidget(old);
    // Auto-expand when enabled
    if (widget.enabled && !old.enabled) {
      setState(() => _expanded = true);
    }
    // Auto-collapse when disabled
    if (!widget.enabled && old.enabled) {
      setState(() => _expanded = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.enabled
              ? widget.color.withOpacity(0.3)
              : AppTheme.cardLight,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        color: widget.enabled
                            ? widget.color
                            : AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  // Toggle switch
                  Switch(
                    value: widget.enabled,
                    onChanged: widget.onToggle,
                    thumbColor: WidgetStateProperty.resolveWith(
                      (s) => s.contains(WidgetState.selected)
                          ? widget.color
                          : AppTheme.textSecondary,
                    ),
                    trackColor: WidgetStateProperty.resolveWith(
                      (s) => s.contains(WidgetState.selected)
                          ? widget.color.withOpacity(0.35)
                          : AppTheme.cardLight,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  // Expand arrow
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: 200.ms,
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: AppTheme.textSecondary,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded content
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(children: widget.children),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: 250.ms,
          ),
        ],
      ),
    );
  }
}
