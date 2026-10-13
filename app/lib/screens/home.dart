// Pantalla principal: Grabar / ⭐ / Detener → transcribir → guardar .md en la bóveda → lista de notas.
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../api.dart';
import '../branding.dart';
import '../recording_service.dart';
import '../settings.dart';
import '../storage.dart';
import 'note.dart';
import 'settings_screen.dart';

enum Phase { idle, recording, transcribing }

/// Lo necesario para (re)intentar una transcripción.
class _Take {
  _Take(this.audio, this.duration, this.title, this.materia, this.marcas);
  final File audio;
  final Duration duration;
  final String title;
  final Materia? materia;
  final List<double> marcas;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.settings});
  final Settings settings;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _recorder = AudioRecorder();
  final _title = TextEditingController();

  Phase _phase = Phase.idle;
  DateTime? _started;
  Duration _elapsed = Duration.zero;
  double _level = 0; // 0–1, nivel del micrófono
  double _progress = 0;
  String? _error;
  _Take? _pending; // grabación que falló, para reintentar
  List<File> _notes = [];
  Materia? _materia;
  final List<double> _marcas = []; // segundos marcados con ⭐

  Timer? _clock;
  Timer? _progressTimer;
  StreamSubscription<Amplitude>? _ampSub;

  Settings get _s => widget.settings;

  @override
  void initState() {
    super.initState();
    _restoreMateria();
    RecordingService.listen(_onServiceData);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await RecordingService.requestPermissions();
      await _loadNotes();
    });
  }

  @override
  void dispose() {
    RecordingService.unlisten(_onServiceData);
    _clock?.cancel();
    _progressTimer?.cancel();
    _ampSub?.cancel();
    _recorder.dispose();
    _title.dispose();
    super.dispose();
  }

  void _restoreMateria() {
    final name = _s.lastMateria;
    _materia = _s.materias.where((m) => m.nombre == name).firstOrNull;
  }

  /// Botones de la notificación: ⭐ Marcar / ⏹ Detener
  void _onServiceData(Object data) {
    if (_phase != Phase.recording) return;
    if (data == 'star') _star();
    if (data == 'stop') _stop();
  }

  Future<bool> _ensureStorage() async {
    if (await Storage.ensureAccess()) return true;
    _showError('Sin permiso para guardar en ${await Storage.base(_s)}. '
        'Actívalo en Ajustes → Apps → Amanuense → Acceso a todos los archivos.');
    return false;
  }

  Future<void> _loadNotes() async {
    if (!await _ensureStorage()) return;
    final notes = await Storage.listNotes(_s);
    if (mounted) setState(() => _notes = notes);
  }

  void _showError(String msg) {
    if (mounted) setState(() => _error = msg);
  }

  // ---------- Grabación ----------

  Future<void> _start() async {
    if (!await _recorder.hasPermission()) {
      _showError('Sin permiso de micrófono.');
      return;
    }
    final dir = await Storage.audioDir();
    final path = '${dir.path}/grabacion_${DateTime.now().millisecondsSinceEpoch}.m4a';
    // Primero el servicio: así Android deja usar el micrófono con la pantalla apagada
    await RecordingService.start([_materia?.nombre, _title.text.trim()].whereType<String>().where((x) => x.isNotEmpty).join(' · '));
    // 16 kHz mono: es lo que usa Whisper, archivos livianos (~30 MB por hora)
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000, numChannels: 1, bitRate: 64000),
      path: path,
    );
    _started = DateTime.now();
    _clock = Timer.periodic(const Duration(milliseconds: 250), (_) {
      setState(() => _elapsed = DateTime.now().difference(_started!));
    });
    _ampSub = _recorder.onAmplitudeChanged(const Duration(milliseconds: 150)).listen((a) {
      setState(() => _level = ((a.current + 50) / 50).clamp(0.0, 1.0)); // dBFS -50..0 → 0..1
    });
    setState(() {
      _phase = Phase.recording;
      _elapsed = Duration.zero;
      _marcas.clear();
      _error = null;
      _pending = null;
    });
  }

  void _star() {
    if (_started == null) return;
    final sec = DateTime.now().difference(_started!).inMilliseconds / 1000;
    setState(() => _marcas.add(sec));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('⭐ Marcado en ${_fmt(Duration(milliseconds: (sec * 1000).round()))}'),
      duration: const Duration(seconds: 1),
    ));
  }

  Future<void> _stop() async {
    if (_phase != Phase.recording) return;
    _clock?.cancel();
    await _ampSub?.cancel();
    final path = await _recorder.stop();
    await RecordingService.stop();
    setState(() => _level = 0);
    if (path == null) {
      setState(() => _phase = Phase.idle);
      _showError('No se pudo guardar la grabación.');
      return;
    }
    await _transcribe(_Take(File(path), _elapsed, _title.text, _materia, List.of(_marcas)));
  }

  // ---------- Transcripción ----------

  /// Barra estimada: rápido hasta 70 % a mitad del tiempo estimado, luego cada vez más lento hasta 99 %.
  void _startProgress(Duration audio) {
    const overhead = 2.0;
    final estimate = overhead + audio.inMilliseconds / 1000 * _s.ratio;
    final t0 = DateTime.now();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final t = DateTime.now().difference(t0).inMilliseconds / 1000 / estimate;
      final p = t < .5 ? 70 * t / .5 : 70 + 29 * (1 - math.exp(-(t - .5) * 2.5));
      setState(() => _progress = math.max(_progress, p / 100));
    });
  }

  Future<void> _transcribe(_Take take) async {
    setState(() {
      _phase = Phase.transcribing;
      _progress = 0;
      _error = null;
    });
    _startProgress(take.duration);
    final t0 = DateTime.now();
    try {
      final api = Api(_s.server, apiKey: _s.apiKey);
      final note = await api.transcribe(
        take.audio,
        title: take.title,
        materia: take.materia?.nombre ?? '',
        vocabulario: take.materia?.vocabulario ?? '',
        marcas: take.marcas,
      );
      if (!await _ensureStorage()) throw ApiException('Sin carpeta para guardar la nota.');
      final file = await Storage.saveNote(await Storage.notesDir(_s, take.materia), note.name, note.markdown);

      // Aprende la velocidad real del server para la próxima barra
      final secs = take.duration.inMilliseconds / 1000;
      if (secs > 0) {
        final real = math.max(.01, (DateTime.now().difference(t0).inMilliseconds / 1000 - 2) / secs);
        _s.ratio = _s.ratio * .5 + real * .5;
      }
      if (_s.keepAudio) {
        final dest = '${(await Storage.datasetDir(_s)).path}/${note.name.replaceFirst(RegExp(r'\.md$'), '.m4a')}';
        await take.audio.copy(dest);
      }
      await take.audio.delete();
      _progressTimer?.cancel();
      setState(() {
        _progress = 1;
        _phase = Phase.idle;
        _pending = null;
        _title.clear();
      });
      await _loadNotes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Guardado: ${file.uri.pathSegments.last}'),
          action: SnackBarAction(label: 'Ver', onPressed: () => _open(file)),
        ));
      }
    } on Exception catch (e) {
      _progressTimer?.cancel();
      setState(() {
        _phase = Phase.idle;
        _pending = take; // el audio queda guardado para reintentar
      });
      _showError('$e');
    }
  }

  void _open(File f) => Navigator.push(context, MaterialPageRoute(builder: (_) => NoteScreen(file: f)));

  Future<void> _openSettings() async {
    await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => SettingsScreen(settings: _s)));
    setState(_restoreMateria); // pudo cambiar la lista de materias
    _loadNotes();
  }

  // ---------- UI ----------

  String _fmt(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  String _carpetaDe(File f) {
    final parts = f.uri.pathSegments;
    return parts.length > 1 ? parts[parts.length - 2] : '';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final recording = _phase == Phase.recording;
    final busy = _phase == Phase.transcribing;
    final materias = _s.materias;

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          ClipOval(child: Image.asset('assets/icon.png', width: 32, height: 32)),
          const SizedBox(width: 10),
          const Text('Amanuense'),
        ]),
        actions: [
          IconButton(
            tooltip: 'Configuración',
            icon: const Icon(Icons.settings),
            onPressed: recording || busy ? null : _openSettings,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadNotes,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const AmanuenseBanner(),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: _materia?.nombre ?? '',
                decoration: const InputDecoration(labelText: 'Materia', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Sin materia (carpeta Amanuense)')),
                  for (final m in materias) DropdownMenuItem(value: m.nombre, child: Text(m.nombre)),
                ],
                onChanged: recording || busy
                    ? null
                    : (v) {
                        setState(() => _materia = materias.where((m) => m.nombre == v).firstOrNull);
                        _s.lastMateria = _materia?.nombre;
                      },
              ),
              if (materias.isEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: recording || busy ? null : _openSettings,
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar materias en Configuración'),
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                enabled: !busy,
                decoration: const InputDecoration(
                  labelText: 'Título (opcional)',
                  hintText: 'Unidad 2 - Requisitos',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 28),

              // Grabar / Detener, y ⭐ al lado mientras graba
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (recording) const SizedBox(width: 72),
                  SizedBox.square(
                    dimension: 140,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        shape: const CircleBorder(),
                        backgroundColor: recording ? cs.error : cs.primary,
                      ),
                      onPressed: busy ? null : (recording ? _stop : _start),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(recording ? Icons.stop_rounded : Icons.mic, size: 48),
                        Text(recording ? 'Detener' : 'Grabar'),
                      ]),
                    ),
                  ),
                  if (recording) ...[
                    const SizedBox(width: 16),
                    SizedBox.square(
                      dimension: 56,
                      child: FilledButton.tonal(
                        style: FilledButton.styleFrom(shape: const CircleBorder(), padding: EdgeInsets.zero),
                        onPressed: _star,
                        child: const Text('⭐', style: TextStyle(fontSize: 26)),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              if (recording) ...[
                Center(
                  child: Text(_fmt(_elapsed),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          )),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: _level, color: cs.error, minHeight: 4),
                if (_marcas.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final m in _marcas)
                      Chip(
                        label: Text('⭐ ${_fmt(Duration(milliseconds: (m * 1000).round()))}'),
                        visualDensity: VisualDensity.compact,
                      ),
                  ]),
                ],
                if (RecordingService.supported) ...[
                  const SizedBox(height: 8),
                  Text('Puedes apagar la pantalla: sigue grabando. ⭐ y ⏹ también están en la notificación.',
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                ],
              ],

              if (busy) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(value: _progress, minHeight: 10),
                ),
                const SizedBox(height: 6),
                Row(children: [
                  const Expanded(child: Text('Transcribiendo…')),
                  Text('${(_progress * 100).floor()}%'),
                ]),
              ],

              if (_error != null) ...[
                const SizedBox(height: 12),
                Card(
                  color: cs.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('❌ $_error', style: TextStyle(color: cs.onErrorContainer)),
                      if (_pending != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _transcribe(_pending!),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                          ),
                        ),
                    ]),
                  ),
                ),
              ],

              const SizedBox(height: 28),
              Text('Notas guardadas', style: Theme.of(context).textTheme.titleMedium),
              const Divider(),
              if (_notes.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Todavía no hay notas.'),
                ),
              for (final f in _notes)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.description_outlined),
                  title: Text(f.uri.pathSegments.last, overflow: TextOverflow.ellipsis),
                  subtitle: Text(_carpetaDe(f)),
                  onTap: () => _open(f),
                ),
              const SizedBox(height: 24),
              const Align(alignment: Alignment.centerRight, child: Firma()),
            ],
          ),
        ),
      ),
    );
  }
}
