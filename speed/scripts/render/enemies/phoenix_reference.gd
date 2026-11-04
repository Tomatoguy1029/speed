## 鳳凰の予兆から着地後までを、敵・攻撃ごとに保持して描く。
extends RefCounted

const SETTINGS := preload("res://data/visuals/fx_reference.tres")
const PARTICLES := preload("res://scripts/render/enemies/phoenix_particles.gd")
const PARTICLE_DRAW := preload("res://scripts/render/enemies/phoenix_particle_draw.gd")
const SHADOW := preload("res://scripts/render/enemies/phoenix_shadow.gd")
const TELEGRAPH := preload("res://scripts/render/enemies/phoenix_telegraph.gd")
const TICK := 1.0 / 60.0

var _settings: Dictionary
var _draw = PARTICLE_DRAW.new()
var _telegraph = TELEGRAPH.new()
var _actors := {}
var _impacts := {}
var _seen := {}
var _last_world_time := -1.0
var _shadow_parent: Node
var _shadows := {}

func _init() -> void:
	_settings = SETTINGS.for_id("G11-phoenix")
	_draw.configure(Color(_settings.color))

## 親はカメラ変換のかかるワールド層で、論理画素の背面より奥に置く。
func setup_shadow(parent: Node) -> void:
	_shadow_parent = parent

## rows と impacts は戦闘の値型フレーム。画像への反映は共通の描画層が行う。
func render(rows: Array, impacts: Array, canvas, dt: float, world_time: float, logical_pixel_size: float) -> void:
	if _last_world_time >= 0 and world_time < _last_world_time:
		_actors.clear()
		for shadow in _shadows.values(): shadow.queue_free()
		_shadows.clear()
		_impacts.clear()
		_seen.clear()
	_last_world_time = world_time
	var present := {}
	for row: Dictionary in rows:
		var id: int = row.id
		present[id] = true
		if not _actors.has(id):
			var sim = PARTICLES.new()
			sim.time = float(row.retreat_time) + float(row.telegraph_elapsed)
			_actors[id] = {"simulation": sim, "anchor": row.anchor, "pos": row.pos, "previous": row.pos,
				"row": row, "accum": 0.0, "tick": world_time - dt, "burst_time": INF, "fired": false}
		var actor: Dictionary = _actors[id]
		actor.previous = actor.pos
		actor.pos = row.pos
		actor.anchor = row.anchor
		actor.row = row
		if _shadow_parent != null:
			if not _shadows.has(id):
				var created_shadow = SHADOW.new()
				_shadow_parent.add_child(created_shadow)
				_shadows[id] = created_shadow
			var shadow = _shadows[id]
			var charge: float = float(row.telegraph_progress) if row.mode == "windup" else 1.0
			var dive: float = float(row.dive_progress) if row.mode == "dash" else 0.0
			var pool: Array[Color] = [_draw.colorize(Color("#ff8246")), _draw.colorize(Color("#d24632")), _draw.colorize(Color("#781428"))]
			shadow.apply(row.anchor, row.sprite_radius, row.sprite_angle, row.impact_radius, charge, dive, float(_settings.size), float(_settings.intensity), canvas.world_scale * logical_pixel_size, pool)
	for id in _shadows.keys():
		if not present.has(id):
			_shadows[id].queue_free()
			_shadows.erase(id)
	for impact: Dictionary in impacts:
		var order: int = impact.order
		if _seen.has(order):
			continue
		_seen[order] = world_time
		var id: int = impact.owner_id
		var effect: Dictionary
		if _actors.has(id):
			effect = _actors[id]
			effect.previous = effect.pos
			effect.pos = impact.pos
			_actors.erase(id)
		else:
			var sim = PARTICLES.new()
			effect = {"simulation": sim, "anchor": impact.pos, "pos": impact.pos, "previous": impact.pos,
				"row": {}, "accum": 0.0, "tick": world_time - maxf(dt, float(impact.age)), "fired": false}
		effect.anchor = impact.pos
		effect.radius = float(impact.radius)
		effect.burst_time = world_time - float(impact.age)
		_impacts[order] = effect
	for id in _actors.keys():
		var actor: Dictionary = _actors[id]
		if not present.has(id):
			# 敵の消失後も突入中に生まれた粒は寿命まで残す。
			actor.row = {}
			if actor.simulation.particles.is_empty() and actor.simulation.blazes.is_empty():
				_actors.erase(id)
				continue
		_advance(actor, canvas.world_scale, dt, world_time)
		_draw_actor(actor, canvas, world_time, logical_pixel_size)
	for order in _impacts.keys():
		var effect: Dictionary = _impacts[order]
		_advance(effect, canvas.world_scale, dt, world_time)
		_draw_effect(effect, canvas, world_time, logical_pixel_size)
		var age: float = world_time - effect.burst_time
		if age >= 3.2 * float(_settings.timing) and effect.simulation.particles.is_empty() and effect.simulation.blazes.is_empty():
			_impacts.erase(order)
	for order in _seen.keys():
		if world_time - float(_seen[order]) > 5.0:
			_seen.erase(order)

