// Lee el encabezado YAML de una nota .md para mostrarla bonita en las listas.
import 'dart:convert';
import 'dart:io';

class NoteMeta {
  NoteMeta({
    required this.file,
    required this.titulo,
    this.fecha,
    this.materia = '',
    this.duracion = '',
    this.favoritos = 0,
  });

  final File file;
  final String titulo;
  final DateTime? fecha;
  final String materia;
  final String duracion;
  final int favoritos;

  String get name => file.uri.pathSegments.last;

  static Map<String, String> frontmatter(String text) {
    final out = <String, String>{};
    if (!text.startsWith('---')) return out;
    final end = text.indexOf('\n---', 3);
    if (end < 0) return out;
    for (final line in text.substring(3, end).split('\n')) {
      final i = line.indexOf(':');
      if (i <= 0) continue;
      var v = line.substring(i + 1).trim();
      if (v.length >= 2 && v.startsWith('"') && v.endsWith('"')) v = v.substring(1, v.length - 1);
      out[line.substring(0, i).trim()] = v;
    }
    return out;
  }

  static Future<NoteMeta> read(File f) async {
    var head = '';
    try {
      // Solo el inicio: el encabezado está arriba
      final raf = await f.open();
      head = utf8.decode(await raf.read(1500), allowMalformed: true);
      await raf.close();
    } on Exception {/* nota ilegible: se muestra con el nombre */}
    final fm = frontmatter(head);
    final fallback = f.uri.pathSegments.last.replaceFirst(RegExp(r'^\d{4}-\d{2}-\d{2}_\d{4}_'), '').replaceAll('.md', '');
    return NoteMeta(
      file: f,
      titulo: fm['titulo']?.isNotEmpty == true ? fm['titulo']! : fallback.replaceAll('-', ' '),
      fecha: DateTime.tryParse(fm['fecha'] ?? ''),
      materia: fm['materia'] ?? '',
      duracion: fm['duracion'] ?? '',
      favoritos: int.tryParse(fm['favoritos'] ?? '') ?? 0,
    );
  }

  static Future<List<NoteMeta>> readAll(List<File> files) => Future.wait(files.map(read));
}

const _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

String fechaCorta(DateTime? d) {
  if (d == null) return '';
  final now = DateTime.now();
  final hm = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Hoy $hm';
  if (diff == 1) return 'Ayer $hm';
  return '${d.day} ${_meses[d.month - 1]}${d.year != now.year ? ' ${d.year}' : ''} · $hm';
}
