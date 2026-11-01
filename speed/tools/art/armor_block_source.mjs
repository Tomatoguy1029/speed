// Adopted SPEED armor-deflection B. Upstream pixelfx a84159688af3ca37a4be05a0d422b94451b2e24e.
// The source is authoring-only; runtime plays the committed sheet.
export function armorBlock(core) {
  const { Particles, Lights, P, Rng, fit, TAU, WHITE } = core;
  // Adopted B revision. Parry fan without gravity; preserve ramp, seeds, lifetime, delay and isotropic drag.
  // The star's key frames and the spark spray are adapted from Sprite Fusion's open-source impact
  // (https://www.spritefusion.com/pixel-art-vfx/impact), MIT License, Copyright (c) 2026 Hugo Duprez.

  const meta = {
    name: "Parry",
    desc: "A compact white-blue fan of straight sparks and motes, without a ring, star, crossing lines or gravity.",
    tags: ["impact", "parry", "block", "clash", "sword", "metal", "sparks", "one-shot"],
    size: [200, 112],
    origin: [100, 96],
    duration: 1,
    loop: false,
    fps: 30,
    bg: "ground",
    options: { palette: ["#1d2d3d", "#365065", "#678b9d", "#9fc1ce", "#daeff2", "#f3fbfc", "#ffffff"], height: 0, seed: 11 },
  };

  function create(o) {
    const C = fit(o.palette, 7), R = new Rng(o.seed), X = 0, Y = -o.height, floor = () => Infinity;
    const ps = new Particles({ rng: R, ground: floor, sparks: [C[4], C[4], C[3], C[2]] });
    const lights = new Lights();
    // The removed star (16), ring (18) and crossed edges (2) consumed 36 RNG draws.
    // Preserve the original particle layout without constructing those unused motifs.
    for (let i = 0; i < 36; i++) R.next();

    lights.add(X, Y, 18, C[4], 0.3, 0.15);
    lights.add(X, Y, 6, WHITE, 0.4, 0.04);
    // The fan keeps its initial direction. update() applies only isotropic drag, never gravity.
    for (let i = 0; i < 24; i++) {
      const s = i % 2 ? 1 : -1, a = -Math.PI / 2 + s * R.range(0.3, 1.3), v = R.range(90, 210);
      ps.spawn(P.SPARK, X + s * R.range(1, 3), Y, Math.cos(a) * v, Math.sin(a) * v, R.range(0.22, 0.5), WHITE, 1, i > 17 ? R.range(0.02, 0.07) : 0);
    }
    for (let i = 0; i < 8; i++) {
      const a = R.range(0, TAU), v = R.range(40, 110);
      ps.spawn(P.MOTE, X, Y, Math.cos(a) * v, Math.sin(a) * v - 20, R.range(0.3, 0.55), R.pick([C[5], C[6]]), 0.6, R.range(0, 0.04));
    }

    let t = 0;
    return {
      update(dt) {
        t += dt;
        // This preview uses only SPARK and MOTE. Keep their existing isotropic drag,
        // lifetime, delayed emission and draw recipe; remove the SPARK gravity force.
        // Multiplying vx and vy by one scalar preserves the initial ray exactly.
        ps.t += dt;
        for (let i = ps.list.length - 1; i >= 0; i--) {
          const q = ps.list[i];
          if (q.delay > 0) { q.delay -= dt; continue; }
          if ((q.life -= dt) <= 0) { ps.list.splice(i, 1); continue; }
          const drag = q.k === P.SPARK ? 2.2 : 0.6;
          const decay = 1 - drag * dt;
          q.vx *= decay;
          q.vy *= decay;
          q.x += q.vx * dt;
          q.y += q.vy * dt;
        }
        lights.update(dt);
      },
      draw(p) {
        ps.draw(p);
        const pop = Math.exp(-t / 0.05);
        if (pop > 0.02) {
          p.glow(X, Y, 12, C[4], 0.3 * pop);
          p.glow(X, Y, 4, WHITE, 0.3 * pop);
        }
        lights.draw(p);
      },
    };
  }

  return { meta, create };
}
