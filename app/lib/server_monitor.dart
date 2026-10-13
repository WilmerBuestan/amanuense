// Revisa cada cierto tiempo si el server responde, para mostrar el punto verde/rojo.
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api.dart';
import 'settings.dart';

enum ServerState { checking, online, loading, offline }

class ServerStatus {
  const ServerStatus(this.state, [this.detail = '', this.auth = false]);
  final ServerState state;
  final String detail; // "small · cpu" o el error
  final bool auth;
}

class ServerMonitor extends ValueNotifier<ServerStatus> {
  ServerMonitor(this.settings) : super(const ServerStatus(ServerState.checking)) {
    check();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => check());
  }

  final Settings settings;
  Timer? _timer;

  Future<void> check() async {
    if (value.state == ServerState.offline) value = const ServerStatus(ServerState.checking);
    try {
      final h = await Api(settings.server).health();
      final detail = '${h['model']} · ${h['device']}';
      value = ServerStatus(h['status'] == 'ok' ? ServerState.online : ServerState.loading, detail, h['auth'] == true);
    } on Exception {
      value = ServerStatus(ServerState.offline, settings.server);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
