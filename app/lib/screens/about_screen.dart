// Acerca de: logo, versión, cómo se usa y la firma.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../branding.dart';
import '../theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const repo = 'https://github.com/WilmerBuestan/amanuense';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    Widget paso(IconData icon, String title, String text) => ListTile(
          leading: CircleAvatar(
            backgroundColor: cs.primaryContainer,
            child: Icon(icon, color: cs.onPrimaryContainer, size: 20),
          ),
          title: Text(title),
          subtitle: Text(text),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Acerca de')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Center(
          child: Hero(
            tag: 'logo',
            child: ClipOval(child: Image.asset('assets/icon.png', width: 120, height: 120)),
          ),
        ),
        const SizedBox(height: 16),
        const AmanuenseBanner(),
        const SizedBox(height: 8),
        Center(child: Text('Voz → texto literal → tu Cerebro · $appVersion', style: tt.bodyMedium)),
        const SizedBox(height: 24),
        Card(
          child: Column(children: [
            paso(Icons.school_rounded, '1. Elige la materia', 'La nota cae en su carpeta y Whisper usa su vocabulario.'),
            paso(Icons.mic_rounded, '2. Graba', 'Puedes apagar la pantalla. Controla todo desde la notificación.'),
            paso(Icons.star_rounded, '3. Marca con ⭐', 'Justo después de algo importante: va a "Momentos importantes".'),
            paso(Icons.description_rounded, '4. Detén', 'Se transcribe en tu server y se guarda el .md en la bóveda.'),
          ]),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.code_rounded),
            title: const Text('Código en GitHub'),
            subtitle: const Text(repo),
            trailing: const Icon(Icons.copy_rounded),
            onTap: () async {
              await Clipboard.setData(const ClipboardData(text: repo));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enlace copiado')));
              }
            },
          ),
        ),
        const SizedBox(height: 32),
        const Center(child: Firma()),
        const SizedBox(height: 6),
        Center(child: Text('Wilmer Buestan', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12))),
      ]),
    );
  }
}
