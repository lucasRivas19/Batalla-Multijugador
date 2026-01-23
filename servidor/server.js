// servidor/server.js

const http = require('http');
const express = require('express');
const { Server } = require('socket.io');

const TURN_DURATION_MS = 3000;

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: '*' },
});

// endpoint simple para ver si el server está vivo
app.get('/status', (req, res) => {
  res.json({ ok: true });
});

// =========================
// Partida 1 vs 1
// =========================
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
    this.resolviendo = false; // para evitar resolver dos veces el mismo turno
  }

  registrarJugador(nombre) {
    if (this.jugadores.has(nombre)) {
      return { ok: false, motivo: 'nombre_en_uso' };
    }

    if (this.jugadores.size >= 2) {
      return { ok: false, motivo: 'sala_llena' };
    }

    this.jugadores.add(nombre);
    console.log(`✅ ${nombre} entró a la sala ${this.roomId}`);
    return { ok: true };
  }

  eliminarJugador(nombre) {
    if (!this.jugadores.delete(nombre)) return;

    console.log(`👋 ${nombre} salió de la sala ${this.roomId}`);
    this.accionesPendientes.delete(nombre);

    // si no queda nadie, volvemos todo a cero
    if (this.jugadores.size === 0) {
      this.estado = { vidaA: 100, vidaB: 100, turno: 1 };
      this.accionesPendientes.clear();

      if (this.timeoutId) {
        clearTimeout(this.timeoutId);
        this.timeoutId = null;
      }
    }
  }

  enviarEstadoActual(socket) {
    socket.emit('estado_partida', {
      roomId: this.roomId,
      estado: this.estado,
      jugadores: Array.from(this.jugadores),
      turnDurationMs: TURN_DURATION_MS,
      log: `Turno ${this.estado.turno} | A=${this.estado.vidaA} B=${this.estado.vidaB}`,
    });
  }

  registrarAccion(jugador, accion) {
    if (!this.jugadores.has(jugador)) return;

    this.accionesPendientes.set(jugador, accion);

    if (!this.timeoutId) {
      this._iniciarTimeout();
    }

    if (this.accionesPendientes.size === this.jugadores.size) {
      this._resolverConLock(false);
    }
  }

  _iniciarTimeout() {
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

    this._resolverTurno(porTimeout);
    this.resolviendo = false;
  }

  _resolverTurno(porTimeout) {
    const log = [];

    if (porTimeout) {
      log.push('⏰ Se terminó el tiempo del turno.');
    }

    // acciones que no llegaron se toman como "ninguna"
    for (const j of this.jugadores) {
      if (!this.accionesPendientes.has(j)) {
        this.accionesPendientes.set(j, 'ninguna');
        log.push(`${j} no eligió acción.`);
      }
    }

    let [jugA, jugB] = Array.from(this.jugadores);

    if (!jugA) return;

    // si hay uno solo, le ponemos un bot medio bobo
    if (!jugB) {
      jugB = 'Bot';
      this.jugadores.add(jugB);
      this.accionesPendientes.set(jugB, 'ninguna');
      log.push('Se agrega un bot inactivo.');
    }

    const accA = this.accionesPendientes.get(jugA);
    const accB = this.accionesPendientes.get(jugB);

    const dmg = 20;
    const heal = 15;
    const estado = this.estado;

    const invulA = accA === 'curar';
    const invulB = accB === 'curar';
    const defA = accA === 'defender';
    const defB = accB === 'defender';

    // curaciones primero
    if (accA === 'curar') {
      const antes = estado.vidaA;
      estado.vidaA = Math.min(100, estado.vidaA + heal);
      log.push(`${jugA} se cura (+${estado.vidaA - antes}).`);
    }

    if (accB === 'curar') {
      const antes = estado.vidaB;
      estado.vidaB = Math.min(100, estado.vidaB + heal);
      log.push(`${jugB} se cura (+${estado.vidaB - antes}).`);
    }

    // ataques
    if (accA === 'atacar') {
      if (!invulB && !defB && estado.vidaB > 0) {
        const antes = estado.vidaB;
        estado.vidaB = Math.max(0, estado.vidaB - dmg);
        log.push(`${jugA} le pega a ${jugB} (-${antes - estado.vidaB}).`);
      } else {
        log.push(`${jugA} ataca, pero no pasa nada.`);
      }
    }

    if (accB === 'atacar') {
      if (!invulA && !defA && estado.vidaA > 0) {
        const antes = estado.vidaA;
        estado.vidaA = Math.max(0, estado.vidaA - dmg);
        log.push(`${jugB} le pega a ${jugA} (-${antes - estado.vidaA}).`);
      } else {
        log.push(`${jugB} ataca, pero no pasa nada.`);
      }
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
      log: log.join('\n'),
      turnDurationMs: TURN_DURATION_MS,
    });
  }
}

// =========================
// Manejo de partidas
// =========================

const partidas = new Map();
const infoPorSocket = new Map();

function obtenerPartida(roomId) {
  if (!partidas.has(roomId)) {
    partidas.set(roomId, new Partida(roomId, io));
    console.log(`🎮 Sala creada: ${roomId}`);
  }
  return partidas.get(roomId);
}

// =========================
// Socket.IO
// =========================

io.on('connection', (socket) => {
  console.log(`🔌 Conectado: ${socket.id}`);

  socket.on('unirse_partida', ({ roomId, jugador }) => {
    const partida = obtenerPartida(roomId);
    const res = partida.registrarJugador(jugador);

    if (!res.ok) {
      socket.emit('error_unirse', {
        tipo: res.motivo,
        mensaje:
          res.motivo === 'nombre_en_uso'
            ? 'Ese nombre ya está en uso.'
            : 'La sala está llena.',
      });
      return;
    }

    infoPorSocket.set(socket.id, { roomId, jugador });
    socket.join(roomId);
    partida.enviarEstadoActual(socket);
  });

  socket.on('accion', ({ roomId, jugador, accion }) => {
    const partida = partidas.get(roomId);
    if (partida) {
      partida.registrarAccion(jugador, accion);
    }
  });

  socket.on('disconnect', () => {
    console.log(`🔴 Desconectado: ${socket.id}`);

    const info = infoPorSocket.get(socket.id);
    if (!info) return;

    const partida = partidas.get(info.roomId);
    if (partida) {
      partida.eliminarJugador(info.jugador);
    }

    infoPorSocket.delete(socket.id);
  });
});

// =========================
// Inicio del server
// =========================

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`🚀 Server escuchando en ${PORT}`);
});
