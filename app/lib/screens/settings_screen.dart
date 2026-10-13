// Configuración: dirección del server y carpeta de notas.
import 'package:flutter/material.dart';

import '../api.dart';
import '../settings.dart';
import '../storage.dart';
import 'materias_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.settings});
  final Settings settings;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final _server = TextEditingController(text: widget.settings.server);
  late final _folder = TextEditingController(text: widget.settings.folder ?? '');
  late final _key = TextEditingController(text: widget.settings.apiKey);
  String _defaultFolder = '';
  String? _status;
  bool _needsKey = false;
  bool _testing = false;
  late bool _keepAudio = widget.settings.keepAudio;

  @override
  void initState() {
    super.initState();
    Storage.defaultFolder().then((f) => setState(() => _defaultFolder = f));
    _needsKey = widget.settings.apiKey.isNotEmpty;
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _status = null;
    });
    try {
      final h = await Api(_server.text.trim()).health();
      setState(() {
        _needsKey = _needsKey || h['auth'] == true;
        _status = h['status'] == 'ok'
            ? '✅ Conectado · modelo ${h['model']} · ${h['device']}'
            : '⏳ El server está cargando el modelo…';
      });
    } on ApiException catch (e) {
      setState(() => _status = '❌ $e');
    } finally {
      setState(() => _testing = false);
    }
  }

  void _save() {
    widget.settings
      ..server = _server.text
      ..folder = _folder.text
      ..apiKey = _key.text
      ..keepAudio = _keepAudio;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _server,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Server',
              helperText: 'Ej: http://192.168.100.97:8000',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            OutlinedButton.icon(
              onPressed: _testing ? null : _test,
              icon: const Icon(Icons.wifi_tethering),
              label: const Text('Probar conexión'),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(_status ?? '')),
          ]),
          if (_needsKey) ...[
            const SizedBox(height: 20),
            TextField(
              controller: _key,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'API key',
                helperText: 'El server la exige',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 20),
          TextField(
            controller: _folder,
            decoration: InputDecoration(
              labelText: 'Carpeta base (bóveda Cerebro_wilo)',
              hintText: _defaultFolder,
              helperText: 'Vacío = $_defaultFolder',
              helperMaxLines: 2,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.school_outlined),
            title: const Text('Materias'),
            subtitle: const Text('Carpeta y vocabulario de cada materia'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => MateriasScreen(settings: widget.settings)),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _keepAudio,
            onChanged: (v) => setState(() => _keepAudio = v),
            title: const Text('Guardar los audios'),
            subtitle: Text('En ${(_folder.text.isEmpty ? _defaultFolder : _folder.text)}_audios, '
                'fuera de la bóveda. Sirven para entrenar un modelo propio más adelante.'),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Guardar')),
        ],
      ),
    );
  }
}
