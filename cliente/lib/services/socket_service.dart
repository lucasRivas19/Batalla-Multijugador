import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/material.dart';

class SocketService with ChangeNotifier {
  late IO.Socket socket;
  bool conectado = false;
  String log = "";

  // Nuevo estado sincronizado con el servidor
  Map<String, dynamic> estado = {
    "vidaA": 100,
    "vidaB": 100,
    "energiaA": 100,
    "energiaB": 100,
    "turno": 1,
  };

  void conectar(String jugador, String roomId) {
    socket = IO.io('http://10.0.2.2:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    socket.onConnect((_) {
      conectado = true;
      log += "🟢 Conectado al servidor como $jugador\n";
      socket.emit("unirse_partida", roomId);
      notifyListeners();
    });

    socket.onDisconnect((_) {
      conectado = false;
      log += "🔴 Desconectado del servidor\n";
      notifyListeners();
    });

    socket.on("resultado_turno", (data) {
      estado = data["estado"]; // guardamos nuevo estado
      log += "\n🎯 Resultado turno ${estado["turno"]}:\n";
      for (var linea in data['log']) {
        log += "   • $linea\n";
      }
      notifyListeners();
    });
  }

  void enviarAccion(String roomId, String jugador, String accion) {
    socket.emit("accion", {"roomId": roomId, "jugador": jugador, "accion": accion});
    log += "⚔️ $jugador elige acción: $accion\n";
    notifyListeners();
  }

  void desconectar() {
    socket.disconnect();
    conectado = false;
    notifyListeners();
  }
}
