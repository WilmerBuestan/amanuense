// Piezas de interfaz reutilizables: estado del server, tarjeta de nota, estado vacío.
import 'package:flutter/material.dart';

import '../note_meta.dart';
import '../server_monitor.dart';
import '../theme.dart';

/// Punto de color con texto: En línea / Cargando / Sin conexión.
class ServerPill extends StatelessWidget {
  const ServerPill({super.key, required this.monitor, this.compact = false});
  final ServerMonitor monitor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<ServerStatus>(
      valueListenable: monitor,
      builder: (context, s, _) {
        final (color, label) = switch (s.state) {
          ServerState.online => (const Color(0xFF2E9E5B), 'En línea'),
          ServerState.loading => (Brand.gold, 'Cargando modelo'),
          ServerState.checking => (cs.outline, 'Conectando…'),
          ServerState.offline => (cs.error, 'Sin conexión'),
        };
        final dot = _Dot(color: color, pulse: s.state != ServerState.offline);
        if (compact) {
          return Tooltip(
            message: '$label${s.detail.isNotEmpty ? ' · ${s.detail}' : ''}',
            child: IconButton(onPressed: monitor.check, icon: dot),
          );
        }
        return InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: monitor.check,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              dot,
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  s.state == ServerState.online ? '$label · ${s.detail}' : label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: cs.onSurface),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _Dot extends StatefulWidget {
  const _Dot({required this.color, required this.pulse});
  final Color color;
  final bool pulse;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 14,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Stack(alignment: Alignment.center, children: [
          if (widget.pulse)
            Container(
              width: 6 + 8 * _c.value,
              height: 6 + 8 * _c.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: .35 * (1 - _c.value)),
              ),
            ),
          Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color)),
        ]),
      ),
    );
  }
}

/// Tarjeta de una nota en las listas.
class NoteCard extends StatelessWidget {
  const NoteCard({super.key, required this.meta, required this.onTap});
  final NoteMeta meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.description_rounded, color: cs.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(meta.titulo, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.titleSmall),
                const SizedBox(height: 4),
                Wrap(spacing: 10, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  if (meta.materia.isNotEmpty) _Meta(Icons.school_rounded, meta.materia),
                  if (meta.fecha != null) _Meta(Icons.schedule_rounded, fechaCorta(meta.fecha)),
                  if (meta.duracion.isNotEmpty) _Meta(Icons.timer_outlined, meta.duracion),
                  if (meta.favoritos > 0)
                    Text('⭐ ${meta.favoritos}', style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                ]),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: cs.outline),
          ]),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: c),
      const SizedBox(width: 3),
      Text(text, style: TextStyle(fontSize: 12.5, color: c)),
    ]);
  }
}

/// Estado vacío con ícono grande y una acción.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.text = '', this.action});
  final IconData icon;
  final String title;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: .5), shape: BoxShape.circle),
          child: Icon(icon, size: 40, color: cs.primary),
        ),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
        if (text.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
        ],
        if (action != null) ...[const SizedBox(height: 16), action!],
      ]),
    );
  }
}

/// Aparece deslizándose desde abajo (para listas y tarjetas).
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({super.key, required this.child, this.delay = 0});
  final Widget child;
  final int delay; // índice para escalonar

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + 40 * delay.clamp(0, 8)),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: child),
      ),
      child: child,
    );
  }
}
