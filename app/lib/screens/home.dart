// Pantalla principal: Grabar / Detener → transcribir → guardar .md → lista de notas.
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../api.dart';
import '../branding.dart';
import '../settings.dart';
import '../storage.dart';
import 'note.dart';
import 'settings_screen.dart';

enum Phase { idle, recording, transcribing }

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
  Duration _elapsed = Duration.zero;
  double _level = 0; // 0–1, nivel del micrófono
  double _progress = 0;
  String? _error;
  File? _pendingAudio; // audio que falló, para reintentar
  Duration _pendingDuration = Duration.zero;
  List<File> _notes = [];

  Timer? _clock;
  Timer? _progressTimer;
  StreamSubscription<Amplitude>? _ampSub;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _clock?.cancel();
    _progressTimer?.cancel();
    _ampSub?.cancel();
    _recorder.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<Directory?> _notesDir() async {
    if (!await Storage.ensureAccess()) {
      _showError('Sin permiso para guardar en ${await Storage.defaultFolder()}. '
          'Actívalo en Ajustes → Apps → Amanuense → Acceso a todos los archivos.');
      return null;
    }
    return Storage.notesDir(widget.settings.folder);
  }

  Future<void> _loadNotes() async {
    final dir = await _notesDir();
    if (dir == null) return;
    final notes = await Storage.listNotes(dir);
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
    // 16 kHz mono: es lo que usa Whisper, archivos livianos
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000, numChannels: 1, bitRate: 64000),
      path: path,
    );
    final started = DateTime.now();
    _clock = Timer.periodic(const Duration(milliseconds: 250), (_) {
      setState(() => _elapsed = DateTime.now().difference(started));
    });
    _ampSub = _recorder.onAmplitudeChanged(const Duration(milliseconds: 150)).listen((a) {
      setState(() => _level = ((a.current + 50) / 50).clamp(0.0, 1.0)); // dBFS -50..0 → 0..1
    });
    setState(() {
      _phase = Phase.recording;
      _elapsed = Duration.zero;
      _error = null;
      _pendingAudio = null;
    });
  }

  Future<void> _stop() async {
    _clock?.cancel();
    await _ampSub?.cancel();
    final path = await _recorder.stop();
    setState(() => _level = 0);
    if (path == null) {
      setState(() => _phase = Phase.idle);
      _showError('No se pudo guardar la grabación.');
      return;
    }
    await _transcribe(File(path), _elapsed);
  }

  // ---------- Transcripción ----------

  /// Barra estimada: rápido hasta 70 % a mitad del tiempo estimado, luego cada vez más lento hasta 99 %.
  void _startProgress(Duration audio) {
    const overhead = 2.0;
    final estimate = overhead + audio.inMilliseconds / 1000 * widget.settings.ratio;
    final t0 = DateTime.now();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final t = DateTime.now().difference(t0).inMilliseconds / 1000 / estimate;
      final p = t < .5 ? 70 * t / .5 : 70 + 29 * (1 - math.exp(-(t - .5) * 2.5));
      setState(() => _progress = math.max(_progress, p / 100));
    });
  }

  Future<void> _transcribe(File audio, Duration duration) async {
    setState(() {
      _phase = Phase.transcribing;
      _progress = 0;
      _error = null;
    });
    _startProgress(duration);
    final t0 = DateTime.now();
    try {
      final api = Api(widget.settings.server, apiKey: widget.settings.apiKey);
      final note = await api.transcribe(audio, title: _title.text);
      final dir = await _notesDir();
      if (dir == null) throw ApiException('Sin carpeta para guardar la nota.');
      final file = await Storage.saveNote(dir, note.name, note.markdown);

      // Aprende la velocidad real del server para la próxima barra
      final secs = duration.inMilliseconds / 1000;
      if (secs > 0) {
        final real = math.max(.01, (DateTime.now().difference(t0).inMilliseconds / 1000 - 2) / secs);
        widget.settings.ratio = widget.settings.ratio * .5 + real * .5;
      }
      await audio.delete();
      _progressTimer?.cancel();
      setState(() {
        _progress = 1;
        _phase = Phase.idle;
        _pendingAudio = null;
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
        _pendingAudio = audio; // el audio queda guardado para reintentar
        _pendingDuration = duration;
      });
      _showError('$e');
    }
  }

  void _open(File f) => Navigator.push(context, MaterialPageRoute(builder: (_) => NoteScreen(file: f)));

  Future<void> _openSettings() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => SettingsScreen(settings: widget.settings)),
    );
    if (changed == true) _loadNotes();
  }

  // ---------- UI ----------

  String _fmt(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final recording = _phase == Phase.recording;
    final busy = _phase == Phase.transcribing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🎙️ Amanuense'),
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
              TextField(
                controller: _title,
                enabled: !busy,
                decoration: const InputDecoration(
                  labelText: 'Título (opcional)',
                  hintText: 'Clase SOA - unidad 2',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 28),

              // Botón grande grabar / detener
              Center(
                child: SizedBox.square(
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
                      if (_pendingAudio != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _transcribe(_pendingAudio!, _pendingDuration),
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
