// Cliente del server Amanuense (FastAPI + faster-whisper).
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class Note {
  Note(this.name, this.markdown);
  final String name;
  final String markdown;
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class Api {
  Api(this.server, {this.apiKey = ''});
  final String server;
  final String apiKey;

  Map<String, String> get _headers => apiKey.isEmpty ? {} : {'X-API-Key': apiKey};

  Future<Map<String, dynamic>> health() async {
    try {
      final r = await http.get(Uri.parse('$server/health')).timeout(const Duration(seconds: 5));
      return jsonDecode(r.body) as Map<String, dynamic>;
    } on Exception {
      throw ApiException('No se pudo conectar con $server');
    }
  }

  /// Sube el audio y devuelve la nota .md lista para guardar.
  Future<Note> transcribe(File audio, {String title = ''}) async {
    final req = http.MultipartRequest('POST', Uri.parse('$server/transcribe/md'))
      ..headers.addAll(_headers)
      ..files.add(await http.MultipartFile.fromPath('audio', audio.path));
    if (title.trim().isNotEmpty) req.fields['title'] = title.trim();

    final http.Response r;
    try {
      r = await http.Response.fromStream(await req.send());
    } on Exception {
      throw ApiException('No se pudo conectar con $server');
    }
    final body = utf8.decode(r.bodyBytes);
    if (r.statusCode != 200) {
      String detail = r.reasonPhrase ?? 'Error ${r.statusCode}';
      try {
        detail = (jsonDecode(body) as Map)['detail']?.toString() ?? detail;
      } on FormatException {/* respuesta no JSON */}
      throw ApiException('Error ${r.statusCode}: $detail');
    }
    final cd = r.headers['content-disposition'] ?? '';
    final name = RegExp(r'filename="([^"]+)"').firstMatch(cd)?.group(1) ?? 'nota.md';
    return Note(name, body);
  }
}
