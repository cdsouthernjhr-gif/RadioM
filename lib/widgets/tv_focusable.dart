import 'package:flutter/material.dart';

/// Wraps a tappable child with a large, high-contrast focus ring for D-pad
/// navigation (Android TV), plus a subtle scale-up when focused.
class TvFocusable extends StatefulWidget {
  const TvFocusable({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.borderRadius = 16,
    this.autofocus = false,
    this.focusNode,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double borderRadius;
  final bool autofocus;
  final FocusNode? focusNode;
  final String? semanticLabel;

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(widget.borderRadius);
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: AnimatedScale(
        scale: _focused ? 1.04 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: _focused ? scheme.secondary : Colors.transparent, width: 3),
            boxShadow: _focused
                ? [BoxShadow(color: scheme.secondary.withOpacity(0.45), blurRadius: 14, spreadRadius: 1)]
                : const [],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              focusNode: widget.focusNode,
              autofocus: widget.autofocus,
              borderRadius: radius,
              onTap: widget.onTap,
              onLongPress: widget.onLongPress,
              onFocusChange: (f) => setState(() => _focused = f),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
