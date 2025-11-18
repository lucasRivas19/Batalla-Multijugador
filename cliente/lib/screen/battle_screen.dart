// lib/screens/battle_screen.dart

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

    final bool conectado = socketService.conectado;
    final bool intentandoReconectar = socketService.intentandoReconectar;

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
              ),
            ),
            const SizedBox(height: 10),

            // Botones de conectar / reconectar
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => socketService.conectar(
                      jugadorCtrl.text.trim(),
                      roomId,
                    ),
                    child: const Text("Conectarse"),
                  ),
                ),
                const SizedBox(width: 8),
                if (!conectado && intentandoReconectar)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => socketService.reconectar(),
                      child: const Text("Reconectar"),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            // Estado de conexión
            Text(
              conectado
                  ? "Estado: ✅ Conectado"
                  : (intentandoReconectar
                      ? "Estado: 🔁 Desconectado, listo para reconectar"
                      : "Estado: ❌ Desconectado"),
              style: TextStyle(
                color: conectado ? Colors.green : Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),

            const Divider(height: 20),

            if (conectado) ...[
              // Timer de turno
              _buildTurnTimer(socketService),

              const SizedBox(height: 16),

              // Barras de estado (JugadorA siempre se asume el local en este ejemplo)
              _buildBar(
                label: "Vida JugadorA",
                value: socketService.estado["vidaA"] / 100,
                color: Colors.redAccent,
                texto: "${socketService.estado["vidaA"]}",
              ),
              const SizedBox(height: 8),
              _buildBar(
                label: "Energía JugadorA",
                value: socketService.estado["energiaA"] / 100,
                color: Colors.blueAccent,
                texto: "${socketService.estado["energiaA"]}",
              ),
              const SizedBox(height: 16),

              _buildBar(
                label: "Vida JugadorB",
                value: socketService.estado["vidaB"] / 100,
                color: Colors.orangeAccent,
                texto: "${socketService.estado["vidaB"]}",
              ),
              const SizedBox(height: 8),
              _buildBar(
                label: "Energía JugadorB",
                value: socketService.estado["energiaB"] / 100,
                color: Colors.teal,
                texto: "${socketService.estado["energiaB"]}",
              ),
              const SizedBox(height: 20),

              const Text(
                "Elige tu acción:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                    ),
                    child: const Text("Atacar"),
                  ),
                  ElevatedButton(
                    onPressed: () => socketService.enviarAccion(
                      roomId,
                      jugadorCtrl.text.trim(),
                      "curar",
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text("Curar"),
                  ),
                  ElevatedButton(
                    onPressed: () => socketService.enviarAccion(
                      roomId,
                      jugadorCtrl.text.trim(),
                      "defender",
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                    ),
                    child: const Text("Defender"),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Log del combate
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  color: Colors.black54,
                  child: SingleChildScrollView(
                    reverse: true,
                    child: Text(
                      socketService.log,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTurnTimer(SocketService socketService) {
    final totalSegundos = (socketService.turnDurationMs / 1000).round();
    final restantes = socketService.segundosRestantes;
    final progreso =
        totalSegundos > 0 ? restantes / totalSegundos : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Tiempo restante para elegir acción:",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Stack(
          children: [
            Container(
              height: 20,
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 20,
              width: double.infinity,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progreso.clamp(0.0, 1.0),
                child: Container(
                  height: 20,
                  decoration: BoxDecoration(
                    color: restantes > 3 ? Colors.blueAccent : Colors.redAccent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Center(
                child: Text(
                  "${socketService.segundosRestantes}s",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBar({
    required String label,
    required double value,
    required Color color,
    required String texto,
  }) {
    final double safeValue = value.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Stack(
          children: [
            Container(
              height: 20,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              height: 20,
              width: safeValue * 300,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            Positioned.fill(
              child: Center(
                child: Text(
                  texto,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
