## 描画の流れ（設計書 10）。ゲームの状態とイベントを読むだけで、状態は書き換えない。
##
## World の下に層（DrawLayer）を作り、層ごとに描く。カメラは RunManager が求めた位置とズームに合わせる。
## 敵と天体は透過ピクセルスプライト。見分けのルール（仕様書 17）を保つ。
class_name RenderManager
extends Node

const XP_COLOR := Color("#b8a0ff")
const XP_OUTLINE := Color("#39265e")
const SPRITE_IDS := ["drifter", "swarm", "darter", "armored", "splitter", "splitling",
	"gunner", "missile", "battleship", "titan", "meteor_0", "meteor_1"]
const MOON := preload("res://assets/pixel/moon.png")
const PLANET := preload("res://assets/pixel/planet.png")
const AIRSHIP := preload("res://assets/pixel/airship.png")
const AIRSHIP_FLAME := preload("res://assets/pixel/airship_flame.png")
const AIRSHIP_SPARK := preload("res://assets/pixel/airship_spark.png")
const AIRSHIP_TURRET_BASE := preload("res://assets/pixel/airship_turret_base.png")
const AIRSHIP_TURRET := preload("res://assets/pixel/airship_turret.png")
const DRONE := preload("res://assets/pixel/drone.png")
const METEOR_SHEETS := [preload("res://assets/pixel/meteor_spritesheet.png"),
	preload("res://assets/pixel/meteor2_spritesheet.png")]
const NATIVE_SPRITES := [&"drifter", &"swarm", &"darter", &"armored", &"splitter", &"splitling"]

@export var world_path: NodePath
@export var camera_path: NodePath

var run: RunManager
var state: RunState
var cfg: GameConfig

var _layers: Dictionary = {}
var pipeline: RenderPipeline
## 形ごとのまとめた描画（敵・経験値の結晶）
var _batches: Dictionary = {}
var _camera: Camera2D
var _font: Font
var _path_band_group: CanvasGroup
var _path_band: DrawLayer

# 演出（実秒で進む。ポーズ中・3択の間は止まる）
var rings: Array = []
var particles: Array = []
var meteor_shards: Array = []
var texts: Array = []
var ghosts: Array = []
var impacts: Array = []
var trails: Array = []
var beams: Array = []
var bolts: Array = []
var shake := 0.0
var flash := 0.0
var _stars: PackedVector3Array
var _jet_time := 0.0
var _exhaust: Array[Dictionary] = []

func _ready() -> void:
	run = get_node("../RunManager") as RunManager
	state = run.state
	cfg = run.cfg
	_font = ThemeDB.fallback_font
	_camera = get_node(camera_path) as Camera2D
	var world := get_node(world_path)
	for name in ["background", "field", "exhaust", "pickups", "enemies", "projectiles", "path", "fx", "dim", "ship", "top"]:
		var layer := DrawLayer.new()
		layer.name = name.capitalize().replace(" ", "")
		layer.z_index = _layers.size() * 2
		layer.draw_fn = Callable(self, "_draw_" + name)
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		world.add_child(layer)
		_layers[name] = layer
	# 不透明な帯を合成してから一度だけ透過し、交差部分も同じ濃さにする。
	_path_band_group = CanvasGroup.new()
	_path_band_group.z_index = -1
	_layers.path.add_child(_path_band_group)
	_path_band = DrawLayer.new()
	_path_band.draw_fn = Callable(self, "_draw_path_band")
	_path_band_group.add_child(_path_band)
	_build_batches()
	pipeline = RenderPipeline.new()
	add_child(pipeline)
	pipeline.setup(world as Node2D, _camera, [_layers.projectiles, _layers.fx, _layers.path, _layers.exhaust])
	_layers.exhaust.modulate = Color(1.15, 1.15, 1.15)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 400:
		_stars.append(Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(0.2, 1.0)))
	run.frame_events.connect(_on_events)

