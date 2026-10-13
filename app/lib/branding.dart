// Marca Amanuense: banner y firma "by wilo" (assets/banner.txt y assets/firma.txt,
// copiados de server/ para que sean los mismos).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AsciiArt extends StatelessWidget {
  const AsciiArt(this.asset, {super.key, this.width, this.opacity = 1, this.label = ''});
  final String asset;
  final double? width;
  final double opacity;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Semantics(
      label: label,
      child: FutureBuilder<String>(
        future: rootBundle.loadString(asset),
        builder: (context, snap) {
          if (!snap.hasData) return const SizedBox.shrink();
          return SizedBox(
            width: width,
            child: Opacity(
              opacity: opacity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  snap.data!.trimRight(),
                  softWrap: false,
                  style: TextStyle(fontFamily: 'monospace', height: 1, fontSize: 12, color: color),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class AmanuenseBanner extends StatelessWidget {
  const AmanuenseBanner({super.key});
  @override
  Widget build(BuildContext context) => const AsciiArt('assets/banner.txt', label: 'Amanuense');
}

/// Firma chiquita, como pie de página.
class Firma extends StatelessWidget {
  const Firma({super.key});
  @override
  Widget build(BuildContext context) =>
      const AsciiArt('assets/firma.txt', width: 110, opacity: .75, label: 'by wilo');
}
