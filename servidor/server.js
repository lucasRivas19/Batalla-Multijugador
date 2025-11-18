// servidor/server.js

const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');

const app = express();
app.use(cors());

const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*',
  },
});

// Duración de cada turno (cliente y servidor deben usar el mismo valor)
const TURN_DURATION_MS = 10000;

// ======================
// Clase Partida (proceso concurrente lógico)
// ======================
class Partida {
  constructor(roomId) {
    this.roomId = roomId;

    // Estado de juego
    this.estado = {
      vidaA: 100,
      vidaB: 100,
      energiaA: 100,
      energiaB: 100,
      turno: 1,
    };

    // Acciones pendientes del turno actual
    this.accionesPendientes = {}; // { JugadorA: 'atacar', JugadorB: 'curar' }

    // Timeout del turno
    this.timeoutId = null;

    // Jugadores que participaron en esta partida
    this.jugadores = new Set();
  }

  registrarJugador(jugador) {
    this.jugadores.add(jugador);
  }

  // Enviar el estado actual a un socket específico (para reconexión / join)
  enviarEstadoActual(socket) {
    socket.emit('estado_partida', {
      roomId: this.roomId,
      estado: this.estado,
      turno: this.estado.turno,
    });
  }

  // Registrar acción de un jugador
  registrarAccion(jugador, accion, io) {
    // Evitamos acciones duplicadas en un mismo turno
    if (this.accionesPendientes[jugador]) {
      return;
    }

    this.accionesPendientes[jugador] = accion;

    // Si es la primera acción, arrancamos timeout de turno
    if (!this.timeoutId) {
      this.iniciarTimeout(io);
    }

    // Si ya recibimos acciones de ambos jugadores, resolvemos antes del timeout
    if (Object.keys(this.accionesPendientes).length >= 2) {
      this.resolverTurno(io, false);
    }
  }

  iniciarTimeout(io) {
    this.timeoutId = setTimeout(() => {
      // Si faltó alguna acción, asignamos acción por defecto
      if (!this.accionesPendientes['JugadorA']) {
        this.accionesPendientes['JugadorA'] = 'defender';
      }
      if (!this.accionesPendientes['JugadorB']) {
        this.accionesPendientes['JugadorB'] = 'defender';
      }
      this.resolverTurno(io, true);
    }, TURN_DURATION_MS);
  }

  resolverTurno(io, porTimeout) {
    if (this.timeoutId) {
      clearTimeout(this.timeoutId);
      this.timeoutId = null;
    }

    const acciones = this.accionesPendientes;
    const logTurno = [];

    const accionA = acciones['JugadorA'] || 'defender';
    const accionB = acciones['JugadorB'] || 'defender';

    logTurno.push(`Turno ${this.estado.turno}: A=${accionA}, B=${accionB}`);

    // Lógica simple de resolución (podés mejorarla luego)
    // --- Jugador A sobre B ---
    if (accionA === 'atacar') {
      let dano = 20;
      if (accionB === 'defender') dano = 10;
      this.estado.vidaB = Math.max(0, this.estado.vidaB - dano);
      logTurno.push(`JugadorA ataca a JugadorB causando ${dano} de daño.`);
    } else if (accionA === 'curar') {
      this.estado.vidaA = Math.min(100, this.estado.vidaA + 15);
      logTurno.push('JugadorA se cura 15 puntos de vida.');
    }

    // --- Jugador B sobre A ---
    if (accionB === 'atacar') {
      let dano = 20;
      if (accionA === 'defender') dano = 10;
      this.estado.vidaA = Math.max(0, this.estado.vidaA - dano);
      logTurno.push(`JugadorB ataca a JugadorA causando ${dano} de daño.`);
    } else if (accionB === 'curar') {
      this.estado.vidaB = Math.min(100, this.estado.vidaB + 15);
      logTurno.push('JugadorB se cura 15 puntos de vida.');
    }

    if (porTimeout) {
      logTurno.push('⚠️ Turno resuelto por timeout (acciones por defecto para jugadores inactivos).');
    }

    // Energía (ejemplo simple)
    this.estado.energiaA = Math.min(100, this.estado.energiaA + 10);
    this.estado.energiaB = Math.min(100, this.estado.energiaB + 10);

    // Avanzar turno
    this.estado.turno += 1;

    // Limpiar acciones para el siguiente turno
    this.accionesPendientes = {};

    // Enviar resultado a todos los clientes de la sala
    io.to(this.roomId).emit('resultado_turno', {
      roomId: this.roomId,
      estado: this.estado,
      log: logTurno,
      porTimeout,
      turno: this.estado.turno - 1,
      turnDurationMs: TURN_DURATION_MS,
    });
  }
}

// Registro de partidas (roomId -> Partida)
const partidas = new Map();

function obtenerPartida(roomId) {
  if (!partidas.has(roomId)) {
    partidas.set(roomId, new Partida(roomId));
  }
  return partidas.get(roomId);
}

// ======================
// Socket.IO
// ======================
io.on('connection', (socket) => {
  console.log('🔌 Nuevo cliente conectado:', socket.id);

  socket.on('unirse_partida', ({ roomId, jugador }) => {
    console.log(`📥 ${jugador} se une a la sala ${roomId}`);

    const partida = obtenerPartida(roomId);
    partida.registrarJugador(jugador);

    socket.join(roomId);

    // Mandamos estado actual al jugador que se conecta (join o reconexión)
    partida.enviarEstadoActual(socket);
  });

  socket.on('accion', (data) => {
    const { roomId, jugador, accion } = data;
    const partida = partidas.get(roomId);
    if (!partida) {
      console.warn('⚠️ Acción para sala inexistente:', roomId);
      return;
    }
    console.log(`🎯 Acción recibida en ${roomId}: ${jugador} -> ${accion}`);
    partida.registrarAccion(jugador, accion, io);
  });

  socket.on('disconnect', () => {
    console.log('❌ Cliente desconectado:', socket.id);
    // No destruimos la partida, para permitir reconexión
  });
});

// Endpoint simple para probar que el servidor está vivo
app.get('/status', (req, res) => {
  res.json({ ok: true, salasActivas: partidas.size });
});

const PORT = 3000;
server.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Servidor corriendo en puerto ${PORT}`);
});