## 種類ごとのスプライトと経験値の結晶を MultiMesh でまとめる。
func _build_batches() -> void:
	var enemy_mat := ShaderMaterial.new()
	enemy_mat.shader = load("res://shaders/pixel_sprite.gdshader")
	for id in SPRITE_IDS:
		if id.begins_with("meteor_"):
			var sheet: Texture2D = METEOR_SHEETS[0 if id == "meteor_0" else 1]
			var frame_size := float(sheet.get_height())
			for stage in 3:
				var rock_batch := InstanceBatch.new()
				rock_batch.setup_texture(sheet, Rect2(stage * frame_size, 0, frame_size, frame_size))
				rock_batch.material = enemy_mat
				rock_batch.z_index = -1
				_layers.enemies.add_child(rock_batch)
				_batches[StringName(id + "_damage_" + str(stage))] = rock_batch
			continue
		var b := InstanceBatch.new()
		b.setup_texture(load("res://assets/pixel/" + id + ".png") as Texture2D)
		b.material = enemy_mat
		# 弱点・予告・HPをスプライトの上に描く。
		b.z_index = -1
		_layers.enemies.add_child(b)
		_batches[StringName(id)] = b
	var gem := InstanceBatch.new()
	gem.setup_polygon(PackedVector2Array([Vector2(0, -1.4), Vector2(1, 0), Vector2(0, 1.4), Vector2(-1, 0)]))
	var gem_mat := ShaderMaterial.new()
	gem_mat.shader = load("res://shaders/xp_crystal.gdshader")
	gem.material = gem_mat
	_layers.pickups.add_child(gem)
	_batches[&"gem"] = gem

func _process(delta: float) -> void:
	var phase := state.phase
	var frozen := phase == RunState.Phase.PAUSED or phase == RunState.Phase.LEVELUP \
		or (phase == RunState.Phase.DYING and run.sequence_t < cfg.death_freeze_time)
	var dt := 0.0 if frozen else delta
	_update_fx(dt)
	_update_exhaust(dt)
	var offset := Vector2.ZERO
	if shake > 0.0 and phase != RunState.Phase.DYING:
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake / maxf(state.camera_zoom, 0.01)
	_camera.position = state.view_center + offset
	_camera.zoom = Vector2(state.camera_zoom, state.camera_zoom)
	pipeline.step(dt, _camera.position, state.camera_zoom)
	for layer in _layers.values():
		layer.queue_redraw()
	_path_band_group.visible = state.drawing or state.tracing
	_path_band_group.self_modulate = Color(1, 1, 1, 0.25 if state.drawing else 0.18)
	_path_band.queue_redraw()

# ── イベント → 演出 ───────────────────────────────────────────────

func _on_events(events: Array[Dictionary]) -> void:
	for ev in events:
		match ev.type:
			&"ring":
				_ring(ev.pos, ev.radius, ev.color, ev.life)
			&"explode":
				_ring(ev.pos, ev.radius, ev.color, ev.life)
				if ev.radius >= 150.0:
					pipeline.add_wave(ev.pos, ev.radius, 0.4)
			&"text":
				_text(ev.pos, ev.text, ev.color, ev.get("size", 16))
			&"kill":
				if ev.get("enemy_type", &"") == &"meteor":
					_shatter_meteor(ev)
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
				_exhaust.clear()
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
				pipeline.add_wave(ev.pos, ev.radius, 0.5)
			&"boss_spawn":
				shake = maxf(shake, 8.0)
			&"boss_explode":
				flash = 1.0
				shake = 30.0
				_burst(ev.pos, Color("#ff526e"), 120, Vector2.ZERO, 900.0)
				pipeline.add_wave(ev.pos, 1600.0, 1.2)
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
	if pipeline.sparks.available():
		pipeline.sparks.burst(p, color, n * 2, dir, speed, 0.7, 5.0)
		return
	# 簡易版（CPU の粒）は数を抑える
	if particles.size() > 500:
		return
	n = mini(n, 8)
	for i in n:
		var a := randf() * TAU
		var s := speed * (0.3 + randf())
		particles.append({"pos": p, "vel": Vector2.from_angle(a) * s * 0.6 + dir * s * 0.8,
			"life": 0.5 + randf() * 0.4, "max": 0.9, "color": color, "size": 2.0 + randf() * 4.0})

