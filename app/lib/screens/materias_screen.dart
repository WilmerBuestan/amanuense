// Materias: nombre, carpeta dentro de la bóveda y vocabulario para Whisper.
import 'package:flutter/material.dart';

import '../settings.dart';

class MateriasScreen extends StatefulWidget {
  const MateriasScreen({super.key, required this.settings});
  final Settings settings;

  @override
  State<MateriasScreen> createState() => _MateriasScreenState();
}

class _MateriasScreenState extends State<MateriasScreen> {
  late List<Materia> _materias = widget.settings.materias;

  void _save() => widget.settings.materias = _materias;

  Future<void> _edit([Materia? m]) async {
    final result = await showDialog<Materia>(context: context, builder: (_) => _MateriaDialog(materia: m));
    if (result == null) return;
    setState(() {
      if (m == null) {
        _materias = [..._materias, result];
      } else {
        m
          ..nombre = result.nombre
          ..carpeta = result.carpeta
          ..vocabulario = result.vocabulario;
      }
    });
    _save();
  }

  Future<void> _delete(Materia m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('¿Quitar ${m.nombre}?'),
        content: const Text('Las notas ya guardadas no se borran.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Quitar')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _materias = _materias.where((x) => x != m).toList());
    _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Materias')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Materia'),
      ),
      body: _materias.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Agrega tus materias. Cada una guarda sus notas en su carpeta de la bóveda '
                  'y tiene un vocabulario para que Whisper acierte los términos técnicos.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                for (final m in _materias)
                  ListTile(
                    leading: const Icon(Icons.school_outlined),
                    title: Text(m.nombre),
                    subtitle: Text(
                      [m.carpeta, if (m.vocabulario.isNotEmpty) '🗣️ ${m.vocabulario}'].join('\n'),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    isThreeLine: m.vocabulario.isNotEmpty,
                    onTap: () => _edit(m),
                    trailing: IconButton(
                      tooltip: 'Quitar',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(m),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _MateriaDialog extends StatefulWidget {
  const _MateriaDialog({this.materia});
  final Materia? materia;

  @override
  State<_MateriaDialog> createState() => _MateriaDialogState();
}

class _MateriaDialogState extends State<_MateriaDialog> {
  late final _nombre = TextEditingController(text: widget.materia?.nombre ?? '');
  late final _carpeta = TextEditingController(text: widget.materia?.carpeta ?? '');
  late final _vocab = TextEditingController(text: widget.materia?.vocabulario ?? '');
  late bool _carpetaManual = widget.materia != null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.materia == null ? 'Nueva materia' : 'Editar materia'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _nombre,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Evolucion'),
            onChanged: (v) {
              if (!_carpetaManual) _carpeta.text = 'VIII Semestre/${v.trim()}';
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _carpeta,
            decoration: const InputDecoration(
              labelText: 'Carpeta en la bóveda',
              hintText: 'VIII Semestre/Evolucion',
            ),
            onChanged: (_) => _carpetaManual = true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _vocab,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Vocabulario',
              hintText: 'SOA, WSDL, microservicios, Kubernetes',
              helperText: 'Nombres y términos que Whisper debe escribir bien, separados por coma',
              helperMaxLines: 2,
            ),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final nombre = _nombre.text.trim();
            if (nombre.isEmpty) return;
            final carpeta = _carpeta.text.trim().replaceAll(RegExp(r'^/+|/+$'), '');
            Navigator.pop(
              context,
              Materia(
                nombre: nombre,
                carpeta: carpeta.isEmpty ? 'VIII Semestre/$nombre' : carpeta,
                vocabulario: _vocab.text.trim(),
              ),
            );
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
