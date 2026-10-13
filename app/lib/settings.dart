// Configuración persistente: server, carpeta base, materias y velocidad aprendida.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Una materia: dónde caen sus notas dentro de la bóveda y qué palabras debe acertar Whisper.
class Materia {
  Materia({required this.nombre, required this.carpeta, this.vocabulario = ''});
  String nombre;
  String carpeta; // relativa a la carpeta base, ej. "VIII Semestre/Evolucion"
  String vocabulario; // términos separados por coma

  Map<String, dynamic> toJson() => {'nombre': nombre, 'carpeta': carpeta, 'vocabulario': vocabulario};
  factory Materia.fromJson(Map<String, dynamic> j) => Materia(
        nombre: j['nombre'] as String,
        carpeta: j['carpeta'] as String,
        vocabulario: (j['vocabulario'] as String?) ?? '',
      );
}

class Settings {
  Settings._(this._p);
  final SharedPreferences _p;

  static const defaultServer = 'http://192.168.100.97:8000';
  /// Notas sin materia
  static const generalFolder = 'Amanuense';

  static Future<Settings> load() async => Settings._(await SharedPreferences.getInstance());

  String get server => _p.getString('server') ?? defaultServer;
  set server(String v) => _p.setString('server', v.trim().replaceAll(RegExp(r'/+$'), ''));

  /// Carpeta base (la bóveda Cerebro_wilo). null = la de por defecto.
  String? get folder => _p.getString('folder');
  set folder(String? v) => v == null || v.trim().isEmpty ? _p.remove('folder') : _p.setString('folder', v.trim());

  String get apiKey => _p.getString('apiKey') ?? '';
  set apiKey(String v) => _p.setString('apiKey', v.trim());

  /// Guardar el audio junto a la nota: material para entrenar un modelo propio más adelante.
  bool get keepAudio => _p.getBool('keepAudio') ?? false;
  set keepAudio(bool v) => _p.setBool('keepAudio', v);

  List<Materia> get materias {
    final raw = _p.getString('materias');
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => Materia.fromJson(e as Map<String, dynamic>)).toList();
  }

  set materias(List<Materia> v) => _p.setString('materias', jsonEncode(v.map((m) => m.toJson()).toList()));

  String? get lastMateria => _p.getString('lastMateria');
  set lastMateria(String? v) => v == null ? _p.remove('lastMateria') : _p.setString('lastMateria', v);

  /// Segundos de proceso por segundo de audio; se ajusta con cada transcripción.
  double get ratio => _p.getDouble('ratio') ?? 0.12;
  set ratio(double v) => _p.setDouble('ratio', v);
}
