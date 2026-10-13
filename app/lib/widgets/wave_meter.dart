// Onda de voz en vivo: barras con el historial reciente del nivel del micrófono.
import 'package:flutter/material.dart';

class WaveMeter extends StatelessWidget {
  const WaveMeter({super.key, required this.levels, this.height = 48});
  final List<double> levels; // 0–1, el último es el más reciente
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _WavePainter(levels, color)),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.levels, this.color);
  final List<double> levels;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const bar = 4.0, gap = 3.0;
    final n = (size.width / (bar + gap)).floor();
    final mid = size.height / 2;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = bar;
    for (var i = 0; i < n; i++) {
      final idx = levels.length - n + i;
      final v = idx >= 0 ? levels[idx] : 0.0;
      final h = 3 + v * (size.height - 6);
      final x = i * (bar + gap) + bar / 2;
      // Más opaco hacia la derecha (lo más reciente)
      paint.color = color.withValues(alpha: .25 + .75 * (i / n));
      canvas.drawLine(Offset(x, mid - h / 2), Offset(x, mid + h / 2), paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => true;
}
