// server.js
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const { resolverTurno } = require('./utils/logic');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: "*" } // permite conexiones desde Flutter
});

let partidas = {}; // { roomId: { jugadores: [], acciones: {}, estado: {} } }

io.on('connection', (socket) => {
  console.log(`🟢 Jugador conectado: ${socket.id}`);

  socket.on('unirse_partida', (roomId) => {
    socket.join(roomId);
    if (!partidas[roomId]) partidas[roomId] = { jugadores: [], acciones: {}, estado: {} };
    partidas[roomId].jugadores.push(socket.id);
    console.log(`Jugador ${socket.id} unido a partida ${roomId}`);
  });

  socket.on('accion', ({ roomId, jugador, accion }) => {
    const partida = partidas[roomId];
    if (!partida) return;

    partida.acciones[jugador] = { accion, timestamp: Date.now() };
    console.log(`Acción recibida de ${jugador}: ${accion}`);

    // Si ambos jugadores ya enviaron su acción
    if (Object.keys(partida.acciones).length === 2) {
      const resultado = resolverTurno(partida.acciones, partida.estado);
      partida.estado = resultado.estado;
      partida.acciones = {}; // reset turno
      io.to(roomId).emit('resultado_turno', resultado);
    }
  });

  socket.on('disconnect', () => {
    console.log(`🔴 Jugador desconectado: ${socket.id}`);
  });
});

server.listen(3000, () => console.log('🚀 Servidor corriendo en puerto 3000'));
