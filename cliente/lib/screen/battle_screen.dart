// cliente/lib/screens/battle_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/socket_service.dart';

class BattleScreen extends StatefulWidget {
  const BattleScreen({super.key});

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  final TextEditingController jugadorCtrl =
      TextEditingController(text: "JugadorA");
  final String roomId = "sala1";

  @override
  Widget build(BuildContext context) {
    final socketService = Provider.of<SocketService>(context);

    // Mostrar SnackBar si hubo error al unirse (por ejemplo, nombre en uso)
    if (socketService.ultimoErrorUnirse != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final msg = socketService.ultimoErrorUnirse!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
        socketService.clearError();
      });
    }

    final conectado = socketService.conectado;
    final intentando = socketService.intentandoReconectar;

    final vidaA = socketService.vidaA.toDouble();
    final vidaB = socketService.vidaB.toDouble();
    final tiempoRestante = (socketService.tiempoRestanteMs / 1000).ceil();

    return Scaffold(
      appBar: AppBar(
        title: const Text("⚔️ Batalla Multijugador"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Nombre del jugador
            TextField(
              controller: jugadorCtrl,
              decoration: const InputDecoration(
                labelText: "Nombre del jugador (JugadorA / JugadorB)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            // Conectarse / desconectar
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: intentando
                        ? null
                        : () {
                            FocusScope.of(context).unfocus();
                            final nombre = jugadorCtrl.text.trim();
                            if (nombre.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      "El nombre de jugador no puede estar vacío."),
                                ),
                              );
                              return;
                            }
                            socketService.conectar(nombre, roomId);
                          },
                    child: Text(
                      intentando
                          ? "Conectando..."
                          : (conectado ? "Reconectar" : "Conectarse"),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: socketService.socketAbierto
                      ? socketService.desconectar
                      : null,
                  icon: const Icon(Icons.power_settings_new),
                  tooltip: "Desconectar",
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Estado
            Row(
              children: [
                const Text(
                  "Estado: ",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  conectado ? "✅ En partida" : "⛔ No en partida",
                  style: TextStyle(
                    color: conectado ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),

            if (conectado) ...[
              Text("Sala: $roomId"),
              Text("Turno: ${socketService.turno}"),
              const SizedBox(height: 8),

              if (socketService.tiempoRestanteMs > 0)
                Text("⏳ Tiempo restante para elegir acción: ${tiempoRestante}s"),
              const SizedBox(height: 12),

              // Barras de vida solamente
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Vida Jugador A"),
                        LinearProgressIndicator(
                          value: vidaA.clamp(0, 100) / 100.0,
                          minHeight: 10,
                        ),
                        Text("${socketService.vidaA} HP"),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Vida Jugador B"),
                        LinearProgressIndicator(
                          value: vidaB.clamp(0, 100) / 100.0,
                          minHeight: 10,
                        ),
                        Text("${socketService.vidaB} HP"),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Acciones
              const Text("Elige tu acción:"),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => socketService.enviarAccion(
                      roomId,
                      jugadorCtrl.text.trim(),
                      "atacar",
                    ),
                    child: const Text("Atacar"),
                  ),
                  ElevatedButton(
                    onPressed: () => socketService.enviarAccion(
                      roomId,
                      jugadorCtrl.text.trim(),
                      "curar",
                    ),
                    child: const Text("Curar"),
                  ),
                  ElevatedButton(
                    onPressed: () => socketService.enviarAccion(
                      roomId,
                      jugadorCtrl.text.trim(),
                      "defender",
                    ),
                    child: const Text("Defender"),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Log
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    socketService.log,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}