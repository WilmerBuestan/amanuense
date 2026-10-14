// Configuración en secciones: Server, Notas y Avanzado.
import 'package:flutter/material.dart';

import '../api.dart';
import '../settings.dart';
import '../storage.dart';
import '../theme.dart';
import 'materias_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.settings});
  final Settings settings;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

enum _Test { none, testing, ok, fail }

class _SettingsScreenState extends State<SettingsScreen> {
  late final _server = TextEditingController(text: widget.settings.server);
  late final _folder = TextEditingController(text: widget.settings.folder ?? '');
  late final _key = TextEditingController(text: widget.settings.apiKey);
  String _defaultFolder = '';
  String _status = '';
  _Test _test = _Test.none;
  bool _needsKey = false;
  bool _showKey = false;
  late bool _keepAudio = widget.settings.keepAudio;

  @override
  void initState() {
    super.initState();
    Storage.defaultFolder().then((f) => setState(() => _defaultFolder = f));
    _needsKey = widget.settings.apiKey.isNotEmpty;
  }

  @override
  void dispose() {
    _server.dispose();
    _folder.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _probar() async {
    setState(() => _test = _Test.testing);
    try {
      final h = await Api(_server.text.trim()).health();
      setState(() {
        _needsKey = _needsKey || h['auth'] == true;
        _test = _Test.ok;
        _status = h['status'] == 'ok' ? 'Conectado · ${h['model']} · ${h['device']}' : 'Cargando el modelo…';
      });
    } on ApiException catch (e) {
      setState(() {
        _test = _Test.fail;
        _status = '$e';
      });
    }
  }

  void _save() {
    widget.settings
      ..server = _server.text
      ..folder = _folder.text
      ..apiKey = _key.text
      ..keepAudio = _keepAudio;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Configuración guardada')));
    Navigator.pop(context, true);
  }

  Widget _section(IconData icon, String title) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Row(children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700, letterSpacing: .3)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final testIcon = switch (_test) {
      _Test.none => const Icon(Icons.wifi_tethering_rounded, key: ValueKey(0)),
      _Test.testing => const SizedBox.square(
          key: ValueKey(1), dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
      _Test.ok => const Icon(Icons.check_circle_rounded, key: ValueKey(2), color: Color(0xFF2E9E5B)),
      _Test.fail => Icon(Icons.error_rounded, key: const ValueKey(3), color: cs.error),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _save,
            icon: const Icon(Icons.save_rounded),
            label: const Text('Guardar'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _section(Icons.dns_rounded, 'SERVER'),
          TextField(
            controller: _server,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.link_rounded),
              labelText: 'Dirección',
              helperText: 'Con Tailscale: http://wilo-server:8000 (casa y fuera) · Solo casa: http://192.168.100.134:8000',
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            OutlinedButton.icon(
              onPressed: _test == _Test.testing ? null : _probar,
              icon: AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: testIcon),
              label: const Text('Probar conexión'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _status,
                  key: ValueKey(_status),
                  style: TextStyle(color: _test == _Test.fail ? cs.error : cs.onSurfaceVariant, fontSize: 13),
                ),
              ),
            ),
          ]),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: _needsKey
                ? Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: TextField(
                      controller: _key,
                      obscureText: !_showKey,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.key_rounded),
                        labelText: 'API key',
                        helperText: 'El server la exige',
                        suffixIcon: IconButton(
                          tooltip: _showKey ? 'Ocultar' : 'Mostrar',
                          icon: Icon(_showKey ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                          onPressed: () => setState(() => _showKey = !_showKey),
                        ),
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          _section(Icons.folder_rounded, 'NOTAS'),
          TextField(
            controller: _folder,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.folder_open_rounded),
              labelText: 'Carpeta base (bóveda Cerebro_wilo)',
              hintText: _defaultFolder,
              helperText: 'Vacío = $_defaultFolder',
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.school_rounded),
              title: const Text('Materias'),
              subtitle: Text('${widget.settings.materias.length} · carpeta y vocabulario de cada una'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                await Navigator.push(context, slideRoute(MateriasScreen(settings: widget.settings)));
                setState(() {});
              },
            ),
          ),
          _section(Icons.science_rounded, 'AVANZADO'),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.graphic_eq_rounded),
              value: _keepAudio,
              onChanged: (v) => setState(() => _keepAudio = v),
              title: const Text('Guardar los audios'),
              subtitle: Text('En ${(_folder.text.isEmpty ? _defaultFolder : _folder.text)}_audios, fuera de la '
                  'bóveda. Sirven para entrenar un modelo propio más adelante.'),
            ),
          ),
        ],
      ),
    );
  }
}
