// Configuración persistente: dirección del server, carpeta de notas y velocidad aprendida.
import 'package:shared_preferences/shared_preferences.dart';

class Settings {
  Settings._(this._p);
  final SharedPreferences _p;

  static const defaultServer = 'http://192.168.100.97:8000';

  static Future<Settings> load() async => Settings._(await SharedPreferences.getInstance());

  String get server => _p.getString('server') ?? defaultServer;
  set server(String v) => _p.setString('server', v.trim().replaceAll(RegExp(r'/+$'), ''));

  /// null = carpeta por defecto (Documents/Amanuense)
  String? get folder => _p.getString('folder');
  set folder(String? v) => v == null || v.trim().isEmpty ? _p.remove('folder') : _p.setString('folder', v.trim());

  String get apiKey => _p.getString('apiKey') ?? '';
  set apiKey(String v) => _p.setString('apiKey', v.trim());

  /// Segundos de proceso por segundo de audio; se ajusta con cada transcripción.
  double get ratio => _p.getDouble('ratio') ?? 0.12;
  set ratio(double v) => _p.setDouble('ratio', v);
}
