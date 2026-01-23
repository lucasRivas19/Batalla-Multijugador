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
      TextEditingController(text: 'JugadorA');

  String _salaInicial = 'sala1';

  @override
  Widget build(BuildContext context) {
    final socketService = Provider.of<SocketService>(context);

    // si el service ya tiene sala, usamos esa
    final sala = socketService.salaActual ?? _salaInicial;

    // mostramos snackbar solo para errores reales
    if (socketService.ultimoErrorUnirse != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(socketService.ultimoErrorUnirse!)),
        );
        socketService.clearError();
      });
    }

    final conectado = socketService.conectado;
    final intentando = socketService.intentandoReconectar;

    final vidaA = socketService.vidaA.toDouble();
    final vidaB = socketService.vidaB.toDouble();
    final tiempoRestante =
        (socketService.tiempoRestanteMs / 1000).ceil();

    return Scaffold(
      appBar: AppBar(
        title: const Text('⚔️ Batalla Multijugador'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: jugadorCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre del jugador',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: intentando
                        ? null
                        : () {
                            FocusScope.of(context).unfocus();

                            final nombre =
                                jugadorCtrl.text.trim();
                            if (nombre.isEmpty) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'El nombre no puede estar vacío'),
                                ),
                              );
                              return;
                            }

                            socketService.conectar(nombre, sala);
                          },
                    child: Text(
                      intentando
                          ? 'Conectando...'
                          : (conectado
                              ? 'Reconectar'
                              : 'Conectarse'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: socketService.socketAbierto
                      ? socketService.desconectar
                      : null,
                  icon:
                      const Icon(Icons.power_settings_new),
                  tooltip: 'Desconectar',
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                const Text(
                  'Estado: ',
                  style:
                      TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  conectado
                      ? '✅ En partida'
                      : '⛔ No en partida',
                  style: TextStyle(
                    color: conectado
                        ? Colors.green
                        : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const Divider(),

            if (conectado) ...[
              Text('Sala: $sala'),
              Text('Turno: ${socketService.turno}'),
              const SizedBox(height: 8),

              if (socketService.tiempoRestanteMs > 0)
                Text(
                  '⏳ Tiempo restante: ${tiempoRestante}s',
                ),

              const SizedBox(height: 12),

              // barras de vida
              Row(
                children: [
                  Expanded(
                    child: _VidaWidget(
                      titulo: 'Jugador A',
                      vida: socketService.vidaA,
                      value: vidaA,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _VidaWidget(
                      titulo: 'Jugador B',
                      vida: socketService.vidaB,
                      value: vidaB,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // muñequitos
              SizedBox(
                height: 140,
                child: Row(
                  children: [
                    Expanded(
                      child: CharacterWidget(
                        label: 'Jugador A',
                        ultimaAccion:
                            socketService.ultimaAccionA,
                        isLeft: true,
                      ),
                    ),
                    Expanded(
                      child: CharacterWidget(
                        label: 'Jugador B',
                        ultimaAccion:
                            socketService.ultimaAccionB,
                        isLeft: false,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Text('Elegí tu acción:'),
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () =>
                        socketService.enviarAccion(
                      sala,
                      jugadorCtrl.text.trim(),
                      'atacar',
                    ),
                    child: const Text('Atacar'),
                  ),
                  ElevatedButton(
                    onPressed: () =>
                        socketService.enviarAccion(
                      sala,
                      jugadorCtrl.text.trim(),
                      'curar',
                    ),
                    child: const Text('Curar'),
                  ),
                  ElevatedButton(
                    onPressed: () =>
                        socketService.enviarAccion(
                      sala,
                      jugadorCtrl.text.trim(),
                      'defender',
                    ),
                    child: const Text('Defender'),
                  ),
                ],
              ),

              const SizedBox(height: 16),
            ],

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

// widget chico para no repetir código de las barras
class _VidaWidget extends StatelessWidget {
  final String titulo;
  final int vida;
  final double value;

  const _VidaWidget({
    required this.titulo,
    required this.vida,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo),
        LinearProgressIndicator(
          value: value.clamp(0, 100) / 100,
          minHeight: 10,
        ),
        Text('$vida HP'),
      ],
    );
  }
}

// --------------------------------------------------------
// Muñequito con animaciones simples
// --------------------------------------------------------

class CharacterWidget extends StatefulWidget {
  final String label;
  final String? ultimaAccion;
  final bool isLeft;

  const CharacterWidget({
    super.key,
    required this.label,
    required this.ultimaAccion,
    required this.isLeft,
  });

  @override
  State<CharacterWidget> createState() =>
      _CharacterWidgetState();
}

class _CharacterWidgetState extends State<CharacterWidget> {
  double _offsetX = 0;
  double _scale = 1.0;
  double _overlayOpacity = 0.0;
  Color _overlayColor = Colors.transparent;

  @override
  void didUpdateWidget(
      covariant CharacterWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.ultimaAccion != null &&
        widget.ultimaAccion !=
            oldWidget.ultimaAccion) {
      _animar(widget.ultimaAccion!);
    }
  }

  void _animar(String accion) {
    setState(() {
      _offsetX = 0;
      _scale = 1.0;
      _overlayOpacity = 0.0;
      _overlayColor = Colors.transparent;
    });

    if (accion == 'atacar') {
      final dir = widget.isLeft ? 1.0 : -1.0;
      setState(() => _offsetX = 20 * dir);
      Future.delayed(
        const Duration(milliseconds: 150),
        () {
          if (!mounted) return;
          setState(() => _offsetX = 0);
        },
      );
    } else if (accion == 'curar') {
      setState(() {
        _overlayColor =
            Colors.greenAccent.withOpacity(0.7);
        _overlayOpacity = 1.0;
        _scale = 1.1;
      });
      Future.delayed(
        const Duration(milliseconds: 300),
        () {
          if (!mounted) return;
          setState(() {
            _overlayOpacity = 0;
            _scale = 1.0;
          });
        },
      );
    } else if (accion == 'defender') {
      setState(() {
        _overlayColor =
            Colors.blueAccent.withOpacity(0.7);
        _overlayOpacity = 1.0;
      });
      Future.delayed(
        const Duration(milliseconds: 300),
        () {
          if (!mounted) return;
          setState(() => _overlayOpacity = 0);
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.translationValues(
          _offsetX,
          0,
          0,
        )..scale(_scale),
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: 35,
              backgroundColor: Colors.grey.shade800,
              child: Text(
                widget.isLeft ? '🧔‍♂️' : '🥷',
                style:
                    const TextStyle(fontSize: 32),
              ),
            ),
            AnimatedOpacity(
              duration:
                  const Duration(milliseconds: 150),
              opacity: _overlayOpacity,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _overlayColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -20,
              child: Text(
                widget.label,
                style: const TextStyle(
                    color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
