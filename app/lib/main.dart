// Amanuense — voz a texto literal en .md. by wilo (Wilmer Buestan)
import 'package:flutter/material.dart';

import 'screens/home.dart';
import 'settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await Settings.load();
  runApp(AmanuenseApp(settings: settings));
}

class AmanuenseApp extends StatelessWidget {
  const AmanuenseApp({super.key, required this.settings});
  final Settings settings;

  static const _seed = Color(0xFF3D5A3A);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Amanuense',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: _seed, brightness: Brightness.light),
      darkTheme: ThemeData(colorSchemeSeed: _seed, brightness: Brightness.dark),
      home: HomeScreen(settings: settings),
    );
  }
}
