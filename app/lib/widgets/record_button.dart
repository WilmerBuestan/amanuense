// Botón grande de grabar: respira en reposo, ondas de pulso mientras graba
// y el ícono cambia de micrófono a detener con una animación.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RecordButton extends StatefulWidget {
  const RecordButton({super.key, required this.recording, required this.enabled, required this.onTap, this.level = 0});
  final bool recording;
  final bool enabled;
  final VoidCallback onTap;
  final double level; // 0–1, agranda las ondas con la voz

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();
  bool _pressed = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = widget.recording ? cs.error : cs.primary;
    const size = 132.0;

    return Semantics(
      button: true,
      label: widget.recording ? 'Detener grabación' : 'Empezar a grabar',
      child: GestureDetector(
        onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: widget.enabled
            ? (_) {
                setState(() => _pressed = false);
                HapticFeedback.mediumImpact();
                widget.onTap();
              }
            : null,
        child: SizedBox.square(
          dimension: size * 1.75,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, child) {
              return CustomPaint(
                painter: _PulsePainter(
                  t: _c.value,
                  color: color,
                  recording: widget.recording,
                  level: widget.level,
                  enabled: widget.enabled,
                ),
                child: child,
              );
            },
            child: Center(
              child: AnimatedScale(
                scale: _pressed ? .92 : 1,
                duration: const Duration(milliseconds: 120),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: widget.enabled
                          ? [Color.lerp(color, Colors.white, .15)!, color]
                          : [cs.surfaceContainerHighest, cs.surfaceContainerHighest],
                    ),
                    boxShadow: widget.enabled
                        ? [BoxShadow(color: color.withValues(alpha: .35), blurRadius: 24, offset: const Offset(0, 10))]
                        : null,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, a) => ScaleTransition(
                      scale: a,
                      child: RotationTransition(turns: Tween(begin: .75, end: 1.0).animate(a), child: child),
                    ),
                    child: Column(
                      key: ValueKey(widget.recording),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.recording ? Icons.stop_rounded : Icons.mic_rounded,
                          size: 52,
                          color: widget.enabled ? Colors.white : cs.onSurfaceVariant,
                        ),
                        Text(
                          widget.recording ? 'Detener' : 'Grabar',
                          style: TextStyle(
                            color: widget.enabled ? Colors.white : cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  _PulsePainter({required this.t, required this.color, required this.recording, required this.level, required this.enabled});
  final double t;
  final Color color;
  final bool recording;
  final double level;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    if (!enabled) return;
    final c = size.center(Offset.zero);
    final base = size.width / 1.75 / 2;
    if (recording) {
      // 3 ondas que salen del botón; más grandes cuanto más fuerte la voz
      for (var i = 0; i < 3; i++) {
        final p = (t + i / 3) % 1;
        final r = base + (base * .55 + level * base * .25) * Curves.easeOut.transform(p);
        canvas.drawCircle(c, r, Paint()..color = color.withValues(alpha: .28 * (1 - p)));
      }
    } else {
      // En reposo: un halo que respira
      final breath = (math.sin(t * 2 * math.pi) + 1) / 2;
      canvas.drawCircle(c, base + 6 + breath * 8, Paint()..color = color.withValues(alpha: .10 + breath * .06));
    }
  }

  @override
  bool shouldRepaint(_PulsePainter old) => true;
}
