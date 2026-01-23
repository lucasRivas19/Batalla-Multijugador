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

  // para animar los muñequitos
  String? ultimaAccionA;
  String? ultimaAccionB;

  // server local (android emulator)
  final String baseUrl = 'http://10.0.2.2:3000';

  String? get salaActual => _ultimaSala;

  // calcula la próxima sala: sala1 -> sala2 -> sala3...
  String _siguienteSala(String actual) {
    final match = RegExp(r'^sala(\d+)$').firstMatch(actual);
    if (match != null) {
      final n = int.parse(match.group(1)!);
      return 'sala${n + 1}';
    }
    return 'sala2';
  }

  void conectar(String jugador, String sala) {
    _ultimoJugador = jugador;
    _ultimaSala = sala;
    ultimoErrorUnirse = null;

    socket?.dispose();
    socket = IO.io(
      baseUrl,
      {
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

      log += '🟢 Socket conectado. Intentando entrar a $sala como $jugador\n';

      socket!.emit('unirse_partida', {
        'roomId': sala,
        'jugador': jugador,
      });

      notifyListeners();
    });

    socket!.on('estado_partida', (data) {
      conectado = true;
      log += '✅ Unido a la sala $_ultimaSala\n';
      _procesarEstado(data);
    });

    socket!.on('resultado_turno', (data) {
      _procesarResultado(data);
    });

    socket!.on('error_unirse', (data) {
      intentandoReconectar = false;
      socketAbierto = false;
      conectado = false;
      _detenerTimer();

      String? tipo;
      String? mensaje;

      if (data is Map) {
        tipo = data['tipo'];
        mensaje = data['mensaje'];
      }

      // si la sala está llena, probamos automáticamente la siguiente
      if (tipo == 'sala_llena' && _ultimoJugador != null) {
        final actual = _ultimaSala ?? 'sala1';
        final nueva = _siguienteSala(actual);

        log += 'ℹ️ $actual llena. Probando en $nueva...\n';

        socket?.dispose();
        socket = null;
        notifyListeners();

        conectar(_ultimoJugador!, nueva);
        return;
      }

      ultimoErrorUnirse =
          mensaje ?? 'No se pudo unir a la partida.';
      log += '⚠️ Error al unirse: $ultimoErrorUnirse\n';

      socket?.dispose();
      socket = null;
      notifyListeners();
    });

    socket!.onDisconnect((_) {
      log += '🔴 Socket desconectado\n';
      socketAbierto = false;
      conectado = false;
      intentandoReconectar = false;
      _detenerTimer();
      notifyListeners();
    });

    socket!.onError((err) {
      log += '⚠️ Error de socket: $err\n';
      notifyListeners();
    });

    socket!.connect();
  }

  void _procesarEstado(dynamic data) {
    try {
      final estado = data['estado'] ?? {};

      vidaA = estado['vidaA'] ?? vidaA;
      vidaB = estado['vidaB'] ?? vidaB;
      turno = estado['turno'] ?? turno;

      // al arrancar el turno limpiamos animaciones
      ultimaAccionA = null;
      ultimaAccionB = null;

      final msg = data['log'];
      if (msg is String && msg.isNotEmpty) {
        log += 'ℹ️ $msg\n';
      }

      final dur = data['turnDurationMs'];
      if (dur is int && dur > 0) {
        _iniciarTimer(dur);
      }

      notifyListeners();
    } catch (e) {
      log += '⚠️ Error procesando estado: $e\n';
      notifyListeners();
    }
  }

  void _procesarResultado(dynamic data) {
    try {
      final estado = data['estado'] ?? {};

      vidaA = estado['vidaA'] ?? vidaA;
      vidaB = estado['vidaB'] ?? vidaB;
      turno = estado['turno'] ?? turno;

      final acciones = data['acciones'];
      if (acciones is Map) {
        final a = acciones['jugadorA'];
        final b = acciones['jugadorB'];

        if (a is Map && a['accion'] is String) {
          ultimaAccionA = a['accion'];
        }
        if (b is Map && b['accion'] is String) {
          ultimaAccionB = b['accion'];
        }
      }

      final msg = data['log'];
      if (msg is String && msg.isNotEmpty) {
        log += '🧾 Resultado:\n$msg\n';
      }

      final dur = data['turnDurationMs'];
      if (dur is int && dur > 0) {
        _iniciarTimer(dur);
      }

      notifyListeners();
    } catch (e) {
      log += '⚠️ Error procesando resultado: $e\n';
      notifyListeners();
    }
  }

  void enviarAccion(String sala, String jugador, String accion) {
    if (!conectado || socket == null) return;

    socket!.emit('accion', {
      'roomId': sala,
      'jugador': jugador,
      'accion': accion,
    });

    log += '📤 $jugador manda $accion ($sala)\n';
    _detenerTimer();
    notifyListeners();
  }

  void _iniciarTimer(int ms) {
    _detenerTimer();
    tiempoRestanteMs = ms;

    _turnTimer =
        Timer.periodic(const Duration(milliseconds: 500), (t) {
      tiempoRestanteMs -= 500;
      if (tiempoRestanteMs <= 0) {
        tiempoRestanteMs = 0;
        t.cancel();
      }
      notifyListeners();
    });
  }

  void _detenerTimer() {
    _turnTimer?.cancel();
    _turnTimer = null;
    tiempoRestanteMs = 0;
  }

  void desconectar() {
    socket?.dispose();
    socket = null;
    socketAbierto = false;
    conectado = false;
    intentandoReconectar = false;
    _detenerTimer();
    notifyListeners();
  }

  void reconectar() {
    if (_ultimoJugador != null && _ultimaSala != null) {
      conectar(_ultimoJugador!, _ultimaSala!);
    }
  }

  void clearError() {
    ultimoErrorUnirse = null;
    notifyListeners();
  }
}
