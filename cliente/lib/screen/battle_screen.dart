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
  final TextEditingController jugadorCtrl = TextEditingController(text: "JugadorA");
  final String roomId = "sala1";
  String accionSeleccionada = "";

  @override
  Widget build(BuildContext context) {
    final socketService = Provider.of<SocketService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("⚔️ Batalla Multijugador"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: jugadorCtrl,
              decoration: const InputDecoration(labelText: "Nombre del jugador"),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => socketService.conectar(jugadorCtrl.text, roomId),
              child: const Text("Conectarse"),
            ),
            const Divider(),

            if (socketService.conectado) ...[
              // 🩸 Barras de estado del jugador
              _buildBar(
                label: "Vida",
                value: socketService.estado["vidaA"] / 100,
                color: Colors.redAccent,
                texto: "${socketService.estado["vidaA"]}",
              ),
              const SizedBox(height: 8),
              _buildBar(
                label: "Energía",
                value: socketService.estado["energiaA"] / 100,
                color: Colors.blueAccent,
                texto: "${socketService.estado["energiaA"]}",
              ),
              const SizedBox(height: 20),

              // 🕹️ Botones de acción
              const Text("Elige tu acción:"),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => socketService.enviarAccion(roomId, jugadorCtrl.text, "atacar"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                    child: const Text("Atacar"),
                  ),
                  ElevatedButton(
                    onPressed: () => socketService.enviarAccion(roomId, jugadorCtrl.text, "curar"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text("Curar"),
                  ),
                  ElevatedButton(
                    onPressed: () => socketService.enviarAccion(roomId, jugadorCtrl.text, "defender"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                    child: const Text("Defender"),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 💬 Log del combate
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  color: Colors.black54,
                  child: SingleChildScrollView(
                    reverse: true,
                    child: Text(
                      socketService.log,
                      style: const TextStyle(fontFamily: 'monospace'),
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

  // 🔧 Función para dibujar las barras
  Widget _buildBar({
    required String label,
    required double value,
    required Color color,
    required String texto,
  }) {
    // límite de 0-1
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
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
