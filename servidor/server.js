// servidor/server.js

const http = require('http');
const express = require('express');
const { Server } = require('socket.io');

// ⏱ Duración del turno: 3 segundos para reaccionar
const TURN_DURATION_MS = 3000;

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: '*' },
});

app.get('/status', (req, res) => {
  res.json({ ok: true });
});

class Partida {
  constructor(roomId, io) {
    this.roomId = roomId;
    this.io = io;

    this.estado = {
      vidaA: 100,
      vidaB: 100,
      turno: 1,
    };

    this.jugadores = new Set();
    this.accionesPendientes = new Map();
    this.timeoutId = null;
    this.resolviendo = false;
  }

  registrarJugador(jugador) {
    if (this.jugadores.has(jugador)) {
      return false;
    }
    this.jugadores.add(jugador);
    return true;
  }

  enviarEstadoActual(socket) {
    socket.emit('estado_partida', {
      roomId: this.roomId,
      estado: this.estado,
      jugadores: Array.from(this.jugadores),
      turnDurationMs: TURN_DURATION_MS,
      log: `Estado actual de la partida. VidaA=${this.estado.vidaA}, VidaB=${this.estado.vidaB}, turno=${this.estado.turno}`,
    });
  }

  registrarAccion(jugador, accion) {
    if (!this.jugadores.has(jugador)) {
      this.jugadores.add(jugador);
    }

    this.accionesPendientes.set(jugador, accion);

    if (!this.timeoutId) {
      this.iniciarTimeout();
    }

    if (this.accionesPendientes.size >= this.jugadores.size) {
      this._resolverConLock(false);
    }
  }

  iniciarTimeout() {
    this.timeoutId = setTimeout(() => {
      this._resolverConLock(true);
    }, TURN_DURATION_MS);
  }

  _resolverConLock(porTimeout) {
    if (this.resolviendo) return;

    this.resolviendo = true;

    if (this.timeoutId) {
      clearTimeout(this.timeoutId);
      this.timeoutId = null;
    }

    this.resolverTurno(porTimeout);

    this.resolviendo = false;
  }

  resolverTurno(porTimeout) {
    const logTurno = [];

    if (porTimeout) {
      logTurno.push('⏰ Tiempo de turno agotado. Algunos jugadores no respondieron.');
    }

    // ⚠️ CAMBIO CLAVE: default = "ninguna" (vulnerable), NO "defender"
    for (const jugador of this.jugadores) {
      if (!this.accionesPendientes.has(jugador)) {
        this.accionesPendientes.set(jugador, 'ninguna');
        logTurno.push(
          `Jugador ${jugador} no eligió acción: queda INACTIVO y vulnerable este turno.`
        );
      }
    }

    let [jugA, jugB] = Array.from(this.jugadores);

    if (!jugA) {
      return;
    }

    if (!jugB) {
      jugB = 'Bot';
      this.jugadores.add(jugB);
      if (!this.accionesPendientes.has(jugB)) {
        this.accionesPendientes.set(jugB, 'ninguna');
        logTurno.push('Se crea un bot inactivo como oponente.');
      }
    }

    const accA = this.accionesPendientes.get(jugA);
    const accB = this.accionesPendientes.get(jugB);

    const dmg = 20;
    const heal = 15;

    const estado = this.estado;

    // Curar = invulnerable
    const invulA = accA === 'curar';
    const invulB = accB === 'curar';
    const defA = accA === 'defender';
    const defB = accB === 'defender';

    // ✅ Primero aplicamos curación
    if (accA === 'curar') {
      const prev = estado.vidaA;
      estado.vidaA = Math.min(100, estado.vidaA + heal);
      logTurno.push(
        `${jugA} se cura (+${estado.vidaA - prev}). Queda con ${estado.vidaA} HP y es invulnerable este turno.`
      );
    }

    if (accB === 'curar') {
      const prev = estado.vidaB;
      estado.vidaB = Math.min(100, estado.vidaB + heal);
      logTurno.push(
        `${jugB} se cura (+${estado.vidaB - prev}). Queda con ${estado.vidaB} HP y es invulnerable este turno.`
      );
    }

    // ✅ Luego aplicamos ataques
    if (accA === 'atacar') {
      if (!invulB && !defB && estado.vidaB > 0) {
        const prev = estado.vidaB;
        estado.vidaB = Math.max(0, estado.vidaB - dmg);
        logTurno.push(
          `${jugA} ataca a ${jugB} y le causa ${prev - estado.vidaB} de daño. Vida de ${jugB}: ${estado.vidaB}.`
        );
      } else {
        logTurno.push(
          `${jugA} ataca a ${jugB}, pero el ataque no hace efecto (defensa o curación de ${jugB}).`
        );
      }
    }

    if (accB === 'atacar') {
      if (!invulA && !defA && estado.vidaA > 0) {
        const prev = estado.vidaA;
        estado.vidaA = Math.max(0, estado.vidaA - dmg);
        logTurno.push(
          `${jugB} ataca a ${jugA} y le causa ${prev - estado.vidaA} de daño. Vida de ${jugA}: ${estado.vidaA}.`
        );
      } else {
        logTurno.push(
          `${jugB} ataca a ${jugA}, pero el ataque no hace efecto (defensa o curación de ${jugA}).`
        );
      }
    }

    // Mensajes informativos para defender
    if (accA === 'defender' && accB !== 'atacar') {
      logTurno.push(`${jugA} se defiende, pero no recibe ataques este turno.`);
    }
    if (accB === 'defender' && accA !== 'atacar') {
      logTurno.push(`${jugB} se defiende, pero no recibe ataques este turno.`);
    }

    estado.turno += 1;
    this.accionesPendientes.clear();

    this.io.to(this.roomId).emit('resultado_turno', {
      roomId: this.roomId,
      estado: this.estado,
      acciones: {
        jugadorA: { nombre: jugA, accion: accA },
        jugadorB: { nombre: jugB, accion: accB },
      },
      log: logTurno.join('\n'),
      turnDurationMs: TURN_DURATION_MS,
    });
  }
}

const partidas = new Map();

function obtenerPartida(roomId) {
  let partida = partidas.get(roomId);
  if (!partida) {
    partida = new Partida(roomId, io);
    partidas.set(roomId, partida);
    console.log(`🎮 Nueva partida creada para sala ${roomId}`);
  }
  return partida;
}

io.on('connection', (socket) => {
  console.log(`🔌 Cliente conectado: ${socket.id}`);

  socket.on('unirse_partida', ({ roomId, jugador }) => {
    console.log(`📥 ${jugador} quiere unirse a la sala ${roomId}`);

    const partida = obtenerPartida(roomId);
    const ok = partida.registrarJugador(jugador);

    if (!ok) {
      console.log(`⚠️ Nombre ya en uso en sala ${roomId}: ${jugador}`);
      socket.emit('error_unirse', {
        tipo: 'nombre_en_uso',
        mensaje: 'El nombre ya está siendo usado en esta sala. Elegí otro.',
      });
      return;
    }

    socket.join(roomId);
    partida.enviarEstadoActual(socket);
  });

  socket.on('accion', ({ roomId, jugador, accion }) => {
    const partida = obtenerPartida(roomId);
    partida.registrarAccion(jugador, accion);
  });

  socket.on('disconnect', () => {
    console.log(`🔴 Cliente desconectado: ${socket.id}`);
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`🚀 Servidor escuchando en puerto ${PORT}`);
});
