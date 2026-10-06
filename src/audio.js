// Synthesized sound. Everything is optional: without Web Audio this is a silent stub.

function noop() {}

// Muted by default; only a stored '0' (the player pressed M to turn sound on) starts unmuted.
export function initialMuted(stored) {
  return stored !== '0';
}

export function createAudio() {
  const AC = typeof window !== 'undefined' && (window.AudioContext || window.webkitAudioContext);
  if (!AC) return { unlock: noop, handle: noop, update: noop, toggleMute: () => true, muted: true };

  let ctx = null, master, sfx, muffle, boomBus, engine, sub, engineGain, wind, windFilter, windGain, noiseBuf;
  let muted = true;
  try { muted = initialMuted(window.localStorage.getItem('speed-muted')); } catch { /* ignore */ }
  const lastPlayed = {};
  let duckT = 0;

  function init() {
    ctx = new AC();
    master = ctx.createGain();
    master.gain.value = muted ? 0 : 0.7;
    const comp = ctx.createDynamicsCompressor();
    master.connect(comp).connect(ctx.destination);
    muffle = ctx.createBiquadFilter();
    muffle.type = 'lowpass';
    muffle.frequency.value = 16000;
    sfx = ctx.createGain();
    sfx.connect(muffle).connect(master);
    boomBus = ctx.createGain();
    boomBus.connect(master);

    noiseBuf = ctx.createBuffer(1, ctx.sampleRate * 2, ctx.sampleRate);
    const d = noiseBuf.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;

    engineGain = ctx.createGain();
    engineGain.gain.value = 0;
    const lp = ctx.createBiquadFilter();
    lp.type = 'lowpass'; lp.frequency.value = 700;
    engine = ctx.createOscillator(); engine.type = 'sawtooth'; engine.frequency.value = 50;
    sub = ctx.createOscillator(); sub.type = 'sine'; sub.frequency.value = 25;
    engine.connect(lp); sub.connect(lp); lp.connect(engineGain).connect(sfx);
    engine.start(); sub.start();

    wind = ctx.createBufferSource(); wind.buffer = noiseBuf; wind.loop = true;
    windFilter = ctx.createBiquadFilter(); windFilter.type = 'bandpass'; windFilter.Q.value = 0.8;
    windGain = ctx.createGain(); windGain.gain.value = 0;
    wind.connect(windFilter).connect(windGain).connect(sfx);
    wind.start();
  }

  function env(g, t, a, peak, dur) {
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(peak, t + a);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
  }

  function tone(freq, dur, type = 'sine', vol = 0.2, slideTo = null, bus = sfx, delay = 0) {
    const t = ctx.currentTime + delay;
    const o = ctx.createOscillator(); o.type = type;
    o.frequency.setValueAtTime(freq, t);
    if (slideTo) o.frequency.exponentialRampToValueAtTime(slideTo, t + dur);
    const g = ctx.createGain();
    env(g, t, 0.005, vol, dur);
    o.connect(g).connect(bus);
    o.start(t); o.stop(t + dur + 0.05);
  }

  function noise(dur, freq, vol = 0.3, type = 'lowpass', sweepTo = null, bus = sfx, q = 1) {
    const t = ctx.currentTime;
    const s = ctx.createBufferSource(); s.buffer = noiseBuf;
    s.playbackRate.value = 0.8 + Math.random() * 0.4;
    const f = ctx.createBiquadFilter(); f.type = type; f.Q.value = q;
    f.frequency.setValueAtTime(freq, t);
    if (sweepTo) f.frequency.exponentialRampToValueAtTime(sweepTo, t + dur);
    const g = ctx.createGain();
    env(g, t, 0.01, vol, dur);
    s.connect(f).connect(g).connect(bus);
    s.start(t, Math.random()); s.stop(t + dur + 0.05);
  }

  function throttle(key, gap) {
    const now = ctx.currentTime;
    if (lastPlayed[key] && now - lastPlayed[key] < gap) return false;
    lastPlayed[key] = now;
    return true;
  }

  const SOUNDS = {
    launch: (e) => noise(0.35, 400 + 1200 * Math.min(1.5, e.gauge), 0.25 + 0.15 * Math.min(1, e.gauge), 'bandpass', 3000, sfx, 1.5),
    kill: (e) => throttle('kill', 0.025) && tone(320 + Math.random() * 280 + (e.r > 25 ? -150 : 0), 0.12, 'square', e.r > 25 ? 0.12 : 0.06, 90),
    hit: (e) => e.crit && throttle('crit', 0.05) && tone(1400, 0.18, 'triangle', 0.18, 2200),
    hurt: () => { noise(0.3, 300, 0.5); tone(90, 0.3, 'sawtooth', 0.25, 40); },
    bounce: () => throttle('bounce', 0.08) && tone(160, 0.15, 'square', 0.15, 80),
    crash: () => noise(0.4, 250, 0.5),
    levelup: () => [523, 659, 784].forEach((f, i) => tone(f, 0.14, 'triangle', 0.12, null, sfx, i * 0.06)),
    pickup: (e) => tone(e.kind === 'core' ? 660 : 880, 0.3, 'sine', 0.2, e.kind === 'core' ? 1320 : 1760),
    equip: () => tone(440, 0.15, 'triangle', 0.15, 880),
    coin: () => throttle('coin', 0.04) && tone(1568, 0.08, 'square', 0.05),
    explode: (e) => throttle('explode' + e.cause, 0.05) && noise(0.35, e.cause === 'trail' ? 900 : 500, e.cause === 'trail' ? 0.12 : 0.3),
    shoot: () => throttle('shoot', 0.09) && tone(700, 0.05, 'square', 0.03, 400),
    turret: () => throttle('turret', 0.06) && tone(1800, 0.04, 'square', 0.03, 1200),
    stage: () => { tone(392, 0.25, 'sawtooth', 0.1, 784); tone(587, 0.35, 'triangle', 0.12, 1175, sfx, 0.08); },
    phase: () => tone(110, 1.2, 'sawtooth', 0.12, 220),
    barrier: () => noise(0.25, 2000, 0.15, 'highpass'),
    warp: () => { tone(1400, 0.12, 'sine', 0.12, 300); noise(0.12, 3000, 0.1, 'highpass'); },
    dashReady: () => tone(988, 0.18, 'triangle', 0.1, 1480),
    hyperOpen: () => { tone(330, 0.6, 'sine', 0.12, 110); noise(0.5, 600, 0.12, 'lowpass', 150); },
    sonic: () => {
      // a beat of silence, then everything comes back at once
      duckT = 0.22;
      const t = ctx.currentTime;
      sfx.gain.cancelScheduledValues(t);
      sfx.gain.setValueAtTime(0.0001, t);
      sfx.gain.linearRampToValueAtTime(1, t + 0.9);
      setTimeout(() => {
        noise(1.6, 1800, 1.0, 'lowpass', 60, boomBus);
        tone(95, 1.4, 'sine', 0.9, 28, boomBus);
        tone(190, 0.5, 'sawtooth', 0.25, 40, boomBus);
      }, 200);
    },
    end: (e) => {
      if (e.state === 'won') [523, 659, 784, 1047].forEach((f, i) => tone(f, 0.4, 'triangle', 0.18, null, boomBus, i * 0.12));
      else tone(220, 1.2, 'sawtooth', 0.15, 55, boomBus);
    },
  };

  return {
    get muted() { return muted; },
    unlock() {
      try {
        if (!ctx) init();
        if (ctx.state === 'suspended') ctx.resume();
      } catch { /* audio unavailable */ }
    },
    toggleMute() {
      muted = !muted;
      try { window.localStorage.setItem('speed-muted', muted ? '1' : '0'); } catch { /* ignore */ }
      if (master) master.gain.value = muted ? 0 : 0.7;
      return muted;
    },
    handle(events) {
      if (!ctx || ctx.state !== 'running') return;
      for (const e of events) {
        const f = SOUNDS[e.type];
        if (f) try { f(e); } catch { /* ignore */ }
      }
    },
    // Continuous layers: engine pitch, wind, and the high-speed fade toward silence.
    update(game, dt) {
      if (!ctx || ctx.state !== 'running' || !game) return;
      const t = ctx.currentTime;
      const sh = game.ship;
      const sp = Math.hypot(sh.vx, sh.vy);
      const ratio = sp / game.stats.maxSpeed;
      const live = game.state === 'play';
      engine.frequency.setTargetAtTime(45 + sp * 0.05, t, 0.08);
      sub.frequency.setTargetAtTime(22 + sp * 0.025, t, 0.08);
      engineGain.gain.setTargetAtTime(live ? 0.05 + 0.08 * Math.min(1.2, ratio) : 0, t, 0.1);
      windFilter.frequency.setTargetAtTime(250 + sp * 0.9, t, 0.1);
      windGain.gain.setTargetAtTime(live ? Math.min(0.35, sp / 4000) : 0, t, 0.1);
      // approaching max speed the world goes quiet
      const k = Math.max(0, Math.min(1, (ratio - 0.6) / 0.38));
      muffle.frequency.setTargetAtTime(16000 * Math.pow(0.02, k), t, 0.15);
      if (duckT > 0) duckT -= dt;
      else sfx.gain.setTargetAtTime(1 - 0.88 * k, t, 0.2);
    },
  };
}
