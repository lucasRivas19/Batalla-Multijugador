// lib/services/socket_service.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService with ChangeNotifier {
  IO.Socket? socket;
  bool conectado = false;
  bool intentandoReconectar = false;

  String log = "";

  // Estado del juego
  Map<String, dynamic> estado = {
    "vidaA": 100,
    "vidaB": 100,
    "energiaA": 100,
    "energiaB": 100,
    "turno": 1,
  };

  // Datos para reconectar
  String? _ultimoJugador;
  String? _ultimaRoomId;

  // Timer de turno (debe coincidir con el servidor)
  final int turnDurationMs = 10000;
  int segundosRestantes = 0;
  Timer? _turnTimer;

  // ======================
  // Conexión
  // ======================
  void conectar(String jugador, String roomId) {
    _ultimoJugador = jugador;
    _ultimaRoomId = roomId;

    // Si ya hay un socket, lo cerramos antes de abrir otro
    socket?.dispose();

    socket = IO.io(
      'http://10.0.2.2:3000',
      <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
      },
    );

    socket!.onConnect((_) {
      conectado = true;
      intentandoReconectar = false;
      log += "🟢 Conectado al servidor como $jugador en sala $roomId\n";

      // Unirse (o re-unirse) a la partida
      socket!.emit("unirse_partida", {"roomId": roomId, "jugador": jugador});

      notifyListeners();
    });

    socket!.onDisconnect((_) {
      conectado = false;
      intentandoReconectar = true;
      _detenerTurnTimer();
      log += "🔴 Desconectado del servidor. Podés intentar reconectar.\n";
      notifyListeners();
    });

    // Estado completo de la partida (para join / reconexión)
    socket!.on("estado_partida", (data) {
      estado = Map<String, dynamic>.from(data["estado"]);
      log += "📦 Estado de partida sincronizado (turno ${estado["turno"]}).\n";
      _iniciarTurnTimer();
      notifyListeners();
    });

    // Resultado de un turno
    socket!.on("resultado_turno", (data) {
      estado = Map<String, dynamic>.from(data["estado"]);

      log += "\n🎯 Resultado turno ${data["turno"]}:\n";
      if (data["log"] is List) {
        for (var linea in data["log"]) {
          log += "   • $linea\n";
        }
      }

      _iniciarTurnTimer(); // arranca el contador para el siguiente turno
      notifyListeners();
    });

    socket!.connect();
  }

  // Reconexión manual reutilizando último jugador / room
  void reconectar() {
    if (_ultimoJugador != null && _ultimaRoomId != null) {
      log += "♻️ Intentando reconectar como $_ultimoJugador en sala $_ultimaRoomId...\n";
      notifyListeners();
      conectar(_ultimoJugador!, _ultimaRoomId!);
    }
  }

  // ======================
  // Acciones de juego
  // ======================
  void enviarAccion(String roomId, String jugador, String accion) {
    if (!conectado || socket == null) return;

    socket!.emit("accion", {
      "roomId": roomId,
      "jugador": jugador,
      "accion": accion,
    });

    log += "⚔️ $jugador elige acción: $accion\n";
    notifyListeners();
  }

  // ======================
  // Timer de turno
  // ======================
  void _iniciarTurnTimer() {
    _detenerTurnTimer();
    segundosRestantes = (turnDurationMs / 1000).round();

    _turnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      segundosRestantes--;
      if (segundosRestantes <= 0) {
        segundosRestantes = 0;
        _detenerTurnTimer();
      }
      notifyListeners();
    });

    notifyListeners();
  }

  void _detenerTurnTimer() {
    _turnTimer?.cancel();
    _turnTimer = null;
    notifyListeners();
  }

  void desconectar() {
    socket?.disconnect();
    conectado = false;
    intentandoReconectar = false;
    _detenerTurnTimer();
    notifyListeners();
  }
}
