import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService extends ChangeNotifier {
  IO.Socket? socket;

  bool socketAbierto = false; // socket TCP abierto
  bool conectado = false;     // aceptado en la partida
  bool intentandoReconectar = false;

  String log = '';

  int vidaA = 100;
  int vidaB = 100;
  int turno = 1;

  int tiempoRestanteMs = 0;
  Timer? _turnTimer;

  String? _ultimoJugador;
  String? _ultimaRoomId;

  String? ultimoErrorUnirse;

  // Para animaciones de muñequitos
  String? ultimaAccionA;
  String? ultimaAccionB;

  // Servidor local (emuladores Android)
  final String baseUrl = 'http://10.0.2.2:3000';

  /// Sala actual (la última a la que se intentó unir)
  String? get roomIdActual => _ultimaRoomId;

  /// Calcula la próxima sala: sala1 -> sala2, sala2 -> sala3, etc.
  String _siguienteSala(String actual) {
    final reg = RegExp(r'^sala(\d+)$');
    final m = reg.firstMatch(actual);
    if (m != null) {
      final n = int.parse(m.group(1)!);
      return 'sala${n + 1}';
    }
    // Si no matchea el patrón, empezamos desde sala2
    return 'sala2';
  }

  void conectar(String jugador, String roomId) {
    _ultimoJugador = jugador;
    _ultimaRoomId = roomId;
    ultimoErrorUnirse = null;

    socket?.dispose();
    socket = IO.io(
      baseUrl,
      <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
      },
    );

    intentandoReconectar = true;
    conectado = false;
    socketAbierto = false;
    notifyListeners();

    socket!.onConnect((_) {
      socketAbierto = true;
      intentandoReconectar = false;
      log +=
          "🟢 Socket conectado. Solicitando unirse como $jugador en sala $roomId\n";

      socket!.emit("unirse_partida", {"roomId": roomId, "jugador": jugador});
      notifyListeners();
    });

    socket!.on("estado_partida", (data) {
      // Aceptado en la partida
      conectado = true;
      log += "✅ Aceptado en la partida (sala ${_ultimaRoomId}).\n";
      _procesarEstadoPartida(data);
    });

    socket!.on("resultado_turno", (data) {
      _procesarResultadoTurno(data);
    });

    socket!.on("error_unirse", (data) {
      intentandoReconectar = false;
      socketAbierto = false;
      conectado = false;
      _detenerTurnTimer();

      String? tipo;
      String? mensaje;
      if (data is Map) {
        tipo = data["tipo"] as String?;
        mensaje = data["mensaje"] as String?;
      }

      // 👉 Caso especial: sala llena -> probamos en la siguiente sala
      if (tipo == "sala_llena" && _ultimoJugador != null) {
        final actual = _ultimaRoomId ?? "sala1";
        final nuevaSala = _siguienteSala(actual);
        log +=
            "ℹ️ La sala $actual está llena. Intentando unirse automáticamente a $nuevaSala...\n";

        // No seteamos ultimoErrorUnirse para no mostrar SnackBar
        socket?.disconnect();
        socket?.dispose();
        socket = null;

        notifyListeners();

        // Reintentamos en la sala siguiente
        conectar(_ultimoJugador!, nuevaSala);
        return;
      }

      // Otros errores (nombre en uso, etc.) -> se muestran al usuario
      ultimoErrorUnirse =
          mensaje ?? "No se pudo unir a la partida. Intente nuevamente.";
      log += "⚠️ Error al unirse a la partida: $ultimoErrorUnirse\n";

      socket?.disconnect();
      socket?.dispose();
      socket = null;

      notifyListeners();
    });

    socket!.onDisconnect((_) {
      log += "🔴 Socket desconectado.\n";
      socketAbierto = false;
      conectado = false;
      intentandoReconectar = false;
      _detenerTurnTimer();
      notifyListeners();
    });

    socket!.onError((err) {
      log += "⚠️ Error de socket: $err\n";
      notifyListeners();
    });

    socket!.connect();
  }

  void _procesarEstadoPartida(dynamic data) {
    try {
      final estado = data["estado"] ?? {};
      vidaA = (estado["vidaA"] ?? vidaA) as int;
      vidaB = (estado["vidaB"] ?? vidaB) as int;
      turno = (estado["turno"] ?? turno) as int;

      // Estado inicial: limpiamos acciones visuales
      ultimaAccionA = null;
      ultimaAccionB = null;

      final logMsg = data["log"];
      if (logMsg is String && logMsg.isNotEmpty) {
        log += "ℹ️ $logMsg\n";
      }

      final dur = data["turnDurationMs"] ?? 0;
      if (dur is int && dur > 0) {
        _iniciarTurnTimer(dur);
      }

      notifyListeners();
    } catch (e) {
      log += "⚠️ Error procesando estado_partida: $e\n";
      notifyListeners();
    }
  }

  void _procesarResultadoTurno(dynamic data) {
    try {
      final estado = data["estado"] ?? {};
      vidaA = (estado["vidaA"] ?? vidaA) as int;
      vidaB = (estado["vidaB"] ?? vidaB) as int;
      turno = (estado["turno"] ?? turno) as int;

      // Acciones para animación de muñequitos
      final acciones = data["acciones"];
      if (acciones is Map) {
        final jugAData = acciones["jugadorA"];
        final jugBData = acciones["jugadorB"];

        if (jugAData is Map && jugAData["accion"] is String) {
          ultimaAccionA = jugAData["accion"] as String;
        }
        if (jugBData is Map && jugBData["accion"] is String) {
          ultimaAccionB = jugBData["accion"] as String;
        }
      }

      final logMsg = data["log"];
      if (logMsg is String && logMsg.isNotEmpty) {
        log += "🧾 Resultado turno:\n$logMsg\n";
      }

      final dur = data["turnDurationMs"] ?? 0;
      if (dur is int && dur > 0) {
        _iniciarTurnTimer(dur);
      }

      notifyListeners();
    } catch (e) {
      log += "⚠️ Error procesando resultado_turno: $e\n";
      notifyListeners();
    }
  }

  void enviarAccion(String roomId, String jugador, String accion) {
    if (!conectado || socket == null) return;

    socket!.emit("accion", {
      "roomId": roomId,
      "jugador": jugador,
      "accion": accion,
    });

    log += "📤 $jugador envía acción: $accion (sala $roomId)\n";
    _detenerTurnTimer();
    notifyListeners();
  }

  void _iniciarTurnTimer(int durationMs) {
    _detenerTurnTimer();
    tiempoRestanteMs = durationMs;

    _turnTimer = Timer.periodic(const Duration(milliseconds: 500), (t) {
      tiempoRestanteMs -= 500;
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

  void desconectar() {
    socket?.disconnect();
    socket?.dispose();
    socket = null;
    socketAbierto = false;
    conectado = false;
    intentandoReconectar = false;
    _detenerTurnTimer();
    notifyListeners();
  }

  void reconectar() {
    if (_ultimoJugador != null && _ultimaRoomId != null) {
      conectar(_ultimoJugador!, _ultimaRoomId!);
    }
  }

  void clearError() {
    ultimoErrorUnirse = null;
    notifyListeners();
  }
}
