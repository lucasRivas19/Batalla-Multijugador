// servidor/stress_test.js
//
// Uso:
//   node stress_test.js 1        # 1 sala
//   node stress_test.js 4 50     # 4 salas, 50 turnos
//
// Stress test simple con sockets reales

const { io } = require('socket.io-client');

const N_SALAS = parseInt(process.argv[2] || '1', 10);
const TURNOS_MAX = parseInt(process.argv[3] || '50', 10);
const SERVER_URL = 'http://localhost:3000';

console.log(
  `Stress test: ${N_SALAS} sala(s), ${TURNOS_MAX} turnos por sala`
);

let partidasTerminadas = 0;
let t0 = null;

const infoSalas = {};

function crearJugador(nombre, roomId, esPrincipal) {
  const socket = io(SERVER_URL, {
    transports: ['websocket'],
    reconnection: false,
  });

  let turnosRecibidos = 0;
  let listo = false;

  socket.on('connect', () => {
    socket.emit('unirse_partida', { roomId, jugador: nombre });
  });

  socket.on('estado_partida', () => {
    if (!listo) {
      listo = true;

      if (!t0) {
        t0 = Date.now();
        console.log(`⏱️ Inicio medición: ${t0}`);
      }

      enviarAccion();
    }
  });

  socket.on('resultado_turno', () => {
    if (esPrincipal) {
      turnosRecibidos++;
      infoSalas[roomId].turnos = turnosRecibidos;
    }

    if (esPrincipal && turnosRecibidos >= TURNOS_MAX) {
      cerrarSala(roomId);
      return;
    }

    if (turnosRecibidos < TURNOS_MAX) {
      enviarAccion();
    }
  });

  socket.on('error_unirse', (err) => {
    console.error(`[${roomId}] Error uniendo ${nombre}:`, err?.mensaje);
    socket.disconnect();
  });

  function enviarAccion() {
    // delay chico para simular jugador real
    const delay = Math.floor(Math.random() * 40) + 10;

    setTimeout(() => {
      socket.emit('accion', {
        roomId,
        jugador: nombre,
        accion: accionRandom(),
      });
    }, delay);
  }

  return socket;
}

function accionRandom() {
  const acciones = ['atacar', 'curar', 'defender'];
  return acciones[Math.floor(Math.random() * acciones.length)];
}

function cerrarSala(roomId) {
  console.log(`[${roomId}] ${TURNOS_MAX} turnos completados`);

  infoSalas[roomId].sockets.forEach((s) => s.disconnect());
  partidasTerminadas++;

  if (partidasTerminadas === N_SALAS) {
    finalizarTest();
  }
}

function finalizarTest() {
  const tf = Date.now();
  const totalMs = tf - t0;
  const totalTurnos = N_SALAS * TURNOS_MAX;
  const throughput = (totalTurnos / (totalMs / 1000)).toFixed(2);

  console.log('===========================');
  console.log('✅ Stress test finalizado');
  console.log(`Salas: ${N_SALAS}`);
  console.log(`Turnos totales: ${totalTurnos}`);
  console.log(`Tiempo total: ${totalMs} ms`);
  console.log(`Throughput: ${throughput} turnos/seg`);
  console.log('===========================');

  process.exit(0);
}

// Crear salas
for (let i = 1; i <= N_SALAS; i++) {
  const roomId = `sala${i}`;

  infoSalas[roomId] = {
    turnos: 0,
    sockets: [],
  };

  const a = crearJugador('JugadorA', roomId, true);
  const b = crearJugador('JugadorB', roomId, false);

  infoSalas[roomId].sockets.push(a, b);
}
