## 描画の流れ（設計書 10）。ゲームの状態とイベントを読むだけで、状態は書き換えない。
##
## World の下に層（DrawLayer）を作り、層ごとに描く。カメラは RunManager が求めた位置とズームに合わせる。
## 見た目は仮の図形（企画書 16）。見分けのルール（仕様書 15）だけは守る。
class_name RenderManager
extends Node

const XP_COLOR := Color("#b8a0ff")
const XP_OUTLINE := Color("#39265e")

@export var world_path: NodePath
@export var camera_path: NodePath

var run: RunManager
var state: RunState
var cfg: GameConfig

var _layers: Dictionary = {}
## 形ごとのまとめた描画（敵・経験値の結晶）
var _batches: Dictionary = {}
var _camera: Camera2D
var _font: Font

# 演出（実秒で進む。ポーズ中・3択の間は止まる）
var rings: Array = []
var particles: Array = []
var texts: Array = []
var ghosts: Array = []
var impacts: Array = []
var trails: Array = []
var beams: Array = []
var bolts: Array = []
var shake := 0.0
var flash := 0.0
var _stars: PackedVector3Array

func _ready() -> void:
	run = get_node("../RunManager") as RunManager
	state = run.state
	cfg = run.cfg
	_font = ThemeDB.fallback_font
	_camera = get_node(camera_path) as Camera2D
	var world := get_node(world_path)
	for name in ["background", "field", "pickups", "enemies", "projectiles", "path", "fx", "dim", "ship", "top"]:
		var layer := DrawLayer.new()
		layer.name = name.capitalize().replace(" ", "")
		layer.draw_fn = Callable(self, "_draw_" + name)
		world.add_child(layer)
		_layers[name] = layer
	_build_batches()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 400:
		_stars.append(Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(0.2, 1.0)))
	run.frame_events.connect(_on_events)

## 敵の形ごと・目・経験値の結晶の MultiMesh を作り、それぞれの層の子に置く。
func _build_batches() -> void:
	var shapes := {
		&"orb": InstanceBatch.circle_points(16),
		&"blob": InstanceBatch.circle_points(14),
		&"dart": PackedVector2Array([Vector2(1.2, 0), Vector2(-0.8, 0.9), Vector2(-0.4, 0), Vector2(-0.8, -0.9)]),
		&"ship": PackedVector2Array([Vector2(1.4, 0), Vector2(-0.8, 0.9), Vector2(-0.4, 0), Vector2(-0.8, -0.9)]),
		&"hex": InstanceBatch.circle_points(6),
		&"diamond": PackedVector2Array([Vector2(1, 0), Vector2(0, 0.7), Vector2(-1, 0), Vector2(0, -0.7)]),
		&"rock": PackedVector2Array([Vector2(1, 0), Vector2(0.62, 0.7), Vector2(0.05, 0.92), Vector2(-0.6, 0.72), Vector2(-0.95, 0.15), Vector2(-0.8, -0.5), Vector2(-0.2, -0.93), Vector2(0.5, -0.82)]),
	}
	for key in shapes:
		var b := InstanceBatch.new()
		b.setup_polygon(shapes[key])
		_layers.enemies.add_child(b)
		_batches[key] = b
	var eye := InstanceBatch.new()
	eye.setup_polygon(InstanceBatch.circle_points(8))
	_layers.enemies.add_child(eye)
	_batches[&"eye"] = eye
	var gem := InstanceBatch.new()
	gem.setup_polygon(PackedVector2Array([Vector2(0, -1.4), Vector2(1, 0), Vector2(0, 1.4), Vector2(-1, 0)]))
	_layers.pickups.add_child(gem)
	_batches[&"gem"] = gem

func _process(delta: float) -> void:
	var phase := state.phase
	var frozen := phase == RunState.Phase.PAUSED or phase == RunState.Phase.LEVELUP \
		or (phase == RunState.Phase.DYING and run.sequence_t < cfg.death_freeze_time)
	var dt := 0.0 if frozen else delta
	_update_fx(dt)
	var offset := Vector2.ZERO
	if shake > 0.0 and phase != RunState.Phase.DYING:
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake / maxf(state.camera_zoom, 0.01)
	_camera.position = state.view_center + offset
	_camera.zoom = Vector2(state.camera_zoom, state.camera_zoom)
	for layer in _layers.values():
		layer.queue_redraw()

