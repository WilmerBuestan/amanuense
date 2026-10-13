// Dónde se guardan las notas .md y los audios.
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class Storage {
  /// Android: /storage/emulated/0/Documents/Amanuense · PC: ~/Documentos/Amanuense
  static Future<String> defaultFolder() async {
    if (Platform.isAndroid) return '/storage/emulated/0/Documents/Amanuense';
    final docs = await getApplicationDocumentsDirectory();
    return '${docs.path}/Amanuense';
  }

  /// En Android pide "Acceso a todos los archivos" para escribir fuera de la app.
  static Future<bool> ensureAccess() async {
    if (!Platform.isAndroid) return true;
    if (await Permission.manageExternalStorage.isGranted) return true;
    return (await Permission.manageExternalStorage.request()).isGranted;
  }

  static Future<Directory> notesDir(String? custom) async {
    final dir = Directory(custom ?? await defaultFolder());
    await dir.create(recursive: true);
    return dir;
  }

  /// Audios de las grabaciones (se borran al transcribir bien; quedan si falla).
  static Future<Directory> audioDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/audios');
    await dir.create(recursive: true);
    return dir;
  }

  static Future<File> saveNote(Directory dir, String name, String markdown) async {
    var file = File('${dir.path}/$name');
    var i = 2;
    while (await file.exists()) {
      file = File('${dir.path}/${name.replaceFirst(RegExp(r'\.md$'), '')}_$i.md');
      i++;
    }
    return file.writeAsString(markdown);
  }

  static Future<List<File>> listNotes(Directory dir) async {
    final files = await dir
        .list()
        .where((e) => e is File && e.path.endsWith('.md'))
        .cast<File>()
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path)); // AAAA-MM-DD_HHMM → más nuevas primero
    return files;
  }
}
