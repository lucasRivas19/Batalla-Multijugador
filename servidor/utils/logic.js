// utils/logic.js
function resolverTurno(acciones, estado) {
    const jugadores = Object.keys(acciones);
    const [j1, j2] = jugadores;
    const acc1 = acciones[j1];
    const acc2 = acciones[j2];
  
    // Estado inicial si no existe
    if (!estado.vidaA) {
      estado = { vidaA: 100, vidaB: 100, turno: 1 };
    }
  
    // Resolver las acciones (turnos simultáneos)
    const resultado = { estado: { ...estado }, log: [] };
  
    // Reglas simples
    const daño = { atacar: 20, curar: -10, defender: 0 };
    const vel = { atacar: 2, curar: 1, defender: 3 };
  
    const p1 = { ...acc1, vel: vel[acc1.accion] };
    const p2 = { ...acc2, vel: vel[acc2.accion] };
  
    // Determinar orden de ejecución
    const orden = [p1, p2].sort((a, b) => b.vel - a.vel);
  
    for (const p of orden) {
      if (p === p1) {
        if (p.accion === 'atacar' && acc2.accion !== 'defender') estado.vidaB -= daño.atacar;
        if (p.accion === 'curar') estado.vidaA -= daño.curar;
      } else {
        if (p.accion === 'atacar' && acc1.accion !== 'defender') estado.vidaA -= daño.atacar;
        if (p.accion === 'curar') estado.vidaB -= daño.curar;
      }
    }
  
    estado.turno += 1;
    resultado.estado = estado;
    resultado.log.push(`Turno ${estado.turno} resuelto`);
    return resultado;
  }
  
  module.exports = { resolverTurno };
  