# ── イベント → 演出 ───────────────────────────────────────────────

func _on_events(events: Array[Dictionary]) -> void:
	for ev in events:
		match ev.type:
			&"ring":
				_ring(ev.pos, ev.radius, ev.color, ev.life)
			&"explode":
				_ring(ev.pos, ev.radius, ev.color, ev.life)
			&"text":
				_text(ev.pos, ev.text, ev.color, ev.get("size", 16))
			&"kill":
				var n := 6 + roundi(ev.r / 3.0)
				_burst(ev.pos, ev.color, n, ev.get("dir", Vector2.ZERO), 260.0 + ev.r * 4.0)
				if ev.r > 25.0:
					shake = maxf(shake, 8.0)
				elif ev.cause == &"ram":
					shake = maxf(shake, 5.0)
			&"block_impact":
				_sparks(ev.pos, ev.normal, cfg.block_spark_count, Color("#ffd28a"))
				impacts.append({"pos": ev.enemy_pos, "r": ev.r, "dir": ev.normal, "life": cfg.block_impact_life, "max": cfg.block_impact_life, "color": Color("#ffe9a8")})
			&"weak_impact":
				var d: Vector2 = (ev.pos - ev.enemy_pos).normalized()
				_sparks(ev.pos, d, cfg.weak_flame_count, Color("#ff6a2a"))
				impacts.append({"pos": ev.enemy_pos, "r": ev.r, "dir": d, "life": cfg.weak_impact_life, "max": cfg.weak_impact_life, "color": Color("#ff5a2a")})
			&"bounce":
				shake = maxf(shake, 10.0)
			&"crash":
				shake = maxf(shake, 16.0)
			&"warp":
				ghosts.append({"from": ev.from, "to": ev.to, "life": 0.18, "max": 0.18})
			&"beam":
				beams.append({"from": ev.from, "to": ev.to, "width": ev.width, "life": 0.4, "max": 0.4})
			&"bolt":
				bolts.append({"points": ev.points, "life": 0.22, "max": 0.22})
				if bolts.size() > 80:
					bolts.pop_front()
			&"debris_trail":
				trails.append({"points": ev.points, "color": ev.color, "life": cfg.corpse_trail_life, "max": cfg.corpse_trail_life})
			&"sonic":
				flash = maxf(flash, 0.25)
				shake = maxf(shake, 10.0)
			&"boss_spawn":
				shake = maxf(shake, 8.0)
			&"boss_explode":
				flash = 1.0
				shake = 30.0
				_burst(ev.pos, Color("#ff526e"), 120, Vector2.ZERO, 900.0)
			&"ship_explode":
				_burst(ev.pos, Color("#9fe8ff"), 60, Vector2.ZERO, 500.0)

func _ring(p: Vector2, radius: float, color: Color, life: float) -> void:
	if rings.size() > 80:
		rings.pop_front()
	rings.append({"pos": p, "radius": radius, "color": color, "life": life, "max": life})

func _text(p: Vector2, s: String, color: Color, size: int) -> void:
	if texts.size() > 40:
		texts.pop_front()
	texts.append({"pos": p, "text": s, "color": color, "size": size, "life": 0.9 if size > 16 else 0.7})

func _burst(p: Vector2, color: Color, n: int, dir: Vector2, speed: float) -> void:
	if particles.size() > 1600:
		return
	for i in n:
		var a := randf() * TAU
		var s := speed * (0.3 + randf())
		particles.append({"pos": p, "vel": Vector2.from_angle(a) * s * 0.6 + dir * s * 0.8,
			"life": 0.5 + randf() * 0.4, "max": 0.9, "color": color, "size": 2.0 + randf() * 4.0})

