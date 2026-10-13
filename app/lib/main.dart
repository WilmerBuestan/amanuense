// Amanuense — voz a texto literal en .md. by wilo (Wilmer Buestan)
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'recording_service.dart';
import 'screens/home.dart';
import 'settings.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  RecordingService.init();
  final settings = await Settings.load();
  runApp(AmanuenseApp(settings: settings));
}

class AmanuenseApp extends StatelessWidget {
  const AmanuenseApp({super.key, required this.settings});
  final Settings settings;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Amanuense',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: RecordingService.supported
          ? WithForegroundTask(child: HomeScreen(settings: settings))
          : HomeScreen(settings: settings),
    );
  }
}
