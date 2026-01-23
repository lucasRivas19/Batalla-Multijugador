// lib/services/socket_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService extends ChangeNotifier {
  IO.Socket? socket;

  bool socketAbierto = false;
  bool conectado = false;
  bool intentandoReconectar = false;

  String log = '';

  int vidaA = 100;
  int vidaB = 100;
  int turno = 1;

  int tiempoRestanteMs = 0;
  Timer? _turnTimer;

  String? _ultimoJugador;
  String? _ultimaSala;

  String? ultimoErrorUnirse;

  // Para animar los muñequitos
  String? ultimaAccionA; // "atacar", "defender", "curar", "ninguna"
  String? ultimaAccionB;

  // server local (Android emulator)
  final String baseUrl = 'http://10.0.2.2:3000';

  String? get salaActual => _ultimaSala;
  String? get jugadorActual => _ultimoJugador;

  // ===================
  // Conexión
  // ===================
  void conectar(String jugador, String roomId) {
    _ultimoJugador = jugador;
    _ultimaSala = roomId;

    if (socketAbierto && socket != null) {
      // Ya hay socket: solo unirse a la sala
      _emitUnirse(jugador, roomId);
      return;
    }

    intentandoReconectar = true;
    notifyListeners();

    socket = IO.io(
      baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .disableAutoConnect()
          .build(),
    );

    socketAbierto = true;

    socket!.onConnect((_) {
      intentandoReconectar = false;
      log = _appendLog('🔌 Conectado al servidor.');
      _emitUnirse(jugador, roomId);
      notifyListeners();
    });

    socket!.onDisconnect((_) {
      conectado = false;
      log = _appendLog('🔴 Desconectado del servidor.');
      notifyListeners();
    });

    socket!.on('estado_partida', (data) {
      _handleEstadoPartida(data);
    });

    socket!.on('resultado_turno', (data) {
      _handleResultadoTurno(data);
    });

    socket!.on('error_unirse', (data) {
      final msg = data['mensaje'] ?? 'Error al unirse a la partida.';
      ultimoErrorUnirse = msg;
      log = _appendLog('⚠️ $msg');
      notifyListeners();
    });

    socket!.connect();
  }

  void _emitUnirse(String jugador, String roomId) {
    if (socket == null) return;
    socket!.emit('unirse_partida', {
      'roomId': roomId,
      'jugador': jugador,
    });
  }

  void desconectar() {
    _detenerTurnTimer();
    conectado = false;
    socketAbierto = false;
    intentandoReconectar = false;

    socket?.disconnect();
    socket?.dispose();
    socket = null;

    log = _appendLog('⛔ Conexión cerrada manualmente.');
    notifyListeners();
  }

  // ===================
  // Enviar acción
  // ===================
  void enviarAccion(String roomId, String jugador, String accion) {
    if (socket == null || !socketAbierto) return;
    if (!conectado) return;

    socket!.emit('accion', {
      'roomId': roomId,
      'jugador': jugador,
      'accion': accion,
    });

    log = _appendLog('🎯 $jugador elige acción: $accion');
    notifyListeners();
  }

  // ===================
  // Handlers de eventos
  // ===================
  void _handleEstadoPartida(dynamic data) {
    final estado = data['estado'] ?? {};
    vidaA = (estado['vidaA'] ?? vidaA) as int;
    vidaB = (estado['vidaB'] ?? vidaB) as int;
    turno = (estado['turno'] ?? turno) as int;

    // Reinicio de timer de turno
    final dur = (data['turnDurationMs'] ?? 0) as int;
    _iniciarTurnTimer(dur);

    conectado = true;

    final logMsg = data['log'] ?? 'Estado de partida recibido.';
    log = _appendLog(logMsg);

    // Limpiar última acción para que vuelvan a la posición base
    ultimaAccionA = null;
    ultimaAccionB = null;

    notifyListeners();
  }

  void _handleResultadoTurno(dynamic data) {
    final estado = data['estado'] ?? {};
    vidaA = (estado['vidaA'] ?? vidaA) as int;
    vidaB = (estado['vidaB'] ?? vidaB) as int;
    turno = (estado['turno'] ?? turno) as int;

    // Acciones para animar muñecos
    final acciones = data['acciones'] ?? {};
    final jugA = acciones['jugadorA'] ?? {};
    final jugB = acciones['jugadorB'] ?? {};

    ultimaAccionA = (jugA['accion'] ?? 'ninguna') as String?;
    ultimaAccionB = (jugB['accion'] ?? 'ninguna') as String?;

    final logMsg = data['log'] ?? 'Turno resuelto.';
    log = _appendLog(logMsg);

    // Reiniciar timer de turno
    final dur = (data['turnDurationMs'] ?? 0) as int;
    _iniciarTurnTimer(dur);

    notifyListeners();

    // Opcional: después de un pequeño delay, volver a posición base
    Future.delayed(const Duration(milliseconds: 500), () {
      ultimaAccionA = null;
      ultimaAccionB = null;
      notifyListeners();
    });
  }

  // ===================
  // Timer de turno
  // ===================
  void _iniciarTurnTimer(int durMs) {
    _detenerTurnTimer();
    if (durMs <= 0) {
      tiempoRestanteMs = 0;
      notifyListeners();
      return;
    }

    tiempoRestanteMs = durMs;
    _turnTimer = Timer.periodic(const Duration(milliseconds: 200), (t) {
      tiempoRestanteMs -= 200;
      if (tiempoRestanteMs <= 0) {
        tiempoRestanteMs = 0;
        t.cancel();
      }
      notifyListeners();
    });
  }

  void _detenerTurnTimer() {
    _turnTimer?.cancel();
    _turnTimer = null;
    tiempoRestanteMs = 0;
  }

  // ===================
  // Utils
  // ===================
  String _appendLog(String msg) {
    final now = DateTime.now().toIso8601String().substring(11, 19);
    if (log.isEmpty) return '[$now] $msg';
    return '$log\n[$now] $msg';
  }

  void clearError() {
    ultimoErrorUnirse = null;
    notifyListeners();
  }
}
