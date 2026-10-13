// Menú lateral (botón hamburguesa): secciones de la app y Salir.
import 'package:flutter/material.dart';

import '../branding.dart';
import '../server_monitor.dart';
import '../theme.dart';
import 'common.dart';

enum AppSection { grabar, notas, materias, ajustes, acerca }

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.monitor, required this.onSelect, required this.onExit});
  final ServerMonitor monitor;
  final void Function(AppSection) onSelect;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget item(AppSection s, IconData icon, IconData selected, String label, {bool current = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
          selected: current,
          selectedTileColor: cs.secondaryContainer,
          leading: Icon(current ? selected : icon),
          title: Text(label),
          onTap: () {
            Navigator.pop(context);
            onSelect(s);
          },
        ),
      );
    }

    return Drawer(
      child: SafeArea(
        child: Column(children: [
          // Encabezado con el ícono y el estado del server
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(colors: [cs.primaryContainer, cs.tertiaryContainer]),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                ClipOval(child: Image.asset('assets/icon.png', width: 56, height: 56)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Amanuense',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    Text('Voz → texto literal · $appVersion',
                        style: TextStyle(color: cs.onPrimaryContainer.withValues(alpha: .8), fontSize: 12.5)),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              ServerPill(monitor: monitor),
            ]),
          ),
          item(AppSection.grabar, Icons.mic_none_rounded, Icons.mic_rounded, 'Grabar', current: true),
          item(AppSection.notas, Icons.description_outlined, Icons.description_rounded, 'Notas'),
          item(AppSection.materias, Icons.school_outlined, Icons.school_rounded, 'Materias'),
          item(AppSection.ajustes, Icons.settings_outlined, Icons.settings_rounded, 'Configuración'),
          item(AppSection.acerca, Icons.info_outline_rounded, Icons.info_rounded, 'Acerca de'),
          const Spacer(),
          const Divider(indent: 24, endIndent: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
              leading: Icon(Icons.logout_rounded, color: cs.error),
              title: Text('Salir', style: TextStyle(color: cs.error)),
              onTap: () {
                Navigator.pop(context);
                onExit();
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 20, 16),
            child: Align(alignment: Alignment.centerRight, child: Firma()),
          ),
        ]),
      ),
    );
  }
}
