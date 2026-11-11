## 鳳凰の着地・突入に使う粒と燃え残りの計算。
## pixelFX src/core/sim.js（Copyright 2026 Hugo Duprez、MIT）の移植。
## ライセンスと帰属は assets/ui/rewards/pixelfx_LICENSE.txt・pixelfx_NOTICE.txt を参照。
extends RefCounted

var _raster := SpeedFxRaster.new()

const SPARK := 0
const EMBER := 7
const SMOKE := 8
const FIRE := 9
const SMOKES := 1
const BIG := 2
const BACK := 4
const MASK32 := 0xffffffff

var particles: Array[Dictionary] = []
var blazes: Array[Dictionary] = []
var time := 0.0
var scorch_radius := 0
var scorch_size := 0
var scorch := PackedFloat32Array()
var _seed := 23
var _trail_seed := 5

func _next(trail := false) -> float:
	var s := _trail_seed if trail else _seed
	s = (s + 0x6d2b79f5) & MASK32
	if trail:
		_trail_seed = s
	else:
		_seed = s
	var t := ((s ^ (s >> 15)) * (s | 1)) & MASK32
	t = (t ^ ((t + (((t ^ (t >> 7)) * (t | 61)) & MASK32)) & MASK32)) & MASK32
	return float((t ^ (t >> 14)) & MASK32) / 4294967296.0

func _range(a: float, b: float, trail := false) -> float:
	return a + (b - a) * _next(trail)

func _spawn(kind: int, pos: Vector2, velocity: Vector2, life: float, color: Color = Color.WHITE, size := 1.0, delay := 0.0, flags := 0) -> void:
	particles.append({"kind": kind, "pos": pos, "velocity": velocity, "life": life, "max": life,
		"color": color, "size": size, "seed": _next() * 100.0, "delay": delay, "flags": flags})

func burst(radius: float, smoke_color: Color, ember_color: Color) -> void:
	for i in 6:
		_spawn(FIRE, Vector2(_range(-3, 3), _range(-3, 3)), Vector2(_range(-20, 20), _range(-50, -10)), _range(0.22, 0.34), Color.TRANSPARENT, _range(radius * 0.38, radius * 0.5))
	for i in 46:
		var angle := _range(0, TAU)
		var d := _range(0, radius * 0.3)
		var speed := _range(0.35, 1) * radius * 5
		_spawn(FIRE, Vector2(cos(angle) * d, sin(angle) * d * 0.9), Vector2(cos(angle) * speed, sin(angle) * speed * 0.85 - 30), _range(0.55, 1.1), Color.TRANSPARENT, _range(radius * 0.16, radius * 0.32), _range(0, 0.06), SMOKES | BIG if _next() < 0.5 else 0)
	for i in 8:
		_spawn(FIRE, Vector2(_range(-radius * 0.3, radius * 0.3), _range(-radius * 0.2, radius * 0.2)), Vector2(_range(-10, 10), _range(-150, -90)), _range(0.8, 1.2), Color.TRANSPARENT, _range(radius * 0.2, radius * 0.3), _range(0.05, 0.15), SMOKES | BIG)
	for i in 90:
		var angle := _range(0, TAU)
		var speed := _range(120, 330)
		_spawn(SPARK, Vector2.ZERO, Vector2(cos(angle) * speed, sin(angle) * speed * 0.85 - 60), _range(0.2, 0.6))
	for i in 40:
		var angle := _range(0, TAU)
		var speed := _range(30, 140)
		_spawn(EMBER, Vector2(cos(angle) * radius * 0.4, sin(angle) * radius * 0.36), Vector2(cos(angle) * speed, sin(angle) * speed - 60), _range(1.0, 2.2), ember_color)
	for i in 10:
		var angle := _range(0, TAU)
		var d := _range(0.25, 0.85) * radius
		var life := _range(0.9, 1.8)
		var power := _range(0.6, 1.0)
		blazes.append({"pos": Vector2(cos(angle) * d, sin(angle) * d * 0.9), "life": life, "max": life, "acc": _next(), "power": power})
	for i in 12:
		var angle := _range(0, TAU)
		var d := _range(0.1, 0.6) * radius
		_spawn(SMOKE, Vector2(cos(angle) * d, sin(angle) * d), Vector2(cos(angle) * 25, sin(angle) * 18 - 30), _range(1.6, 2.6), smoke_color, _range(radius * 0.22, radius * 0.36), _range(0.15, 0.45), BIG)
	scorch_radius = ceili(radius * 1.8)
	scorch_size = scorch_radius * 2 + 1
	scorch.resize(scorch_size * scorch_size)
	scorch.fill(0.0)

