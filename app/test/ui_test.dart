// Pruebas de interfaz en tamaño celular: que nada se desborde ni falle al dibujar.
import 'dart:io';

import 'package:amanuense/screens/note.dart';
import 'package:amanuense/server_monitor.dart';
import 'package:amanuense/settings.dart';
import 'package:amanuense/theme.dart';
import 'package:amanuense/widgets/app_drawer.dart';
import 'package:amanuense/widgets/record_button.dart';
import 'package:amanuense/widgets/wave_meter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _nota = '''---
tipo: transcripcion
titulo: "Clase de prueba con un título bastante largo para ver el corte"
creado: 2026-10-13
fecha: 2026-10-13 19:13
duracion: 52:10
materia: "Evolucion"
tags: [amanuense, transcripcion, evolucion]
favoritos: 1
estado: literal
---

# Clase de prueba

📚 [[Evolucion]]

## ⭐ Momentos importantes

- **[00:10]** esto entra en el examen, requisitos funcionales y no funcionales

## Transcripción

⭐ **[00:00]** En requisitos funcionales pueden ser de tipo de autenticación, niveles de autorización.
**[01:02]** Segundo párrafo de la clase.

---
_Transcrito con Amanuense · by wilo (Wilmer Buestan)_
''';

Widget _app(Widget child) => MaterialApp(theme: buildTheme(Brightness.light), home: child);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> phone(WidgetTester t) async {
    t.view.physicalSize = const Size(360, 780);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  testWidgets('Nota con formato: datos, ⭐ y transcripción', (t) async {
    await phone(t);
    final f = File('${Directory.systemTemp.createTempSync('am').path}/2026-10-13_1913_prueba.md')
      ..writeAsStringSync(_nota);
    await t.runAsync(() async {
      await t.pumpWidget(_app(NoteScreen(file: f)));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await t.pumpAndSettle();
    expect(find.text('Evolucion'), findsOneWidget);
    expect(find.text('1 favorito'), findsOneWidget);
    expect(find.text('Momentos importantes'), findsOneWidget);
    expect(find.text('⭐ 00:10'), findsOneWidget);
    expect(find.text('⭐ 00:00'), findsOneWidget);
    // Cambiar a texto .md
    await t.tap(find.byTooltip('Ver texto .md'));
    await t.pumpAndSettle();
    expect(find.textContaining('tipo: transcripcion'), findsOneWidget);
  });

  testWidgets('Botón de grabar y onda de voz', (t) async {
    await phone(t);
    var taps = 0;
    await t.pumpWidget(_app(Scaffold(
      body: Column(children: [
        RecordButton(recording: true, enabled: true, level: .7, onTap: () => taps++),
        WaveMeter(levels: List.generate(80, (i) => (i % 10) / 10)),
      ]),
    )));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('Detener'), findsOneWidget);
    await t.tap(find.text('Detener'));
    await t.pump(const Duration(milliseconds: 200));
    expect(taps, 1);
  });

  testWidgets('Menú hamburguesa con Salir', (t) async {
    await phone(t);
    final monitor = ServerMonitor(await Settings.load());
    AppSection? chosen;
    var exited = false;
    await t.pumpWidget(_app(Scaffold(
      appBar: AppBar(title: const Text('x')),
      drawer: AppDrawer(monitor: monitor, onSelect: (s) => chosen = s, onExit: () => exited = true),
    )));
    Future<void> settle() async {
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
    }

    await t.tap(find.byTooltip('Open navigation menu'));
    await settle();
    expect(find.text('Configuración'), findsOneWidget);
    await t.tap(find.text('Notas'));
    await settle();
    expect(chosen, AppSection.notas);
    await t.tap(find.byTooltip('Open navigation menu'));
    await settle();
    await t.tap(find.text('Salir'));
    await settle();
    expect(exited, isTrue);
    monitor.dispose(); // apaga el chequeo periódico del server
  });
}