func _sparks(p: Vector2, normal: Vector2, n: int, color: Color) -> void:
	if pipeline.sparks.available():
		pipeline.sparks.burst(p, color, n, normal, 520.0, 0.4, 3.0)
		return
	var side := Vector2(-normal.y, normal.x)
	n = mini(n, 10)
	for i in n:
		var s := 250.0 + randf() * 450.0
		var dir := (side * (1.0 if i % 2 == 0 else -1.0) * randf_range(0.4, 1.0) + normal * randf_range(0.0, 0.8)).normalized()
		particles.append({"pos": p, "vel": dir * s, "life": 0.25 + randf() * 0.2, "max": 0.45, "color": color, "size": 2.0 + randf() * 2.0})

func _shatter_meteor(ev: Dictionary) -> void:
	var sheet: Texture2D = METEOR_SHEETS[posmod(int(ev.meteor_index), 2)]
	var size := float(sheet.get_height())
	var half := size / 2.0
	for y in 2:
		for x in 2:
			var offset := Vector2((x - 0.5) * half, (y - 0.5) * half).rotated(ev.facing)
			meteor_shards.append({"texture": sheet,
				"region": Rect2(size * 2.0 + x * half, y * half, half, half),
				"pos": ev.pos + offset, "vel": offset.normalized() * 100.0 + ev.dir * 60.0,
				"angle": ev.facing, "spin": -1.5 if x == y else 1.5, "life": 0.65})

func _update_fx(dt: float) -> void:
	for shard in meteor_shards:
		shard.pos += shard.vel * dt
		shard.angle += shard.spin * dt
		shard.life -= dt
	meteor_shards = meteor_shards.filter(func(s): return s.life > 0.0)
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
		if view.grow(b.r).has_point(b.pos):
			c.draw_texture_rect(PLANET if b.is_planet else MOON,
				Rect2(b.pos - Vector2.ONE * b.r, Vector2.ONE * b.r * 2.0), false)

func _draw_pickups(c: CanvasItem) -> void:
	var p := run.pickups
	var view := state.view_rect().grow(60.0)
	# 経験値の結晶：画面上で最低 8px の高さ（仕様書 17）
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
	for key in _batches:
		if key != &"gem":
			_batches[key].begin()
	for e: Enemy in run.enemies.list:
		if e.dead or not view.has_point(e.pos):
			continue
		# 色のr成分はスプライトシェーダーの被弾フラッシュ。
		var col := Color(1.0 if e.flash > 0.0 and e.type != &"meteor" else 0.0, 0.0, 0.0, 1.0)
		if e.type == &"meteor":
			# ストリームで再生成されても同じ岩の模様を使う。
			var variant := posmod(e.meteor_index, 2)
			var stage := clampi(int((1.0 - e.hp / e.max_hp) * 3.0), 0, 2)
			var rock_key := StringName("meteor_" + str(variant) + "_damage_" + str(stage))
			var rock_batch: InstanceBatch = _batches[rock_key]
			rock_batch.add(e.pos, e.facing, METEOR_SHEETS[variant].get_height() / 2.0, col)
			continue
		var batch: InstanceBatch = _batches.get(e.type, _batches[&"battleship"])
		if e.type in NATIVE_SPRITES:
			batch.add(e.pos, e.facing + PI / 2.0, e.r, col)
		else:
			batch.add(e.pos, e.facing - PI / 2.0, e.r, col)
		_draw_enemy_marks(c, e)
	for key in _batches:
		if key != &"gem":
			_batches[key].end()
	_draw_meteor_shards(c)