func trail(pos: Vector2, direction: Vector2) -> void:
	for i in 7:
		var j := _range(0, 1, true)
		_spawn(FIRE, pos - direction * j * 6.0 + Vector2(_range(-3, 3, true), _range(-3, 3, true)), Vector2(-direction.x * _range(20, 60, true) + _range(-15, 15, true), -direction.y * _range(20, 60, true) + _range(-25, 0, true)), _range(0.12, 0.3, true), Color.TRANSPARENT, _range(1.2, 3.4, true), 0.0, SMOKES if _next(true) < 0.25 else 0)
	if _next(true) < 0.7:
		_spawn(SPARK, pos, Vector2(-direction.x * _range(60, 160, true) + _range(-40, 40, true), -direction.y * _range(60, 160, true) + _range(-40, 40, true)), _range(0.15, 0.35, true))

func advance(dt: float, stamp_scorch: bool) -> void:
	time += dt
	for i in range(particles.size() - 1, -1, -1):
		var p := particles[i]
		if p.delay > 0:
			p.delay -= dt
			continue
		p.life -= dt
		if p.life <= 0:
			if p.kind == FIRE and (int(p.flags) & SMOKES) != 0:
				var big: bool = (p.flags & BIG) != 0
				_spawn(SMOKE, p.pos, p.velocity * 0.6 - Vector2(0, 6), _range(1.3, 2.3) if big else _range(0.8, 1.4), Color.TRANSPARENT, p.size * (0.85 if big else 0.7), 0.0, BIG if big else 0)
			particles.remove_at(i)
			continue
		var velocity: Vector2 = p.velocity
		match p.kind:
			FIRE:
				velocity.y -= 95 * dt
				velocity.x += sin(time * 17 + p.seed) * 30 * dt
				velocity.x -= velocity.x * 5 * dt
				velocity.y -= velocity.y * 3.2 * dt
			SPARK:
				velocity.y += 950 * 0.45 * dt
				velocity -= velocity * 2.2 * dt
			EMBER:
				velocity.y += (-30 + sin(time * 3 + p.seed) * 20) * dt
				velocity.x += cos(time * 2.3 + p.seed) * 45 * dt
				velocity -= velocity * 1.6 * dt
			SMOKE:
				velocity.y -= (23 if (int(p.flags) & BIG) != 0 else 16) * dt
				velocity.x += sin(time * 1.3 + p.seed) * 8 * dt
				velocity.x -= velocity.x * 1.6 * dt
				velocity.y -= velocity.y * 1.2 * dt
		p.velocity = velocity
		p.pos += velocity * dt
	for i in range(blazes.size() - 1, -1, -1):
		var b := blazes[i]
		b.life -= dt
		if b.life <= 0:
			blazes.remove_at(i)
			continue
		var k: float = b.life / b.max
		var intensity: float = b.power * (1.0 if k > 0.7 else 0.35 + k / 0.7 * 0.65)
		b.acc += dt * (6 + 16 * intensity)
		while b.acc > 1:
			b.acc -= 1
			var s := _range(1.2, 2.8) * intensity
			_spawn(FIRE, b.pos + Vector2(_range(-1.5, 1.5), -s * 0.6), Vector2(_range(-6, 6), _range(-30, -12)), _range(0.28, 0.6), Color.TRANSPARENT, s, 0.0, BACK | (SMOKES if _next() < 0.3 else 0))
			if _next() < 0.06:
				_spawn(EMBER, b.pos - Vector2(0, 1.5), Vector2(_range(-15, 15), _range(-45, -15)), _range(0.6, 1.4), Color("#ff8a2a"), 1.0, 0.0, BACK)
	if stamp_scorch:
		_stamp_scorch()

func _stamp_scorch() -> void:
	scorch = _raster.phoenix_stamp_scorch(scorch,scorch_size,scorch_radius,particles)