func _sparks(p: Vector2, normal: Vector2, n: int, color: Color) -> void:
	var side := Vector2(-normal.y, normal.x)
	for i in n:
		var s := 250.0 + randf() * 450.0
		var dir := (side * (1.0 if i % 2 == 0 else -1.0) * randf_range(0.4, 1.0) + normal * randf_range(0.0, 0.8)).normalized()
		particles.append({"pos": p, "vel": dir * s, "life": 0.25 + randf() * 0.2, "max": 0.45, "color": color, "size": 2.0 + randf() * 2.0})

func _update_fx(dt: float) -> void:
	shake = maxf(0.0, shake - dt * 40.0)
	flash = maxf(0.0, flash - dt * 2.0)
	for p in particles:
		p.pos += p.vel * dt
		p.vel *= 1.0 - 2.5 * dt
		p.life -= dt
	particles = particles.filter(func(p): return p.life > 0.0)
	for list in [rings, texts, ghosts, impacts, trails, beams, bolts]:
		for f in list:
			f.life -= dt
	for t in texts:
		t.pos.y -= 40.0 * dt
	rings = rings.filter(func(f): return f.life > 0.0)
	texts = texts.filter(func(f): return f.life > 0.0)
	ghosts = ghosts.filter(func(f): return f.life > 0.0)
	impacts = impacts.filter(func(f): return f.life > 0.0)
	trails = trails.filter(func(f): return f.life > 0.0)
	beams = beams.filter(func(f): return f.life > 0.0)
	bolts = bolts.filter(func(f): return f.life > 0.0)

# ── 層ごとの描画 ─────────────────────────────────────────────────

func _px(px: float) -> float:
	return px / maxf(state.camera_zoom, 0.01)

func _draw_background(c: CanvasItem) -> void:
	var view := state.view_rect().grow(200.0)
	c.draw_rect(view, Color(0.02, 0.03, 0.07))
	var half := state.view_half
	for s in _stars:
		var par := s.z * 0.3
		var p := state.view_center * (1.0 - par)
		var w := half * 2.4
		var sp := Vector2(fposmod(s.x * 5000.0 - p.x, w.x * 2.0) - w.x, fposmod(s.y * 5000.0 - p.y, w.y * 2.0) - w.y)
		c.draw_circle(state.view_center + sp * 0.5, _px(1.2 * s.z), Color(0.7, 0.8, 1.0, 0.25 + 0.5 * s.z))

func _draw_field(c: CanvasItem) -> void:
	var f := run.field
	var view := state.view_rect().grow(700.0)
	for d in f.dust:
		var center := Vector2(d.x, d.y)
		if view.has_point(center) or view.grow(d.z).has_point(center):
			c.draw_circle(center, d.z, Color(0.4, 0.35, 0.55, 0.08))
	c.draw_arc(Vector2.ZERO, cfg.field_radius, 0, TAU, 256, Color(1.0, 0.4, 0.4, 0.35), _px(2.0))
	for b in f.bodies:
		var col := Color("#3b4d8a") if b.is_planet else Color("#55607a")
		c.draw_circle(b.pos, b.r, col)
		c.draw_arc(b.pos, b.r, 0, TAU, 96, col.lightened(0.35), _px(2.0))