## 数の少ない飾り（エリートの輪・背面の弱点・予告・HP バー）は個別に描く。
func _draw_enemy_marks(c: CanvasItem, e: Enemy) -> void:
	if e.elite:
		c.draw_arc(e.pos, e.r + _px(3.0), 0, TAU, 32, Color("#ffd24a"), _px(2.0))
	if e.weak_arc > 0.0 and e.type != &"armored":
		c.draw_arc(e.pos, e.r + _px(2.0), e.facing + PI - e.weak_arc, e.facing + PI + e.weak_arc, 12, Color("#ffe46b"), _px(3.0))
	if e.charge > 0.0:
		c.draw_arc(e.pos, e.r + _px(6.0), 0, TAU * e.charge, 24, Color(1, 0.3, 0.3, 0.8), _px(2.5))
	if (e.r >= 25.0 or e.is_boss) and e.hp < e.max_hp:
		var w := e.r * 1.6
		var top := e.pos + Vector2(-w / 2.0, -e.r - _px(10.0))
		c.draw_rect(Rect2(top, Vector2(w, _px(4.0))), Color(0, 0, 0, 0.6))
		c.draw_rect(Rect2(top, Vector2(w * maxf(0.0, e.hp / e.max_hp), _px(4.0))), Color("#ff6b5a"))

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

func _draw_path_band(c: CanvasItem) -> void:
	var pts := state.draw_points if state.drawing else state.trace_path
	if pts.size() < 2:
		return
	var color := Color(0.55, 0.9, 1.0)
	for i in pts.size() - 1:
		c.draw_line(pts[i], pts[i + 1], color, cfg.wave_radius * 2.0)
	for point in pts:
		c.draw_circle(point, cfg.wave_radius, color)

func _draw_path(c: CanvasItem) -> void:
	if state.drawing and state.draw_points.size() > 0:
		var pts := state.draw_points
		if pts.size() > 1:
			c.draw_polyline(pts, Color(0.8, 0.97, 1.0, 0.95), _px(3.0))
		c.draw_circle(pts[0], _px(6.0), Color("#c8f7ff"))
	if state.tracing and state.trace_path.size() > 1:
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
			var size := DRONE.get_size() * cfg.character_scale
			var outward: Vector2 = d.pos - state.ship_pos
			var angle := outward.angle() + PI / 2.0 if not outward.is_zero_approx() else state.ship_heading.angle() + PI / 2.0
			c.draw_set_transform(d.pos, angle)
			c.draw_texture_rect(DRONE, Rect2(-size / 2.0, size), false)
			c.draw_set_transform(Vector2.ZERO)
	var vortex = b.trait_behaviors.get(&"T03")
	if vortex != null:
		for v in vortex.vortexes:
			var k: float = v.life / v.max
			for i in 3:
				var a: float = state.time * 4.0 + i * TAU / 3.0
				c.draw_arc(v.pos, v.radius * (0.3 + 0.2 * i), a, a + 2.0, 16, Color(0.75, 0.45, 1.0, 0.6 * k), _px(3.0))

func _draw_meteor_shards(c: CanvasItem) -> void:
	for shard in meteor_shards:
		c.draw_set_transform(shard.pos, shard.angle)
		c.draw_texture_rect_region(shard.texture, Rect2(-shard.region.size / 2.0, shard.region.size),
			shard.region, Color(1, 1, 1, shard.life / 0.65))
	c.draw_set_transform(Vector2.ZERO)

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

## 敗北の暗転（機体以外を暗くする。仕様書 16）。
func _draw_dim(c: CanvasItem) -> void:
	if state.phase == RunState.Phase.DYING:
		c.draw_rect(state.view_rect().grow(400.0), Color(0, 0, 0, cfg.death_world_dim))

func _update_exhaust(dt: float) -> void:
	if dt <= 0.0:
		return
	for sample in _exhaust:
		sample.life -= dt
	_exhaust = _exhaust.filter(func(sample): return sample.life > 0.0)
	if state.phase != RunState.Phase.PLAY and state.phase != RunState.Phase.FINISHING:
		return
	if state.drawing or state.hitstop > 0.0:
		return
	var animation_speed := state.ship_vel.length()
	if state.tracing and run.draw.run != null:
		animation_speed = run.draw.run.rate
	_jet_time += dt * clampf(animation_speed / cfg.base_max_speed, 0.0, 3.0)
	if state.ship_vel.length() < 5.0:
		return
	var tail := state.ship_pos - state.ship_heading * 22.0 * cfg.character_scale
	if not _exhaust.is_empty():
		var distance: float = tail.distance_to(_exhaust.back().pos)
		if distance > maxf(120.0, state.ship_vel.length() * dt * 3.0):
			_exhaust.clear()
		elif distance < 2.0 * cfg.character_scale:
			return
	_exhaust.append({"pos": tail, "life": 0.24})
	if _exhaust.size() > 48:
		_exhaust.pop_front()

