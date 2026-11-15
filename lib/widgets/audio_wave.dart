import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Lightweight animated equaliser bars. A single AnimationController drives a
/// CustomPainter; it stops completely when not [active] to save CPU on TV boxes.
class AudioWave extends StatefulWidget {
  const AudioWave({super.key, required this.active, this.bars = 24, this.height = 48, this.color});
  final bool active;
  final int bars;
  final double height;
  final Color? color;

  @override
  State<AudioWave> createState() => _AudioWaveState();
}

class _AudioWaveState extends State<AudioWave> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant AudioWave old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) _c.repeat();
    if (!widget.active && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.secondary;
    return RepaintBoundary(
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: CustomPaint(painter: _WavePainter(_c, widget.bars, color, widget.active)),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.anim, this.bars, this.color, this.active) : super(repaint: anim);
  final Animation<double> anim;
  final int bars;
  final Color color;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round;
    final gap = size.width / bars;
    paint.strokeWidth = math.max(2, gap * 0.45);
    final t = anim.value * 2 * math.pi;
    for (var i = 0; i < bars; i++) {
      final phase = i * 0.55;
      final amp = active
          ? 0.25 + 0.75 * (0.5 + 0.5 * math.sin(t * 2 + phase) * math.cos(t + phase * 0.7)).abs()
          : 0.12;
      final h = size.height * amp;
      final x = gap * (i + 0.5);
      canvas.drawLine(Offset(x, (size.height - h) / 2), Offset(x, (size.height + h) / 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => old.active != active || old.color != color;
}
