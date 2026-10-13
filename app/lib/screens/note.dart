// Ver una nota: encabezado con datos, ⭐ momentos importantes y transcripción con marcas de tiempo.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../note_meta.dart';
import '../theme.dart';

class NoteScreen extends StatefulWidget {
  const NoteScreen({super.key, required this.file});
  final File file;

  @override
  State<NoteScreen> createState() => _NoteScreenState();
}

class _NoteScreenState extends State<NoteScreen> {
  String? _text;
  bool _raw = false;

  @override
  void initState() {
    super.initState();
    widget.file.readAsString().then((t) => setState(() => _text = t));
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _text ?? ''));
    HapticFeedback.selectionClick();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📋 Texto copiado')));
    }
  }

  Future<void> _share() async {
    await SharePlus.instance.share(ShareParams(files: [XFile(widget.file.path)], subject: _title));
  }

  String get _title => NoteMeta.frontmatter(_text ?? '')['titulo'] ?? widget.file.uri.pathSegments.last;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_text == null ? '' : _title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: _raw ? 'Ver con formato' : 'Ver texto .md',
            icon: Icon(_raw ? Icons.article_outlined : Icons.code_rounded),
            onPressed: () => setState(() => _raw = !_raw),
          ),
          IconButton(tooltip: 'Copiar', icon: const Icon(Icons.copy_rounded), onPressed: _copy),
          IconButton(tooltip: 'Compartir', icon: const Icon(Icons.share_rounded), onPressed: _share),
        ],
      ),
      body: _text == null
          ? const Center(child: CircularProgressIndicator())
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _raw
                  ? SingleChildScrollView(
                      key: const ValueKey('raw'),
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(_text!, style: const TextStyle(fontFamily: 'monospace', height: 1.5)),
                    )
                  : _Rendered(key: const ValueKey('nice'), text: _text!),
            ),
    );
  }
}

/// Muestra la nota de Amanuense con formato (sin depender de un paquete de Markdown).
class _Rendered extends StatelessWidget {
  const _Rendered({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fm = NoteMeta.frontmatter(text);
    var body = text;
    if (text.startsWith('---')) {
      final end = text.indexOf('\n---', 3);
      if (end > 0) body = text.substring(end + 4);
    }

    final children = <Widget>[];

    // Tarjeta de datos
    final chips = <(IconData, String)>[
      if ((fm['materia'] ?? '').isNotEmpty) (Icons.school_rounded, fm['materia']!),
      if ((fm['fecha'] ?? '').isNotEmpty) (Icons.event_rounded, fechaCorta(DateTime.tryParse(fm['fecha']!))),
      if ((fm['duracion'] ?? '').isNotEmpty) (Icons.timer_outlined, fm['duracion']!),
      if ((fm['favoritos'] ?? '').isNotEmpty) (Icons.star_rounded, '${fm['favoritos']} favorito${fm['favoritos'] == '1' ? '' : 's'}'),
    ];
    if (chips.isNotEmpty) {
      children.add(Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (icon, label) in chips)
          Chip(
            avatar: Icon(icon, size: 16, color: icon == Icons.star_rounded ? Brand.gold : cs.primary),
            label: Text(label),
            visualDensity: VisualDensity.compact,
          ),
      ]));
      children.add(const SizedBox(height: 8));
    }

    final tsRe = RegExp(r'^(⭐ )?\*\*\[([\d:]+)\]\*\* ?(.*)$');
    for (final raw in body.split('\n')) {
      final line = raw.trimRight();
      if (line.isEmpty) continue;
      if (line.startsWith('# ')) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(line.substring(2), style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        ));
      } else if (line.startsWith('## ')) {
        final star = line.contains('⭐');
        children.add(Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Row(children: [
            Icon(star ? Icons.star_rounded : Icons.notes_rounded, color: star ? Brand.gold : cs.primary, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(line.substring(3).replaceAll('⭐ ', ''),
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
          ]),
        ));
      } else if (line.startsWith('📚')) {
        continue; // ya está en la tarjeta de datos
      } else if (line == '---') {
        children.add(const Divider(height: 32));
      } else if (line.startsWith('- ')) {
        final m = RegExp(r'^- \*\*\[([\d:]+)\]\*\* (.*)$').firstMatch(line);
        children.add(Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Brand.goldSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border(left: BorderSide(color: Brand.gold, width: 3)),
          ),
          child: m == null
              ? Text(line.substring(2))
              : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _Ts(m.group(1)!, gold: true),
                  const SizedBox(width: 10),
                  Expanded(child: SelectableText(m.group(2)!, style: const TextStyle(height: 1.45))),
                ]),
        ));
      } else if (tsRe.hasMatch(line)) {
        final m = tsRe.firstMatch(line)!;
        final star = m.group(1) != null;
        children.add(Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: star ? const EdgeInsets.all(10) : const EdgeInsets.symmetric(vertical: 2),
          decoration: star
              ? BoxDecoration(color: Brand.goldSoft, borderRadius: BorderRadius.circular(14))
              : null,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Ts(m.group(2)!, gold: star),
            const SizedBox(width: 10),
            Expanded(child: SelectableText(m.group(3)!, style: const TextStyle(height: 1.55, fontSize: 15.5))),
          ]),
        ));
      } else if (line.startsWith('_') && line.endsWith('_')) {
        children.add(Align(
          alignment: Alignment.centerRight,
          child: Text(line.substring(1, line.length - 1),
              style: TextStyle(fontStyle: FontStyle.italic, color: cs.onSurfaceVariant, fontSize: 12.5)),
        ));
      } else {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SelectableText(line, style: const TextStyle(height: 1.55)),
        ));
      }
    }

    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: children);
  }
}

class _Ts extends StatelessWidget {
  const _Ts(this.ts, {this.gold = false});
  final String ts;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: gold ? Brand.gold : cs.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        gold ? '⭐ $ts' : ts,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
          color: gold ? Colors.black87 : cs.onSecondaryContainer,
        ),
      ),
    );
  }
}
