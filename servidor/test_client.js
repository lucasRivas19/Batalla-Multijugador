// test-client.js
const io = require("socket.io-client");

// Cambiar el roomId si querés separar partidas
const roomId = "sala1";

// Cambiar nombre del jugador (A o B)
const jugador = process.argv[2] || "JugadorA";

const socket = io("http://localhost:3000", {
  transports: ["websocket"],
});

socket.on("connect", () => {
  console.log(`🟢 ${jugador} conectado al servidor`);
  socket.emit("unirse_partida", roomId);

  // Enviar acciones automáticamente cada 3 segundos
  const acciones = ["atacar", "defender", "curar"];
  setInterval(() => {
    const accion = acciones[Math.floor(Math.random() * acciones.length)];
    console.log(`⚔️ ${jugador} elige acción: ${accion}`);
    socket.emit("accion", { roomId, jugador, accion });
  }, 3000);
});

socket.on("resultado_turno", (data) => {
  console.log("🎯 Resultado recibido:", data);
});

socket.on("disconnect", () => {
  console.log(`🔴 ${jugador} desconectado`);
});
