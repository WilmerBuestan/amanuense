// Servicio en primer plano (Android): notificación fija mientras graba, para que Android
// no corte la grabación con la pantalla apagada. Botones ⭐ Marcar y ⏹ Detener en la notificación.
import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class RecordingService {
  static bool get supported => Platform.isAndroid;

  static void init() {
    if (!supported) return;
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'amanuense_grabacion',
        channelName: 'Grabación',
        channelDescription: 'Aparece mientras Amanuense está grabando.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000),
        allowWakeLock: true, // la CPU sigue con la pantalla apagada
        allowWifiLock: true,
      ),
    );
  }

  /// Permisos: notificaciones (Android 13+) y sin optimización de batería.
  static Future<void> requestPermissions() async {
    if (!supported) return;
    if (await FlutterForegroundTask.checkNotificationPermission() != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
  }

  static Future<void> start(String titulo) async {
    if (!supported) return;
    await FlutterForegroundTask.saveData(key: 'titulo', value: titulo);
    await FlutterForegroundTask.saveData(key: 'inicio', value: DateTime.now().millisecondsSinceEpoch);
    await FlutterForegroundTask.startService(
      serviceId: 701,
      serviceTypes: [ForegroundServiceTypes.microphone],
      notificationTitle: '🎙️ Amanuense grabando',
      notificationText: titulo,
      notificationButtons: const [
        NotificationButton(id: 'star', text: '⭐ Marcar'),
        NotificationButton(id: 'stop', text: '⏹ Detener'),
      ],
      callback: _startCallback,
    );
  }

  static Future<void> stop() async {
    if (!supported) return;
    await FlutterForegroundTask.stopService();
  }

  static void listen(void Function(Object data) onData) {
    if (supported) FlutterForegroundTask.addTaskDataCallback(onData);
  }

  static void unlisten(void Function(Object data) onData) {
    if (supported) FlutterForegroundTask.removeTaskDataCallback(onData);
  }
}

@pragma('vm:entry-point')
void _startCallback() => FlutterForegroundTask.setTaskHandler(_GrabacionHandler());

class _GrabacionHandler extends TaskHandler {
  int _inicio = 0;
  String _titulo = '';
  int _estrellas = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _inicio = await FlutterForegroundTask.getData<int>(key: 'inicio') ?? timestamp.millisecondsSinceEpoch;
    _titulo = await FlutterForegroundTask.getData<String>(key: 'titulo') ?? '';
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    final d = Duration(milliseconds: timestamp.millisecondsSinceEpoch - _inicio);
    String two(int n) => n.toString().padLeft(2, '0');
    final t = d.inHours > 0
        ? '${d.inHours}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}'
        : '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
    FlutterForegroundTask.updateService(
      notificationText: [t, if (_titulo.isNotEmpty) _titulo, if (_estrellas > 0) '⭐ $_estrellas'].join(' · '),
    );
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'star') _estrellas++;
    FlutterForegroundTask.sendDataToMain(id);
  }

  @override
  void onNotificationPressed() => FlutterForegroundTask.launchApp();

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}