func _draw_pickups(c: CanvasItem) -> void:
	var p := run.pickups
	var view := state.view_rect().grow(60.0)
	# 経験値の結晶：画面上で最低 8px の高さ（仕様書 15）
	var gs := maxf(5.0, _px(4.0))
	var gems: InstanceBatch = _batches[&"gem"]
	gems.begin()
	for g: Pickup in p.gems:
		if view.has_point(g.pos):
			gems.add(g.pos, 0.0, gs, XP_COLOR)
	gems.end()
	var cs := maxf(6.0, _px(3.5))
	for co: Pickup in p.coins:
		if view.has_point(co.pos):
			c.draw_circle(co.pos, cs, Color("#ffd24a"))
	for cap: Pickup in p.capsules:
		match cap.kind:
			Pickup.Kind.HEAL:
				c.draw_rect(Rect2(cap.pos - Vector2(14, 11), Vector2(28, 22)), Color.WHITE)
				c.draw_rect(Rect2(cap.pos - Vector2(3, 8), Vector2(6, 16)), Color("#e8434f"))
				c.draw_rect(Rect2(cap.pos - Vector2(8, 3), Vector2(16, 6)), Color("#e8434f"))
			Pickup.Kind.CORE:
				c.draw_circle(cap.pos, 18.0, Color("#ffd24a"))
				c.draw_arc(cap.pos, 26.0, 0, TAU, 32, Color("#fff2b0"), _px(2.0))
			Pickup.Kind.MAGNET:
				c.draw_arc(cap.pos, 14.0, PI, TAU, 16, XP_COLOR, 6.0)
				c.draw_rect(Rect2(cap.pos + Vector2(-17, 0), Vector2(6, 10)), Color.WHITE)
				c.draw_rect(Rect2(cap.pos + Vector2(11, 0), Vector2(6, 10)), Color.WHITE)
			_:
				c.draw_circle(cap.pos, 14.0, XP_COLOR.darkened(0.2))
				c.draw_arc(cap.pos, 16.0, 0, TAU, 24, XP_COLOR.lightened(0.3), _px(2.0))

func _draw_enemies(c: CanvasItem) -> void:
	var view := state.view_rect().grow(cfg.max_enemy_radius)
	for b in _batches.values():
		b.begin()
	var eye: InstanceBatch = _batches[&"eye"]
	var dark := Color(0.05, 0.05, 0.1)
	for e: Enemy in run.enemies.list:
		if e.dead or not view.has_point(e.pos):
			continue
		var col := e.color
		if e.flash > 0.0:
			col = col.lerp(Color.WHITE, 0.7)
		if e.type == &"meteor":
			_batches[&"rock"].add(e.pos, e.facing, e.r, Color("#b8a898") if e.flash > 0.0 else Color("#7a6a5c"))
			continue
		var shape: StringName = e.def.shape if e.def != null else &"ship"
		var batch: InstanceBatch = _batches.get(shape, _batches[&"orb"])
		batch.add(e.pos, e.facing, e.r, col)
		eye.add(e.pos + Vector2.from_angle(e.facing) * e.r * 0.55, 0.0, maxf(2.0, e.r * 0.18), dark)
		_draw_enemy_marks(c, e)
	for key in _batches:
		if key != &"gem":
			_batches[key].end()

## 数の少ない飾り（エリートの輪・背面の弱点・予告・HP バー）は個別に描く。
func _draw_enemy_marks(c: CanvasItem, e: Enemy) -> void:
	if e.elite:
		c.draw_arc(e.pos, e.r + _px(3.0), 0, TAU, 32, Color("#ffd24a"), _px(2.0))
	if e.weak_arc > 0.0:
		c.draw_arc(e.pos, e.r + _px(2.0), e.facing + PI - e.weak_arc, e.facing + PI + e.weak_arc, 12, Color("#ffe46b"), _px(3.0))
	if e.charge > 0.0:
		c.draw_arc(e.pos, e.r + _px(6.0), 0, TAU * e.charge, 24, Color(1, 0.3, 0.3, 0.8), _px(2.5))
	if (e.r >= 25.0 or e.is_boss) and e.hp < e.max_hp:
		var w := e.r * 1.6
		var top := e.pos + Vector2(-w / 2.0, -e.r - _px(10.0))
		c.draw_rect(Rect2(top, Vector2(w, _px(4.0))), Color(0, 0, 0, 0.6))
		c.draw_rect(Rect2(top, Vector2(w * maxf(0.0, e.hp / e.max_hp), _px(4.0))), Color("#ff6b5a"))

## 隕石：灰茶の不規則な岩とクレーター。敵の目・装甲の輪・HP バーは描かない（仕様書 15）。
func _draw_rock(c: CanvasItem, e: Enemy) -> void:
	var pts := PackedVector2Array()
	var seed := e.id * 0.37
	for i in 9:
		var a := e.facing + i * TAU / 9.0
		var k := 0.78 + 0.22 * sin(seed + i * 2.3)
		pts.append(e.pos + Vector2.from_angle(a) * e.r * k)
	c.draw_colored_polygon(pts, Color("#7a6a5c") if e.flash <= 0.0 else Color("#b8a898"))
	for i in 3:
		var off := Vector2.from_angle(seed * 3.0 + i * 2.1) * e.r * 0.45
		c.draw_circle(e.pos + off, e.r * 0.16, Color("#5e5146"))
	if e.hp < e.max_hp:
		c.draw_line(e.pos - Vector2(e.r * 0.4, 0), e.pos + Vector2(e.r * 0.3, e.r * 0.3), Color("#2e2620"), _px(2.0))