func _draw_exhaust(c: CanvasItem) -> void:
	for i in range(1, _exhaust.size()):
		var fade: float = _exhaust[i - 1].life / 0.24
		c.draw_line(_exhaust[i - 1].pos, _exhaust[i].pos,
			Color(1.0, 0.57, 0.3, fade * 0.18), 3.0 * cfg.character_scale)
	if state.phase == RunState.Phase.DYING or state.phase == RunState.Phase.ENDED:
		return
	var size := AIRSHIP.get_size() * cfg.character_scale
	# 下側20pxは炎用の余白。機体本体の中心を判定の中心へ合わせる。
	var rect := Rect2(Vector2(-AIRSHIP.get_width() / 2.0, -20.0) * cfg.character_scale, size)
	var frame := int(_jet_time * 12.0) % 3
	var region := Rect2(frame * AIRSHIP.get_width(), 0, AIRSHIP.get_width(), AIRSHIP.get_height())
	c.draw_set_transform(state.ship_pos, state.ship_heading.angle() + PI / 2.0)
	c.draw_texture_rect_region(AIRSHIP_FLAME, rect, region)
	c.draw_texture_rect_region(AIRSHIP_SPARK, rect, region, Color(1, 1, 1, 0.65))
	c.draw_set_transform(Vector2.ZERO)

func _draw_ship(c: CanvasItem) -> void:
	if state.phase == RunState.Phase.DYING and run.sequence_t >= cfg.death_freeze_time:
		return
	var p := state.ship_pos
	var R := cfg.ship_radius
	var col := Color.WHITE
	var hurt := state.ship_hurt > 0.0
	if hurt:
		col = Color("#ff6b5a")
		p.x += randf_range(-1.0, 1.0) * _px(cfg.ship_hurt_shake)
	if state.ship_invuln > 0.0 and fmod(state.time * 20.0, 2.0) < 1.0:
		col.a = 0.5
	var dir := state.ship_heading
	var size := AIRSHIP.get_size() * cfg.character_scale
	c.draw_set_transform(p, dir.angle() + PI / 2.0)
	c.draw_texture_rect(AIRSHIP, Rect2(Vector2(-AIRSHIP.get_width() / 2.0, -20.0) * cfg.character_scale, size), false, col)
	var rear = run.build.weapon_behaviors.get(&"W23")
	if rear != null:
		c.draw_texture_rect(AIRSHIP_TURRET_BASE,
			Rect2(Vector2(-AIRSHIP.get_width() / 2.0, -20.0) * cfg.character_scale, size), false, col)
	c.draw_set_transform(Vector2.ZERO)
	if rear != null:
		# 元絵の砲身は下向き。キャンバスの中心ではなく取り付け軸で回す。
		var mount: Vector2 = rear.mount_position() + (p - state.ship_pos)
		var aim: Vector2 = rear.aim_direction()
		c.draw_set_transform(mount, aim.angle() - PI / 2.0)
		c.draw_texture_rect(AIRSHIP_TURRET,
			Rect2(-rear.MOUNT_PIXEL * cfg.character_scale, size), false, col)
		c.draw_set_transform(Vector2.ZERO)
	# HP バー（機体の真下、仕様書 17）
	var frac := clampf(state.ship_hp / state.stats.max_hp, 0.0, 1.0)
	var w := _px(44.0)
	var top := p + Vector2(-w / 2.0, R + _px(10.0))
	c.draw_rect(Rect2(top - Vector2(_px(1), _px(1)), Vector2(w + _px(2), _px(7))), Color(0, 0, 0, 0.55))
	c.draw_rect(Rect2(top, Vector2(w * frac, _px(5.0))), Color("#ff5a4a") if frac < 0.3 else Color("#5dffa0"))

func _draw_top(c: CanvasItem) -> void:
	if flash > 0.0:
		c.draw_rect(state.view_rect().grow(400.0), Color(1, 1, 1, flash * 0.5))
