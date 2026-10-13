// Pantalla principal: materia → Grabar / ⭐ / Detener → transcribir → guardar .md en la bóveda.
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';

import '../api.dart';
import '../branding.dart';
import '../note_meta.dart';
import '../recording_service.dart';
import '../server_monitor.dart';
import '../settings.dart';
import '../storage.dart';
import '../theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/common.dart';
import '../widgets/record_button.dart';
import '../widgets/wave_meter.dart';
import 'about_screen.dart';
import 'materias_screen.dart';
import 'note.dart';
import 'notes_screen.dart';
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
  late final _monitor = ServerMonitor(widget.settings);

  Phase _phase = Phase.idle;
  DateTime? _started;
  Duration _elapsed = Duration.zero;
  double _level = 0; // 0–1, nivel del micrófono
  final List<double> _levels = []; // historial para la onda
  double _progress = 0;
  String? _error;
  _Take? _pending; // grabación que falló, para reintentar
  NoteMeta? _lastSaved;
  List<NoteMeta> _recent = [];
  Materia? _materia;
  final List<double> _marcas = []; // segundos marcados con ⭐

  Timer? _clock;
  Timer? _progressTimer;
  StreamSubscription<Amplitude>? _ampSub;

  Settings get _s => widget.settings;
  bool get _recording => _phase == Phase.recording;
  bool get _busy => _phase == Phase.transcribing;

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
    _monitor.dispose();
    super.dispose();
  }

  void _restoreMateria() {
    final name = _s.lastMateria;
    _materia = _s.materias.where((m) => m.nombre == name).firstOrNull;
  }

  /// Botones de la notificación: ⭐ Marcar / ⏹ Detener
  void _onServiceData(Object data) {
    if (!_recording) return;
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
    final files = await Storage.listNotes(_s);
    final recent = await NoteMeta.readAll(files.take(3).toList());
    if (mounted) setState(() => _recent = recent);
  }

  void _showError(String msg) {
    if (mounted) setState(() => _error = msg);
  }

  // ---------- Navegación ----------

  Future<void> _go(AppSection s) async {
    switch (s) {
      case AppSection.grabar:
        return;
      case AppSection.notas:
        await Navigator.push(context, slideRoute(NotesScreen(settings: _s)));
      case AppSection.materias:
        await Navigator.push(context, slideRoute(MateriasScreen(settings: _s)));
      case AppSection.ajustes:
        await Navigator.push(context, slideRoute(SettingsScreen(settings: _s)));
        _monitor.check();
      case AppSection.acerca:
        await Navigator.push(context, slideRoute(const AboutScreen()));
    }
    setState(_restoreMateria); // pudo cambiar la lista de materias
    _loadNotes();
  }

  void _open(File f) => Navigator.push(context, slideRoute(NoteScreen(file: f)));

  /// Salir: si está grabando, pregunta qué hacer con la grabación.
  Future<void> _exit() async {
    if (_busy) {
      _toast('Espera a que termine la transcripción');
      return;
    }
    if (_recording) {
      final choice = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.mic_rounded),
          title: const Text('Estás grabando'),
          content: const Text('¿Qué hacemos con la grabación antes de salir?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Seguir grabando')),
            FilledButton(onPressed: () => Navigator.pop(c, 'save'), child: const Text('Guardar y salir')),
          ],
        ),
      );
      if (choice != 'save') return;
      await _stop();
    }
    await RecordingService.stop();
    if (Platform.isAndroid) {
      await SystemNavigator.pop();
    } else {
      exit(0);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
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
    await RecordingService.start(
      [_materia?.nombre, _title.text.trim()].whereType<String>().where((x) => x.isNotEmpty).join(' · '),
    );
    // 16 kHz mono: es lo que usa Whisper, archivos livianos (~30 MB por hora)
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000, numChannels: 1, bitRate: 64000),
      path: path,
    );
    _started = DateTime.now();
    _clock = Timer.periodic(const Duration(milliseconds: 250), (_) {
      setState(() => _elapsed = DateTime.now().difference(_started!));
    });
    _ampSub = _recorder.onAmplitudeChanged(const Duration(milliseconds: 90)).listen((a) {
      setState(() {
        _level = ((a.current + 50) / 50).clamp(0.0, 1.0); // dBFS -50..0 → 0..1
        _levels.add(_level);
        if (_levels.length > 120) _levels.removeAt(0);
      });
    });
    setState(() {
      _phase = Phase.recording;
      _elapsed = Duration.zero;
      _levels.clear();
      _marcas.clear();
      _error = null;
      _pending = null;
      _lastSaved = null;
    });
  }

  void _star() {
    if (_started == null) return;
    HapticFeedback.lightImpact();
    final sec = DateTime.now().difference(_started!).inMilliseconds / 1000;
    setState(() => _marcas.add(sec));
    _toast('⭐ Marcado en ${_fmt(Duration(milliseconds: (sec * 1000).round()))}');
  }

  Future<void> _stop() async {
    if (!_recording) return;
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
      HapticFeedback.mediumImpact();
      final meta = await NoteMeta.read(file);
      setState(() {
        _progress = 1;
        _phase = Phase.idle;
        _pending = null;
        _lastSaved = meta;
        _title.clear();
      });
      await _loadNotes();
    } on Exception catch (e) {
      _progressTimer?.cancel();
      setState(() {
        _phase = Phase.idle;
        _pending = take; // el audio queda guardado para reintentar
      });
      _showError('$e');
    }
  }

  // ---------- UI ----------

  String _fmt(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  Widget _materiaChips() {
    final materias = _s.materias;
    final locked = _recording || _busy;
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: const Icon(Icons.inbox_rounded, size: 18),
              label: const Text('General'),
              selected: _materia == null,
              onSelected: locked
                  ? null
                  : (_) {
                      setState(() => _materia = null);
                      _s.lastMateria = null;
                    },
            ),
          ),
          for (final m in materias)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: const Icon(Icons.school_rounded, size: 18),
                label: Text(m.nombre),
                selected: _materia?.nombre == m.nombre,
                onSelected: locked
                    ? null
                    : (_) {
                        setState(() => _materia = m);
                        _s.lastMateria = m.nombre;
                      },
              ),
            ),
          ActionChip(
            avatar: const Icon(Icons.add_rounded, size: 18),
            label: Text(materias.isEmpty ? 'Agregar materia' : 'Materia'),
            onPressed: locked ? null : () => _go(AppSection.materias),
          ),
        ],
      ),
    );
  }

  Widget _statusArea(ColorScheme cs, TextTheme tt) {
    // Un solo bloque que cambia con animación según el estado
    final Widget child;
    if (_recording) {
      child = Column(key: const ValueKey('rec'), children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _RecDot(color: cs.error),
          const SizedBox(width: 8),
          Text(
            _fmt(_elapsed),
            style: tt.displaySmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ]),
        const SizedBox(height: 8),
        WaveMeter(levels: _levels),
        const SizedBox(height: 14),
        _StarButton(count: _marcas.length, onTap: _star),
        if (_marcas.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
            for (final m in _marcas)
              Chip(
                label: Text('⭐ ${_fmt(Duration(milliseconds: (m * 1000).round()))}'),
                visualDensity: VisualDensity.compact,
                backgroundColor: Brand.goldSoft,
                side: BorderSide.none,
              ),
          ]),
        ],
        if (RecordingService.supported) ...[
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.screen_lock_portrait_rounded, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Flexible(
              child: Text('Puedes apagar la pantalla. ⭐ y ⏹ están en la notificación.',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
            ),
          ]),
        ],
      ]);
    } else if (_busy) {
      final stage = _progress < .12 ? 'Enviando audio…' : 'Transcribiendo…';
      child = Card(
        key: const ValueKey('busy'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: cs.primary)),
              const SizedBox(width: 12),
              Expanded(child: Text(stage, style: tt.titleSmall)),
              Text('${(_progress * 100).floor()}%',
                  style: tt.titleSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
            ]),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: _progress),
                duration: const Duration(milliseconds: 250),
                builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 10),
              ),
            ),
            const SizedBox(height: 8),
            Text('Tu server está escribiendo la nota. No cierres la app.',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
          ]),
        ),
      );
    } else if (_error != null) {
      child = Card(
        key: const ValueKey('error'),
        color: cs.errorContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.error_outline_rounded, color: cs.onErrorContainer),
              const SizedBox(width: 10),
              Expanded(child: Text(_error!, style: TextStyle(color: cs.onErrorContainer))),
            ]),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => setState(() => _error = null), child: const Text('Cerrar')),
              if (_pending != null)
                FilledButton.icon(
                  onPressed: () => _transcribe(_pending!),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                ),
            ]),
          ]),
        ),
      );
    } else if (_lastSaved != null) {
      child = Card(
        key: ValueKey('ok${_lastSaved!.name}'),
        color: cs.primaryContainer,
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          leading: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Icon(Icons.check_circle_rounded, color: cs.primary, size: 32),
          ),
          title: const Text('Nota guardada'),
          subtitle: Text(_lastSaved!.titulo, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: FilledButton.tonal(onPressed: () => _open(_lastSaved!.file), child: const Text('Ver')),
        ),
      );
    } else {
      child = Padding(
        key: const ValueKey('idle'),
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          'Toca el botón para empezar.\nMarca con ⭐ lo importante mientras grabas.',
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (c, a) => FadeTransition(
        opacity: a,
        child: SizeTransition(sizeFactor: a, alignment: Alignment.topCenter, child: c),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return PopScope(
      canPop: !_recording && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _toast(_recording ? 'Grabando: usa Detener o el menú → Salir' : 'Espera a que termine');
      },
      child: Scaffold(
        drawer: AppDrawer(monitor: _monitor, onSelect: _go, onExit: _exit),
        appBar: AppBar(
          title: Row(children: [
            Hero(tag: 'logo', child: ClipOval(child: Image.asset('assets/icon.png', width: 34, height: 34))),
            const SizedBox(width: 10),
            const Text('Amanuense', style: TextStyle(fontWeight: FontWeight.w700)),
          ]),
          actions: [ServerPill(monitor: _monitor, compact: true), const SizedBox(width: 4)],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              await _monitor.check();
              await _loadNotes();
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                AnimatedOpacity(
                  opacity: _recording ? .35 : 1,
                  duration: const Duration(milliseconds: 300),
                  child: const AmanuenseBanner(),
                ),
                const SizedBox(height: 16),
                _materiaChips(),
                const SizedBox(height: 10),
                TextField(
                  controller: _title,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.edit_note_rounded),
                    hintText: 'Título (opcional) · Unidad 2 - Requisitos',
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: RecordButton(
                    recording: _recording,
                    enabled: !_busy,
                    level: _level,
                    onTap: _recording ? _stop : _start,
                  ),
                ),
                _statusArea(cs, tt),
                const SizedBox(height: 28),
                Row(children: [
                  Text('Recientes', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _go(AppSection.notas),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text('Ver todas'),
                    iconAlignment: IconAlignment.end,
                  ),
                ]),
                const SizedBox(height: 6),
                if (_recent.isEmpty)
                  const EmptyState(
                    icon: Icons.description_outlined,
                    title: 'Sin notas todavía',
                    text: 'Tus transcripciones aparecerán aquí.',
                  ),
                for (final (i, m) in _recent.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FadeSlideIn(delay: i, child: NoteCard(meta: m, onTap: () => _open(m.file))),
                  ),
                const SizedBox(height: 20),
                const Align(alignment: Alignment.centerRight, child: Firma()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Punto rojo que parpadea mientras graba.
class _RecDot extends StatefulWidget {
  const _RecDot({required this.color});
  final Color color;

  @override
  State<_RecDot> createState() => _RecDotState();
}

class _RecDotState extends State<_RecDot> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: .25, end: 1.0).animate(_c),
        child: Container(width: 12, height: 12, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
      );
}

/// Botón ⭐ que rebota al tocarlo y muestra cuántas marcas van.
class _StarButton extends StatelessWidget {
  const _StarButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(count), // reinicia el rebote en cada marca
      tween: Tween(begin: count == 0 ? 1 : 1.35, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.elasticOut,
      builder: (_, s, child) => Transform.scale(scale: s, child: child),
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: Brand.gold,
          foregroundColor: Colors.black87,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        ),
        onPressed: onTap,
        icon: const Icon(Icons.star_rounded),
        label: Text(count == 0 ? 'Marcar importante' : 'Marcar · $count'),
      ),
    );
  }
}