func _draw_projectiles(c: CanvasItem) -> void:
	var view := state.view_rect().grow(40.0)
	for t in trails:
		var a: float = t.life / t.max
		var pts: PackedVector2Array = t.points
		if pts.size() > 1:
			c.draw_polyline(pts, Color(1.0, 0.6, 0.25, 0.6 * a), _px(3.0))
	for s: Shot in run.projectiles.friendly:
		if not view.has_point(s.pos):
			continue
		if s.kind == &"debris":
			if s.trail.size() > 1:
				c.draw_polyline(s.trail, Color(1.0, 0.6, 0.25, 0.7), _px(3.0))
			var u := Vector2.from_angle(s.angle) * s.r
			var v := Vector2(-u.y, u.x) * 0.6
			c.draw_colored_polygon(PackedVector2Array([s.pos + u, s.pos + v, s.pos - u * 0.7, s.pos - v]), Color("#aeb6c4"))
			c.draw_polyline(PackedVector2Array([s.pos + u, s.pos + v, s.pos - u * 0.7, s.pos - v, s.pos + u]), Color("#ff9a3c"), _px(1.5))
		else:
			var dir := s.vel.normalized()
			c.draw_line(s.pos - dir * s.r * 2.2, s.pos + dir * s.r * 1.2, Color("#9fe8ff"), maxf(_px(3.0), s.r * 0.9))
	for s: Shot in run.projectiles.hostile:
		if not view.has_point(s.pos):
			continue
		c.draw_circle(s.pos, s.r, Color("#ff3b3b"))
		c.draw_circle(s.pos, s.r * 0.5, Color("#3a0a0a"))

func _draw_path(c: CanvasItem) -> void:
	if state.drawing and state.draw_points.size() > 0:
		var pts := state.draw_points
		if pts.size() > 1:
			c.draw_polyline(pts, Color(0.55, 0.9, 1.0, 0.25), cfg.wave_radius * 2.0)
			c.draw_polyline(pts, Color(0.8, 0.97, 1.0, 0.95), _px(3.0))
		c.draw_circle(pts[0], _px(6.0), Color("#c8f7ff"))
	if state.tracing and state.trace_path.size() > 1:
		c.draw_polyline(state.trace_path, Color(0.55, 0.9, 1.0, 0.18), cfg.wave_radius * 2.0)
		c.draw_polyline(state.trace_path, Color(0.8, 0.97, 1.0, 0.6), _px(2.0))
	for g in ghosts:
		var a: float = g.life / g.max
		c.draw_line(g.from, g.to, Color(0.75, 0.95, 1.0, 0.6 * a), _px(4.0))

## 武器・特性が残すもの（機雷・ドローン・渦）。
func _draw_build_objects(c: CanvasItem) -> void:
	var b := run.build
	var mines = b.weapon_behaviors.get(&"W07")
	if mines != null:
		for m in mines.mines:
			var col := Color("#ff7b54") if m.armed <= 0.0 else Color(1, 0.5, 0.3, 0.4)
			c.draw_circle(m.pos, 7.0, col)
			c.draw_arc(m.pos, 11.0, 0, TAU, 12, Color(1, 0.6, 0.4, 0.5), _px(1.5))
	var drones = b.weapon_behaviors.get(&"W06")
	if drones != null:
		for d in drones.drones:
			c.draw_circle(d.pos, 9.0, Color("#a8ffdb"))
	var vortex = b.trait_behaviors.get(&"T03")
	if vortex != null:
		for v in vortex.vortexes:
			var k: float = v.life / v.max
			for i in 3:
				var a: float = state.time * 4.0 + i * TAU / 3.0
				c.draw_arc(v.pos, v.radius * (0.3 + 0.2 * i), a, a + 2.0, 16, Color(0.75, 0.45, 1.0, 0.6 * k), _px(3.0))

