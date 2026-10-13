// Dónde se guardan las notas .md y los audios.
// Carpeta base = bóveda Cerebro_wilo: en la PC la real, en el celular una copia
// que Syncthing mantiene igual. Dentro: Amanuense/ (sin materia) o la carpeta de cada materia.
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'settings.dart';

class Storage {
  static final _notaRe = RegExp(r'^\d{4}-\d{2}-\d{2}_\d{4}_.*\.md$');

  /// Android: Documents/Cerebro_wilo · PC: ~/Documentos/Cerebro_wilo (si existe)
  static Future<String> defaultFolder() async {
    if (Platform.isAndroid) return '/storage/emulated/0/Documents/Cerebro_wilo';
    final docs = await getApplicationDocumentsDirectory();
    final vault = Directory('${docs.path}/Cerebro_wilo');
    return await vault.exists() ? vault.path : '${docs.path}/Amanuense';
  }

  /// En Android pide "Acceso a todos los archivos" para escribir fuera de la app.
  static Future<bool> ensureAccess() async {
    if (!Platform.isAndroid) return true;
    if (await Permission.manageExternalStorage.isGranted) return true;
    return (await Permission.manageExternalStorage.request()).isGranted;
  }

  static Future<String> base(Settings s) async => s.folder ?? await defaultFolder();

  static Future<Directory> notesDir(Settings s, Materia? m) async {
    final dir = Directory('${await base(s)}/${m?.carpeta ?? Settings.generalFolder}');
    await dir.create(recursive: true);
    return dir;
  }

  /// Audios en grabación o pendientes (se borran al transcribir bien; quedan si falla).
  static Future<Directory> audioDir() async {
    final b = await getApplicationSupportDirectory();
    final dir = Directory('${b.path}/audios');
    await dir.create(recursive: true);
    return dir;
  }

  /// Audios guardados para entrenar: fuera de la bóveda, para no llenarla.
  static Future<Directory> datasetDir(Settings s) async {
    final dir = Directory('${await base(s)}_audios');
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

  /// Notas de Amanuense (nombre AAAA-MM-DD_HHMM_titulo.md) en la carpeta general y las de cada materia.
  static Future<List<File>> listNotes(Settings s) async {
    final b = await base(s);
    final dirs = {Settings.generalFolder, ...s.materias.map((m) => m.carpeta)};
    final files = <File>[];
    for (final d in dirs) {
      final dir = Directory('$b/$d');
      if (!await dir.exists()) continue;
      await for (final e in dir.list()) {
        if (e is File && _notaRe.hasMatch(e.uri.pathSegments.last)) files.add(e);
      }
    }
    files.sort((a, b) => b.uri.pathSegments.last.compareTo(a.uri.pathSegments.last)); // más nuevas primero
    return files;
  }
}