func _advance(effect: Dictionary, scale: float, dt: float, world_time: float) -> void:
	var sim = effect.simulation
	effect.accum += maxf(0.0, dt)
	while effect.accum >= TICK:
		effect.accum -= TICK
		effect.tick += TICK
		var row: Dictionary = effect.row
		var is_dash: bool = not row.is_empty() and row.mode == "dash"
		var will_land: bool = not effect.fired and effect.tick >= effect.burst_time
		if (is_dash and not effect.fired) or will_land:
			var fraction := clampf(1.0 - (world_time - float(effect.tick)) / maxf(dt, TICK), 0.0, 1.0)
			var pos: Vector2 = effect.previous.lerp(effect.pos, fraction)
			if will_land:
				pos = effect.anchor
			var direction: Vector2 = (effect.anchor - pos).normalized()
			sim.trail((pos - effect.anchor) * scale, direction)
		if will_land:
			sim.burst(effect.radius * scale, _draw.smoke_color, _draw.spark_colors()[1])
			effect.fired = true
		var age: float = effect.tick - effect.burst_time
		sim.advance(TICK, effect.fired and age < 1.2)

func _draw_actor(effect: Dictionary, canvas, clock: float, pixel_size: float) -> void:
	var row: Dictionary = effect.row
	var center: Vector2 = canvas.to_logical(effect.anchor)
	if not row.is_empty():
		var k: float = float(row.telegraph_progress) if row.mode == "windup" else 1.0
		canvas.back.place(center.x, center.y)
		canvas.front.place(center.x, center.y)
		_telegraph.draw(canvas.back, canvas.front, float(row.impact_radius) * canvas.world_scale, float(row.telegraph_elapsed), clock, k, float(_settings.intensity), _draw.fire_colors(), _draw.spark_colors())
	if not effect.simulation.particles.is_empty():
		canvas.back.place(center.x, center.y)
		_draw.draw_back(canvas.back, effect.simulation, clock, 0.0, float(_settings.timing), pixel_size)
		canvas.front.place(center.x, center.y)
		_draw.draw_front(canvas.front, effect.simulation, clock, 0.0, pixel_size)
	canvas.back.place(0, 0)
	canvas.front.place(0, 0)

func _draw_effect(effect: Dictionary, canvas, clock: float, pixel_size: float) -> void:
	if not effect.fired:
		return
	var center: Vector2 = canvas.to_logical(effect.anchor)
	var age: float = maxf(0.0, clock - float(effect.burst_time))
	canvas.back.place(center.x, center.y)
	_draw.draw_back(canvas.back, effect.simulation, clock, age, float(_settings.timing), pixel_size)
	canvas.front.place(center.x, center.y)
	_draw.draw_front(canvas.front, effect.simulation, clock, age, pixel_size)
	var radius: float = effect.radius * canvas.world_scale
	if age < 0.12:
		canvas.front.glow(0, 0, radius * 1.3, _draw.colorize(Color("#fff1c4")), (1 - age / 0.12) * float(_settings.intensity))
		canvas.front.glow(0, 0, radius * 0.6, Color.WHITE, (1 - age / 0.12) * 0.8 * float(_settings.intensity))
	if age < 0.8:
		canvas.front.glow(0, 0, radius * 1.1, _draw.colorize(Color("#ff6a3a")), 0.35 * (1 - age / 0.8) * float(_settings.intensity))
	canvas.back.place(0, 0)
	canvas.front.place(0, 0)