func _draw_fx(c: CanvasItem) -> void:
	_draw_build_objects(c)
	for bm in beams:
		var k: float = bm.life / bm.max
		c.draw_line(bm.from, bm.to, Color(1.0, 0.95, 0.6, 0.7 * k), bm.width)
		c.draw_line(bm.from, bm.to, Color(1, 1, 1, k), bm.width * 0.3)
	for bo in bolts:
		var k: float = bo.life / bo.max
		var pts := PackedVector2Array(bo.points)
		if pts.size() > 1:
			c.draw_polyline(pts, Color(0.7, 0.85, 1.0, k), _px(3.0))
	for r in rings:
		var k: float = r.life / r.max
		var col: Color = r.color
		col.a *= k
		c.draw_arc(r.pos, r.radius * (1.0 + (1.0 - k) * 0.15), 0, TAU, 48, col, _px(3.0))
	for im in impacts:
		var k: float = im.life / im.max
		var col: Color = im.color
		col.a = k
		var a: float = im.dir.angle()
		c.draw_arc(im.pos, im.r + _px(3.0), a - 0.7, a + 0.7, 16, col, _px(5.0))
	for p in particles:
		var col: Color = p.color
		col.a = clampf(p.life / p.max, 0.0, 1.0)
		c.draw_circle(p.pos, _px(p.size * 0.6), col)
	for t in texts:
		var col: Color = t.color
		col.a = clampf(t.life / 0.5, 0.0, 1.0)
		var size := int(t.size / maxf(state.camera_zoom, 0.25))
		c.draw_string(_font, t.pos - Vector2(size * 0.8, 0), t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

## 敗北の暗転（機体以外を暗くする。仕様書 14）。
func _draw_dim(c: CanvasItem) -> void:
	if state.phase == RunState.Phase.DYING:
		c.draw_rect(state.view_rect().grow(400.0), Color(0, 0, 0, cfg.death_world_dim))

func _draw_ship(c: CanvasItem) -> void:
	if state.phase == RunState.Phase.DYING and run.sequence_t >= cfg.death_freeze_time:
		return
	var p := state.ship_pos
	var R := cfg.ship_radius
	var col := Color("#e8f6ff")
	var hurt := state.ship_hurt > 0.0
	if hurt:
		col = Color("#ff6b5a")
		p.x += randf_range(-1.0, 1.0) * _px(cfg.ship_hurt_shake)
	if state.ship_invuln > 0.0 and fmod(state.time * 20.0, 2.0) < 1.0:
		col.a = 0.5
	c.draw_circle(p, R, col)
	c.draw_arc(p, R + _px(2.0), 0, TAU, 32, Color("#5fd8ff"), _px(2.0))
	var dir := state.ship_heading
	var tip := p + dir * (R + _px(14.0))
	var side := Vector2(-dir.y, dir.x) * _px(6.0)
	c.draw_colored_polygon(PackedVector2Array([tip, p + dir * (R + _px(4.0)) + side, p + dir * (R + _px(4.0)) - side]), Color("#5fd8ff"))
	# HP バー（機体の真下、仕様書 15）
	var frac := clampf(state.ship_hp / state.stats.max_hp, 0.0, 1.0)
	var w := _px(44.0)
	var top := p + Vector2(-w / 2.0, R + _px(10.0))
	c.draw_rect(Rect2(top - Vector2(_px(1), _px(1)), Vector2(w + _px(2), _px(7))), Color(0, 0, 0, 0.55))
	c.draw_rect(Rect2(top, Vector2(w * frac, _px(5.0))), Color("#ff5a4a") if frac < 0.3 else Color("#5dffa0"))

func _draw_top(c: CanvasItem) -> void:
	if flash > 0.0:
		c.draw_rect(state.view_rect().grow(400.0), Color(1, 1, 1, flash * 0.5))
