// servidor/stress_test.js
//
// Uso:
//   node stress_test.js 1        # 1 sala (T1)
//   node stress_test.js 4 50     # 4 salas, 50 turnos
//
// Requiere: npm install socket.io-client

const { io } = require('socket.io-client');

const N_SALAS = parseInt(process.argv[2] || '1', 10);
const TURNOS_MAX = parseInt(process.argv[3] || '50', 10);
const SERVER_URL = 'http://localhost:3000';

console.log(`Iniciando stress test con ${N_SALAS} sala(s), ${TURNOS_MAX} turnos cada una.`);

// Para saber cuándo terminaron TODAS las salas
let partidasTerminadas = 0;
let t0 = null;

// Para debug resumido por sala
const infoSalas = {};

function crearJugador(nombre, roomId, esPrincipal) {
  const socket = io(SERVER_URL, {
    transports: ['websocket'],
    reconnection: false,
  });

  let turnosRecibidos = 0;
  let listoParaJugar = false;

  socket.on('connect', () => {
    console.log(`[${roomId}] ${nombre} conectado, uniendo a partida...`);
    socket.emit('unirse_partida', { roomId, jugador: nombre });
  });

  socket.on('estado_partida', (msg) => {
    // Primera vez que recibimos estado -> arrancamos a mandar acciones
    if (!listoParaJugar) {
      listoParaJugar = true;
      if (!t0) {
        t0 = Date.now();
        console.log(`⏱️  t0 = ${t0}`);
      }
      // Disparamos la primera acción
      enviarAccion();
    }
  });

  socket.on('resultado_turno', (msg) => {
    // Sólo el jugador "principal" de la sala cuenta turnos para evitar duplicar
    if (esPrincipal) {
      turnosRecibidos++;
      infoSalas[roomId].turnos = turnosRecibidos;
    }

    if (esPrincipal && turnosRecibidos >= TURNOS_MAX) {
      console.log(`[${roomId}] Alcanzados ${TURNOS_MAX} turnos. Terminando sala...`);

      // Cerramos ambos sockets de la sala
      infoSalas[roomId].sockets.forEach((s) => s.disconnect());

      partidasTerminadas++;
      if (partidasTerminadas === N_SALAS) {
        const tf = Date.now();
        const totalMs = tf - t0;
        console.log('===========================');
        console.log(`✅ Todas las salas completadas.`);
        console.log(`Salas: ${N_SALAS}, Turnos por sala: ${TURNOS_MAX}`);
        console.log(`Tiempo total: ${totalMs} ms (${(totalMs / 1000).toFixed(3)} s)`);
        console.log('===========================');
        process.exit(0);
      }
      return;
    }

    // Si todavía no llegamos al máximo de turnos, mandamos otra acción
    if (turnosRecibidos < TURNOS_MAX) {
      enviarAccion();
    }
  });

  socket.on('error_unirse', (err) => {
    console.error(`[${roomId}] Error al unirse como ${nombre}:`, err.mensaje);
    socket.disconnect();
  });

  socket.on('connect_error', (err) => {
    console.error(`[${roomId}] Error de conexión de ${nombre}:`, err.message);
  });

  function enviarAccion() {
    // Para el stress: acciones fijas, siempre atacar
    socket.emit('accion', {
      roomId,
      jugador: nombre,
      accion: 'atacar',
    });
  }

  return socket;
}

// Crear N_SALAS, cada una con JugadorA y JugadorB
for (let i = 1; i <= N_SALAS; i++) {
  const roomId = `sala${i}`;
  infoSalas[roomId] = {
    turnos: 0,
    sockets: [],
  };

  const sockA = crearJugador('JugadorA', roomId, true);  // principal
  const sockB = crearJugador('JugadorB', roomId, false); // secundario

  infoSalas[roomId].sockets.push(sockA, sockB);
}
