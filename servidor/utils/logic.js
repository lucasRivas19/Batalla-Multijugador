// utils/logic.js

function resolverTurno(acciones, estado) {
  const jugadores = Object.keys(acciones);
  const [j1, j2] = jugadores;
  const acc1 = acciones[j1];
  const acc2 = acciones[j2];

  // Estado inicial si no existe
  if (!estado.vidaA) {
    estado = {
      vidaA: 100,
      vidaB: 100,
      energiaA: 100,
      energiaB: 100,
      cooldownA: { atacar: 0, curar: 0 },
      cooldownB: { atacar: 0, curar: 0 },
      turno: 1,
    };
  }

  const log = [`🔹 Resolviendo turno ${estado.turno}`];

  // Configuración de habilidades
  const habilidades = {
    atacar: { costo: 20, daño: 25, curar: 0, vel: 2, cd: 1 },
    curar: { costo: 15, daño: 0, curar: 20, vel: 1, cd: 2 },
    defender: { costo: 10, daño: 0, curar: 0, vel: 3, cd: 1 },
  };

  // Procesar jugadores
  const p1 = { ...acc1, vel: habilidades[acc1.accion].vel };
  const p2 = { ...acc2, vel: habilidades[acc2.accion].vel };

  // Determinar orden (mayor velocidad primero)
  const orden = [p1, p2].sort((a, b) => b.vel - a.vel);

  for (const p of orden) {
    const isP1 = p === p1;
    const acc = habilidades[p.accion];
    const energiaKey = isP1 ? 'energiaA' : 'energiaB';
    const vidaPropia = isP1 ? 'vidaA' : 'vidaB';
    const vidaEnemigo = isP1 ? 'vidaB' : 'vidaA';
    const cooldownKey = isP1 ? 'cooldownA' : 'cooldownB';

    // Verificar energía suficiente
    if (estado[energiaKey] < acc.costo) {
      log.push(`⚠️ ${isP1 ? 'Jugador A' : 'Jugador B'} no tiene energía para ${p.accion}`);
      continue;
    }

    // Verificar cooldown
    if (estado[cooldownKey][p.accion] > 0) {
      log.push(`⏳ ${isP1 ? 'Jugador A' : 'Jugador B'} aún está en cooldown de ${p.accion}`);
      continue;
    }

    // Ejecutar acción
    estado[energiaKey] -= acc.costo;

    if (p.accion === 'atacar') {
      if ((isP1 && acc2.accion !== 'defender') || (!isP1 && acc1.accion !== 'defender')) {
        estado[vidaEnemigo] -= acc.daño;
        log.push(`💥 ${isP1 ? 'A' : 'B'} ataca causando ${acc.daño} de daño.`);
      } else {
        log.push(`🛡️ ${isP1 ? 'A' : 'B'} ataca pero el enemigo se defiende.`);
      }
    }

    if (p.accion === 'curar') {
      estado[vidaPropia] += acc.curar;
      if (estado[vidaPropia] > 100) estado[vidaPropia] = 100;
      log.push(`💚 ${isP1 ? 'A' : 'B'} se cura ${acc.curar} puntos.`);
    }

    if (p.accion === 'defender') {
      log.push(`🛡️ ${isP1 ? 'A' : 'B'} se defiende.`);
    }

    // Aplicar cooldown
    estado[cooldownKey][p.accion] = acc.cd;
  }

  // Reducir cooldowns
  for (const key of Object.keys(estado.cooldownA)) {
    if (estado.cooldownA[key] > 0) estado.cooldownA[key]--;
    if (estado.cooldownB[key] > 0) estado.cooldownB[key]--;
  }

  // Regenerar energía leve por turno
  estado.energiaA = Math.min(estado.energiaA + 10, 100);
  estado.energiaB = Math.min(estado.energiaB + 10, 100);

  estado.turno += 1;

  // Evitar valores negativos
  if (estado.vidaA < 0) estado.vidaA = 0;
  if (estado.vidaB < 0) estado.vidaB = 0;

  const resultado = { estado, log };
  console.log(log.join('\n'));
  return resultado;
}

module.exports = { resolverTurno };
