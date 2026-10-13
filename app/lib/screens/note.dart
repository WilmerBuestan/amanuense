// Ver una nota .md guardada.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NoteScreen extends StatelessWidget {
  const NoteScreen({super.key, required this.file});
  final File file;

  @override
  Widget build(BuildContext context) {
    final name = file.uri.pathSegments.last;
    return Scaffold(
      appBar: AppBar(
        title: Text(name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Copiar texto',
            icon: const Icon(Icons.copy),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: await file.readAsString()));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Texto copiado')));
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: file.readAsString(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(snap.data!, style: const TextStyle(height: 1.5)),
          );
        },
      ),
    );
  }
}
