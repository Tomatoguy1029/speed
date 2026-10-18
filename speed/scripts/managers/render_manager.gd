## 描画の流れ（設計書 10）。ゲームの状態とイベントを読むだけで、状態は書き換えない。
##
## World の下に層（DrawLayer）を作り、層ごとに描く。カメラは RunManager が求めた位置とズームに合わせる。
## 敵と天体は透過ピクセルスプライト。見分けのルール（仕様書 17）を保つ。
class_name RenderManager
extends Node

const XP_COLOR := Color("#b8a0ff")
const COIN_COLOR := Color("#ffd24a")
const XP_OUTLINE := Color("#39265e")
const SHIELD_VISUAL := preload("res://scripts/render/shield_visual.gd")
const SPRITE_IDS := ["drifter", "swarm", "darter", "armored", "splitter", "splitling",
	"gunner", "missile", "battleship", "titan", "meteor_0", "meteor_1"]
const MOON := preload("res://assets/pixel/moon.png")
const PLANET := preload("res://assets/pixel/planet.png")
const AIRSHIP := preload("res://assets/pixel/airship.png")
const AIRSHIP_FLAME := preload("res://assets/pixel/airship_flame.png")
const AIRSHIP_SPARK := preload("res://assets/pixel/airship_spark.png")
const AIRSHIP_TURRET_BASE := preload("res://assets/pixel/airship_turret_base.png")
const AIRSHIP_TURRET := preload("res://assets/pixel/airship_turret.png")
const AIRSHIP_ARMOR := preload("res://assets/pixel/airship_armor.png")
const AIRSHIP_CANON := preload("res://assets/pixel/airship_canon.png")
const AIRSHIP_PROBE := preload("res://assets/pixel/airship_electronic_probe.png")
const AIRSHIP_MINE := preload("res://assets/pixel/airship_mine.png")
const AIRSHIP_BLUE_FLAME := preload("res://assets/pixel/airship_blue_flame.png")
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
## 絵がまだない敵の種類（仮の図形で、敵の色で描く）
var _shape_ids: Dictionary = {}
var _camera: Camera2D
var _font: Font
## 描画のカメラの中心と倍率（毎フレーム決める）。普段はゲームの表示範囲と同じ。
var cam_center := Vector2.ZERO
var cam_zoom := 1.0
## 実験場（デバッグ）用：{"center": Vector2, "zoom": float} を入れると、ゲームの状態を変えずに描画のカメラだけをそこへ動かす
var view_override: Variant = null
## 背景の星を描くか（実験場では初めは消す）
var show_background := true
## いつも飾りを描く敵の種類（type ID → true）
var _always_marked: Dictionary = {}
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
var _enemy_textures: Dictionary = {}
var bolts: Array = []
var shield_transfers: Array = []
## ポンプ座に吸い込まれていく敵（回りながら小さくなって口へ飛び込む）
var swallows: Array = []
## ケフェウス座が兵を召喚する位置の予告
var summon_marks: Array = []
var shake := 0.0
## 設定の「画面の揺れ」の強さ（0〜1。ポーズ中に変えるとすぐ反映）
var _shake_scale := 1.0
var flash := 0.0
var _stars: PackedVector3Array
var _star_batch: InstanceBatch
var _star_material: ShaderMaterial
var _hostile_batch: InstanceBatch
var _coin_batch: InstanceBatch
var _jet_time := 0.0
var _exhaust: Array[Dictionary] = []

func _ready() -> void:
	run = get_node("../RunManager") as RunManager
	state = run.state
	cfg = run.cfg
	_font = ThemeDB.fallback_font
	_read_settings()
	SaveManager.settings_changed.connect(_read_settings)
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
	_build_star_batch()
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
	# ほかの種類は、assets/pixel/<type ID>.png があればその絵で、なければ敵の定義の形（EnemyDef.shape）の
	# 図形で描く。png を置けば絵に替わる
	for def: EnemyDef in ConfigManager.enemies.values():
		# いつも飾り（口・殻・ハサミ・膜・水流・号令・塊）を描く種類
		if def.gate in [&"mouth", &"shell", &"claw"] or def.behavior in [&"triangle", &"aquarius", &"cepheus", &"crow", &"shield", &"pump", &"soldier"] \
				or def.id in [&"bomber", &"splitter", &"beamer", &"pulser", &"telescope", &"lynx", &"ruler", &"reticle"]:
			_always_marked[def.id] = true
		if def.id == &"meteor" or _batches.has(def.id):
			continue
		var b := InstanceBatch.new()
		var path := "res://assets/pixel/%s.png" % def.id
		if ResourceLoader.exists(path):
			b.setup_texture(load(path) as Texture2D)
			b.material = enemy_mat
		else:
			b.setup_polygon(_placeholder_points(def.shape))
			_shape_ids[def.id] = true
		b.z_index = -1
		_layers.enemies.add_child(b)
		_batches[def.id] = b
	var gem := InstanceBatch.new()
	gem.setup_polygon(PackedVector2Array([Vector2(0, -1.4), Vector2(1, 0), Vector2(0, 1.4), Vector2(-1, 0)]))
	var gem_mat := ShaderMaterial.new()
	gem_mat.shader = load("res://shaders/xp_crystal.gdshader")
	gem.material = gem_mat
	_layers.pickups.add_child(gem)
	_batches[&"gem"] = gem
	# 部品は数が増え続けるので、円を1つずつ描かずにまとめて描く。カプセルより下に置く。
	_coin_batch = InstanceBatch.new()
	_coin_batch.setup_polygon(InstanceBatch.circle_points(24))
	_coin_batch.show_behind_parent = true
	_layers.pickups.add_child(_coin_batch)
	# 弾の二重の円は全弾で共通。頂点を毎フレーム生成せず使い回す。
	_hostile_batch = InstanceBatch.new()
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var circle := InstanceBatch.circle_points(32)
	for disc in 2:
		var radius := 1.0 if disc == 0 else 0.5
		var color := Color("#ff3b3b") if disc == 0 else Color("#3a0a0a")
		for i in circle.size():
			vertices.append(Vector2.ZERO)
			vertices.append(circle[i] * radius)
			vertices.append(circle[(i + 1) % circle.size()] * radius)
			for j in 3:
				colors.append(color)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_hostile_batch._setup_mesh(mesh)
	_layers.projectiles.add_child(_hostile_batch)

func _read_settings() -> void:
	_shake_scale = float(SaveManager.settings.screen_shake)

func _process(delta: float) -> void:
	var phase := state.phase
	var frozen := phase == RunState.Phase.PAUSED or phase == RunState.Phase.LEVELUP \
		or (phase == RunState.Phase.DYING and run.sequence_t < cfg.death_freeze_time)
	var dt := 0.0 if frozen else delta
	# 停止中は減衰も止まるため、残った画面揺れを持ち越さない。
	if phase == RunState.Phase.PAUSED or phase == RunState.Phase.LEVELUP:
		shake = 0.0
	_update_fx(dt)
	_update_exhaust(dt)
	_update_view()
	var offset := Vector2.ZERO
	if not frozen and shake > 0.0 and phase != RunState.Phase.DYING and view_override == null:
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * _shake_scale / maxf(cam_zoom, 0.01)
	_camera.position = cam_center + offset
	_camera.zoom = Vector2(cam_zoom, cam_zoom)
	pipeline.step(dt, _camera.position, cam_zoom)
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
			&"shield_reflect":
				_sparks(ev.pos, ev.normal, 8, Color("#ffa4ef"))
				_ring(ev.pos, 22.0, Color("#ff9de9"), 0.18)
			&"shield_stolen":
				shield_transfers.append({"pos": ev.pos, "facing": ev.facing, "r": ev.r, "arc": ev.arc,
					"life": 0.3, "max": 0.3})
				_ring(ev.pos, ev.r * 1.7, Color("#65e8ff"), 0.3)
				shake = maxf(shake, 6.0)
			&"swallow":
				if swallows.size() < 120:
					swallows.append({"type": ev.enemy_type, "pos": ev.pos, "r": ev.r, "facing": ev.facing, "color": ev.color,
						"row": ev.row, "id": ev.id, "spin": ev.spin, "life": 0.3, "max": 0.3})
			&"gem_burst":
				_ring(ev.pos, float(ev.r) * 2.4, Color("#ffe27a"), 0.3)
				_burst(ev.pos, Color("#ffd23f"), 14, Vector2.ZERO, 360.0)
			&"summon_mark":
				summon_marks.append({"pos": ev.pos, "king": ev.king, "color": ev.color, "life": ev.life, "max": ev.life})
			&"cepheus_summon":
				_ring(ev.pos, 70.0, (ev.color as Color).lightened(0.4), 0.3)
			&"rock_break":
				_shatter_meteor(ev)
				_burst(ev.pos, ev.color, 10, ev.dir, 300.0)
				_ring(ev.pos, ev.r * 1.2, Color(1.0, 0.95, 0.6), 0.2)
			&"ruler_split":
				_ring(ev.pos, 46.0, (ev.color as Color).lightened(0.4), 0.3)
				_burst(ev.pos, ev.color, 10, Vector2.ZERO, 260.0)
				shake = maxf(shake, 4.0)
			&"bud":
				_ring(ev.pos, 20.0, ev.color, 0.25)
				_burst(ev.pos, ev.color, 6, Vector2.ZERO, 160.0)
			&"membrane_break":
				var pts: PackedVector2Array = ev.points
				for k in pts.size():
					var a: Vector2 = pts[k]
					var b: Vector2 = pts[(k + 1) % pts.size()]
					for s in 4:
						_burst(a.lerp(b, (s + 0.5) / 4.0), (ev.color as Color).lightened(0.4), 4, Vector2.ZERO, 240.0)
				shake = maxf(shake, 5.0)
			&"telescope_charge":
				_ring(ev.pos, 30.0, Color(1.0, 0.4, 0.3), 0.2)
			&"telescope_fire":
				# 太いレーザーの残光と、レンズの閃光
				var dir := Vector2.from_angle(ev.angle)
				beams.append({"from": ev.pos, "to": ev.pos + dir * float(ev.length), "width": float(ev.width) * 1.6, "life": 0.28,
					"max": 0.28, "color": Color(1.0, 0.3, 0.22)})
				_ring(ev.pos, 40.0, Color(1.0, 0.75, 0.6), 0.22)
				_burst(ev.pos, Color(1.0, 0.5, 0.35), 10, dir, 500.0)
				shake = maxf(shake, 9.0)
			&"shield_block":
				_ring(ev.pos, cfg.ship_radius * 3.0, Color("#bcefff"), 0.18)
			&"shield_expired":
				_burst(ev.pos, Color("#65e8ff"), 12, Vector2.ZERO, 180.0)
			&"bounce":
				shake = maxf(shake, 10.0)
			&"crash":
				shake = maxf(shake, 16.0)
			&"warp":
				_exhaust.clear()
				ghosts.append({"from": ev.from, "to": ev.to, "life": 0.18, "max": 0.18})
			&"beam":
				var life: float = ev.get("life", 0.4)
				beams.append({"from": ev.from, "to": ev.to, "width": ev.width, "life": life, "max": life,
					"color": ev.get("color", Color(1.0, 0.95, 0.6))})
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
	for list in [rings, texts, ghosts, impacts, trails, beams, bolts, shield_transfers, swallows, summon_marks]:
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
	shield_transfers = shield_transfers.filter(func(f): return f.life > 0.0)
	swallows = swallows.filter(func(f): return f.life > 0.0)
	summon_marks = summon_marks.filter(func(f): return f.life > 0.0)

# ── 層ごとの描画 ─────────────────────────────────────────────────

func _px(px: float) -> float:
	return px / maxf(cam_zoom, 0.01)

## 描画のカメラを決める。実験場では、ゲームの表示範囲（固定の大きさ）が表示枠に収まるように倍率を合わせる。
func _update_view() -> void:
	if view_override != null:
		cam_center = view_override.center
		cam_zoom = float(view_override.zoom)
		return
	cam_center = state.view_center
	cam_zoom = game_zoom()

## 描画のカメラの倍率。実験場は決まった大きさの画面（view_size）で計算する。本番の画面全体を実験場の枠に収める倍率と、
## 本番がこのウィンドウに映すのと同じ倍率の、中間（幾何平均）を使う（枠に収まらない端は切れる）。
func game_zoom() -> float:
	var zoom := state.camera_zoom if state.camera_zoom > 0.0 else run._base_zoom()
	if state.lab_mode:
		var sim: Vector2 = run.options.get("view_size", Vector2.ZERO)
		var shown := get_viewport().get_visible_rect().size
		var window := get_tree().root.get_visible_rect().size
		if sim.x > 0.0 and sim.y > 0.0:
			var fit := minf(shown.x / sim.x, shown.y / sim.y)
			var full := minf(window.x, window.y) / minf(sim.x, sim.y)
			zoom *= sqrt(fit * full)
	return zoom

## 描画のカメラに映る範囲（ワールド座標）。
func view_rect() -> Rect2:
	var half := get_viewport().get_visible_rect().size / 2.0 / maxf(cam_zoom, 0.0001)
	return Rect2(cam_center - half, half * 2.0)

## 星の円メッシュと乱数データは開始時に作り、GPUで位置・視差だけ更新する。
func _build_star_batch() -> void:
	_star_batch = InstanceBatch.new()
	_star_batch.setup_polygon(InstanceBatch.circle_points(16))
	var mm := _star_batch.multimesh
	mm.use_custom_data = true
	mm.instance_count = _stars.size()
	for i in _stars.size():
		var star := _stars[i]
		mm.set_instance_transform_2d(i, Transform2D.IDENTITY)
		mm.set_instance_custom_data(i, Color(star.x, star.y, star.z, 0.0))
		mm.set_instance_color(i, Color(0.7, 0.8, 1.0, 0.25 + 0.5 * star.z))
	_star_material = ShaderMaterial.new()
	_star_material.shader = preload("res://shaders/background_stars.gdshader")
	_star_batch.material = _star_material
	_layers.background.add_child(_star_batch)

func _draw_background(c: CanvasItem) -> void:
	var view := view_rect().grow(200.0)
	c.draw_rect(view, Color(0.08, 0.03, 0.12) if state.bonus_t > 0.0 else Color(0.02, 0.03, 0.07))
	_star_batch.visible = show_background
	_star_material.set_shader_parameter("view_center", cam_center)
	_star_material.set_shader_parameter("view_half", view_rect().size / 2.0)
	_star_material.set_shader_parameter("camera_zoom", cam_zoom)

func _draw_field(c: CanvasItem) -> void:
	var f := run.field
	var view := view_rect().grow(700.0)
	for d in f.dust:
		var center := Vector2(d.x, d.y)
		if view.has_point(center) or view.grow(d.z).has_point(center):
			c.draw_circle(center, d.z, Color(0.4, 0.35, 0.55, 0.08))
	c.draw_arc(Vector2.ZERO, cfg.field_radius, 0, TAU, 256, Color(1.0, 0.4, 0.4, 0.35), _px(2.0))
	_draw_hero(c)
	# ヘルクレス座の火の隕石：落ちてくる影と、燃える跡
	for fall in run.heroes.falls:
		var k := clampf(1.0 - fall.z / 0.6, 0.0, 1.0)
		var at := Vector2(fall.x, fall.y)
		c.draw_circle(at, 30.0 + 60.0 * k, Color(1.0, 0.4, 0.1, 0.12 + 0.25 * k))
		c.draw_circle(at - Vector2(-0.6, 1.0) * 500.0 * (1.0 - k), 22.0, Color("#ffb060"))
	for b in run.heroes.burns:
		var flick := 0.8 + 0.2 * sin(state.world_time * 18.0 + b.x)
		c.draw_circle(Vector2(b.x, b.y), 80.0 * flick, Color(1.0, 0.45, 0.1, 0.22 * minf(1.0, b.z)))
	# ワープホール：回る輪
	if f.warp_gone >= 0.0:
		var wr := cfg.warp_radius
		c.draw_circle(f.warp_pos, wr, Color(0.6, 0.3, 1.0, 0.25))
		for n in 3:
			var a0 := state.world_time * (2.0 + n) + n * 2.1
			c.draw_arc(f.warp_pos, wr * (0.5 + 0.2 * n), a0, a0 + PI * 1.4, 24, Color(0.85, 0.7, 1.0, 0.8), _px(3.0))
	# 重力：縮みながら渦を巻く
	for w in f.wells:
		var k := 1.0 - (state.world_time - w.born) / w.life
		var reach := w.radius * k
		c.draw_circle(w.pos, reach, Color(0.35, 0.2, 0.6, 0.12))
		for n in 3:
			var rr := reach * fposmod(1.0 - state.world_time * 0.6 - n / 3.0, 1.0)
			c.draw_arc(w.pos, maxf(rr, 1.0), 0, TAU, 40, Color(0.7, 0.55, 1.0, 0.35), _px(2.0))
		c.draw_circle(w.pos, maxf(6.0, reach * 0.08), Color(0.08, 0.02, 0.15, 0.9))
	for b in f.bodies:
		if view.grow(b.r).has_point(b.pos):
			c.draw_texture_rect(PLANET if b.is_planet else MOON,
				Rect2(b.pos - Vector2.ONE * b.r, Vector2.ONE * b.r * 2.0), false)

## 英雄の星座：うっすらと見える点線の星座線と、光った線。近くまで来ると星が恒星のように強く光る。
func _draw_hero(c: CanvasItem) -> void:
	var h := run.heroes
	if h.hero == null:
		return
	var view := view_rect().grow(900.0)
	if not view.has_point(h.center):
		return
	var near := clampf(1.0 - h.center.distance_to(state.ship_pos) / cfg.hero_glow_range, 0.0, 1.0)
	var gold := Color("#ffe8a0")
	var links := h.hero.links
	for n in h.lit.size():
		var a := h.stars[links[n * 2]]
		var b := h.stars[links[n * 2 + 1]]
		if h.lit[n] != 0:
			c.draw_line(a, b, Color(gold, 0.35), _px(9.0))
			c.draw_line(a, b, gold, _px(3.0))
		else:
			c.draw_dashed_line(a, b, Color(0.8, 0.85, 1.0, 0.25 + 0.25 * near), _px(2.0), _px(10.0))
	var pulse := 0.85 + 0.15 * sin(state.world_time * 3.0)
	for p in h.stars:
		if near > 0.0:
			# 恒星のような光：中心の芯と、細い光の筋
			c.draw_circle(p, cfg.hero_star_radius * (0.9 + 0.6 * near) * pulse, Color(1.0, 0.95, 0.75, 0.1 * near))
			c.draw_circle(p, cfg.hero_star_radius * 0.6, Color(1.0, 0.97, 0.85, 0.3 * near))
			for k in 4:
				var u := Vector2.from_angle(k * PI / 4.0) * cfg.hero_star_radius * (1.2 + 2.0 * near) * pulse
				c.draw_line(p - u, p + u, Color(1.0, 0.96, 0.8, (0.5 if k % 2 == 0 else 0.25) * near), _px(2.0))
		c.draw_circle(p, maxf(_px(3.0), cfg.hero_star_radius * 0.3), Color(1.0, 0.98, 0.9, 0.6 + 0.4 * near))

func _draw_pickups(c: CanvasItem) -> void:
	var p := run.pickups
	var view := view_rect().grow(60.0)
	# 経験値の結晶：画面上で最低 8px の高さ（仕様書 17）
	var gs := maxf(5.0, _px(4.0))
	var gems: InstanceBatch = _batches[&"gem"]
	gems.begin()
	var gem_alive := p.gem_alive
	var gem_pos := p.gem_pos
	for i in gem_alive.size():
		var pos := gem_pos[i]
		if gem_alive[i] != 0 and view.has_point(pos):
			gems.add(pos, 0.0, gs, XP_COLOR)
	gems.end()
	var cs := maxf(6.0, _px(3.5))
	_coin_batch.begin()
	var coin_alive := p.coin_alive
	var coin_pos := p.coin_pos
	for i in coin_alive.size():
		var pos := coin_pos[i]
		if coin_alive[i] != 0 and view.has_point(pos):
			_coin_batch.add(pos, 0.0, cs, COIN_COLOR)
	_coin_batch.end()
	for cap: Pickup in p.capsules:
		match cap.kind:
			Pickup.Kind.HEAL:
				c.draw_rect(Rect2(cap.pos - Vector2(14, 11), Vector2(28, 22)), Color.WHITE)
				c.draw_rect(Rect2(cap.pos - Vector2(3, 8), Vector2(6, 16)), Color("#e8434f"))
				c.draw_rect(Rect2(cap.pos - Vector2(8, 3), Vector2(16, 6)), Color("#e8434f"))
			Pickup.Kind.CORE:
				c.draw_circle(cap.pos, 18.0, Color("#ffd24a"))
				c.draw_arc(cap.pos, 26.0, 0, TAU, 32, Color("#fff2b0"), _px(2.0))
			Pickup.Kind.COMET_WEAPON:
				var pulse := 0.5 + 0.5 * sin(state.time * 5.0)
				c.draw_circle(cap.pos, 30.0 + pulse * 6.0, Color(1.0, 0.75, 0.25, 0.25))
				c.draw_colored_polygon(PackedVector2Array([cap.pos + Vector2(0, -22), cap.pos + Vector2(18, 0),
					cap.pos + Vector2(0, 22), cap.pos + Vector2(-18, 0)]), Color("#efcb70"))
				c.draw_circle(cap.pos, 7.0, Color("#fff1bf"))
			Pickup.Kind.MAGNET:
				c.draw_arc(cap.pos, 14.0, PI, TAU, 16, XP_COLOR, 6.0)
				c.draw_rect(Rect2(cap.pos + Vector2(-17, 0), Vector2(6, 10)), Color.WHITE)
				c.draw_rect(Rect2(cap.pos + Vector2(11, 0), Vector2(6, 10)), Color.WHITE)
			_:
				c.draw_circle(cap.pos, 14.0, XP_COLOR.darkened(0.2))
				c.draw_arc(cap.pos, 16.0, 0, TAU, 24, XP_COLOR.lightened(0.3), _px(2.0))

func _draw_enemies(c: CanvasItem) -> void:
	var view := view_rect().grow(cfg.max_enemy_radius)
	for key in _batches:
		if key != &"gem":
			_batches[key].begin()
	var t := run.enemies.table
	var alive := t.alive
	var dead := t.dead
	var pos := t.pos
	var elite := t.elite
	var weak := t.weak_arc
	var charge := t.charge
	var landmark := t.landmark
	var stone := t.stone
	var radius := t.r
	var hp := t.hp
	var max_hp := t.max_hp
	for i in alive.size():
		if alive[i] == 0 or dead[i] != 0:
			continue
		var p := pos[i]
		if not view.has_point(p):
			continue
		var type := t.type[i]
		# 色のr成分はスプライトシェーダーの被弾フラッシュ。
		var col := Color(1.0 if t.flash[i] > 0.0 and type != &"meteor" else 0.0, 0.0, 0.0, 1.0)
		if type == &"meteor":
			var comet := run.field.comet_at(t.meteor_index[i])
			if comet != null:
				_draw_comet(c, p, t.r[i], t.vel[i], comet.rare_weapon != &"")
				continue
			# ストリームで再生成されても同じ岩の模様を使う。
			var variant := posmod(t.meteor_index[i], 2)
			var stage := clampi(int((1.0 - t.hp[i] / t.max_hp[i]) * 3.0), 0, 2)
			var rock_key := StringName("meteor_" + str(variant) + "_damage_" + str(stage))
			var rock_batch: InstanceBatch = _batches[rock_key]
			rock_batch.add(p, t.facing[i], METEOR_SHEETS[variant].get_height() / 2.0, col)
			continue
		if t.is_boss[i] != 0 and run.bosses.actor != null and run.bosses.actor.draws_self:
			continue
		var batch: InstanceBatch = _batches.get(type, _batches[&"battleship"])
		if _shape_ids.has(type):
			batch.add(p, t.facing[i], t.r[i], Color.WHITE if t.flash[i] > 0.0 else t.color[i])
		elif type in NATIVE_SPRITES:
			batch.add(p, t.facing[i] + PI / 2.0, t.r[i], col)
		else:
			batch.add(p, t.facing[i] - PI / 2.0, t.r[i], col)
		# 飾りのある敵だけ、飾りを描く
		if elite[i] != 0 or weak[i] > 0.0 or charge[i] > 0.0 or landmark[i] != 0 or stone[i] > 0.0 \
				or (radius[i] >= 25.0 and hp[i] < max_hp[i]) or _always_marked.has(type):
			_draw_enemy_marks(c, t, i)
	for key in _batches:
		if key != &"gem":
			_batches[key].end()
	_draw_meteor_shards(c)
	_draw_swallows(c)
	_draw_summon_marks(c)

## ケフェウス座の召喚の予告：王から金の光が伸び、兵が現れる位置に紋章の輪が閉じていく。
func _draw_summon_marks(c: CanvasItem) -> void:
	for m in summon_marks:
		var k := 1.0 - float(m.life) / float(m.max)
		var col: Color = (m.color as Color).lightened(0.35)
		var at: Vector2 = m.pos
		c.draw_line(m.king, at, Color(1.0, 0.85, 0.45, 0.25 + 0.35 * k), _px(2.0))
		c.draw_arc(at, 30.0 * (1.6 - 0.6 * k), 0, TAU, 32, Color(col, 0.4 + 0.5 * k), _px(2.5))
		for q in 5:
			var a := state.world_time * 2.0 + q * TAU / 5.0
			c.draw_line(at + Vector2.from_angle(a) * 18.0, at + Vector2.from_angle(a) * (26.0 + 10.0 * (1.0 - k)), Color(1.0, 0.85, 0.45, 0.6 * k), _px(2.0))
		c.draw_circle(at, 6.0 + 8.0 * k, Color(1.0, 0.95, 0.75, 0.3 + 0.5 * k))

## ポンプ座に吸い込まれていく敵。自転しながら小さくなり、ポンプ座の口へ飛び込む。
func _draw_swallows(c: CanvasItem) -> void:
	var t := run.enemies.table
	for sw in swallows:
		var k := 1.0 - float(sw.life) / float(sw.max)
		var target: Vector2 = sw.pos
		if run.enemies.is_same(sw.row, sw.id):
			target = t.pos[sw.row] + Vector2.from_angle(t.facing[sw.row]) * t.r[sw.row] * EnemyManager.PUMP_MOUTH
		var p: Vector2 = (sw.pos as Vector2).lerp(target, k * k)
		var r: float = sw.r * (1.0 - 0.85 * k)
		var angle: float = sw.facing + float(sw.spin) * (float(sw.max) - float(sw.life))
		var tex := _enemy_texture(sw.type)
		if tex == null:
			c.draw_circle(p, r, sw.color)
			continue
		var size := tex.get_size() / maxf(tex.get_width(), tex.get_height()) * r * 2.0
		c.draw_set_transform(p, angle + (PI / 2.0 if sw.type in NATIVE_SPRITES else -PI / 2.0))
		c.draw_texture_rect(tex, Rect2(-size / 2.0, size), false)
		c.draw_set_transform(Vector2.ZERO)

## 彗星：光る核と、進む向きの反対へ伸びる尾。レアな彗星は金色で、周りを光の粒が回る（デザインとアートスタイル）。
## 専用の絵ができるまでの仮の描き方。
func _draw_comet(c: CanvasItem, p: Vector2, r: float, vel: Vector2, rare: bool) -> void:
	var u := vel.normalized() if vel.length_squared() > 1.0 else Vector2.RIGHT
	var n := Vector2(-u.y, u.x)
	var core := Color("#ffe9a0") if rare else Color("#dff6ff")
	var glow := Color("#ffb52e") if rare else Color("#7fd3ff")
	var tail_len := r * 9.0
	c.draw_polygon(PackedVector2Array([p + n * r * 0.9, p - u * tail_len, p - n * r * 0.9]),
		PackedColorArray([Color(glow, 0.55), Color(glow, 0.0), Color(glow, 0.55)]))
	c.draw_polygon(PackedVector2Array([p + n * r * 0.45, p - u * tail_len * 0.6, p - n * r * 0.45]),
		PackedColorArray([Color(core, 0.8), Color(core, 0.0), Color(core, 0.8)]))
	c.draw_circle(p, r * 1.35, Color(glow, 0.25))
	c.draw_circle(p, r, Color(glow, 0.55))
	c.draw_circle(p, r * 0.65, core)
	if rare:
		for k in 4:
			var a := state.time * 3.0 + k * TAU / 4.0
			c.draw_circle(p + Vector2.from_angle(a) * r * 1.7, maxf(3.0, r * 0.12), Color("#fff3c4"))

## 絵がまだない敵の仮の図形（+X が前、半径 1）。orb は円、diamond は菱形、hex は六角形、dart は矢じり、それ以外は四角。
static func _placeholder_points(shape: StringName) -> PackedVector2Array:
	match shape:
		&"orb":
			return InstanceBatch.circle_points(20)
		&"diamond":
			return PackedVector2Array([Vector2(1, 0), Vector2(0, 0.75), Vector2(-1, 0), Vector2(0, -0.75)])
		&"hex":
			return InstanceBatch.circle_points(6)
		&"dart":
			return PackedVector2Array([Vector2(1, 0), Vector2(-0.8, 0.7), Vector2(-0.4, 0), Vector2(-0.8, -0.7)])
		&"saw":
			# 歯の付いた円
			var pts := PackedVector2Array()
			for k in 24:
				pts.append(Vector2.from_angle(TAU * k / 24.0) * (1.0 if k % 2 == 0 else 0.78))
			return pts
	return PackedVector2Array([Vector2(0.8, -0.8), Vector2(0.8, 0.8), Vector2(-0.8, 0.8), Vector2(-0.8, -0.8)])

## 敵の種類の絵（牽引した船体を描くのに使う。絵のない種類は null）。
func _enemy_texture(type: StringName) -> Texture2D:
	if not _enemy_textures.has(type):
		var path := "res://assets/pixel/%s.png" % type
		_enemy_textures[type] = load(path) if ResourceLoader.exists(path) else null
	return _enemy_textures[type]

## 敵の船体を絵で描く（牽引中・撃ち出した船体）。glow は周りの光の色（透明なら光らせない）。
func _draw_hull(c: CanvasItem, type: StringName, p: Vector2, angle: float, r: float, glow: Color) -> void:
	var tex := _enemy_texture(type)
	if glow.a > 0.0:
		c.draw_circle(p, r * 1.1, Color(glow, 0.25))
	if tex == null:
		c.draw_circle(p, r, Color("#aeb6c4"))
		return
	var size := tex.get_size() / maxf(tex.get_width(), tex.get_height()) * r * 2.0
	c.draw_set_transform(p, angle + (PI / 2.0 if type in NATIVE_SPRITES else -PI / 2.0))
	c.draw_texture_rect(tex, Rect2(-size / 2.0, size), false)
	c.draw_set_transform(Vector2.ZERO)

## 数の少ない飾り（エリートの輪・背面の弱点・予告・HP バー）は個別に描く。
func _draw_enemy_marks(c: CanvasItem, t: EnemyTable, i: int) -> void:
	var p := t.pos[i]
	var r := t.r[i]
	if t.beh[i] == EnemyTable.Beh.SHIELD:
		SHIELD_VISUAL.enemy(c, t, i)
	if t.elite[i] != 0:
		c.draw_arc(p, r + _px(3.0), 0, TAU, 32, Color("#ffd24a"), _px(2.0))
	var weak := t.weak_arc[i]
	if weak > 0.0 and t.type[i] != &"armored" and t.beh[i] != EnemyTable.Beh.SHIELD:
		var f := t.facing[i]
		c.draw_arc(p, r + _px(2.0), f + PI - weak, f + PI + weak, 12, Color("#ffe46b"), _px(3.0))
	if t.landmark[i] != 0:
		# 目印の星：金色とも白ともつかない特別な光
		var tw := 0.75 + 0.25 * sin(state.world_time * 5.0 + float(t.id[i]))
		c.draw_circle(p, r * 2.2 * tw, Color(1.0, 0.95, 0.8, 0.16))
		c.draw_circle(p, r * 0.5, Color(1.0, 0.97, 0.88, 0.95))
		for k in 4:
			var u := Vector2.from_angle(k * PI / 2.0 + state.world_time) * r * 1.8 * tw
			c.draw_line(p - u, p + u, Color(1.0, 0.95, 0.75, 0.6), _px(2.0))
	if t.stone[i] > 0.0:
		# 石になっている
		c.draw_circle(p, r * 1.05, Color(0.62, 0.6, 0.58, 0.85))
		c.draw_arc(p, r * 1.05, 0, TAU, 20, Color(0.35, 0.33, 0.32), _px(2.0))
	var charge := t.charge[i]
	var type := t.type[i]
	if t.beh[i] == EnemyTable.Beh.PUMP:
		_draw_pump(c, t, i)
	elif type == &"bomber":
		_draw_bomber(c, t, i)
	elif type == &"splitter":
		_draw_splitter_crystals(c, t, i)
	elif type == &"beamer":
		_draw_beamer(c, t, i)
	elif type == &"pulser":
		_draw_pulser(c, t, i)
	elif type == &"telescope":
		_draw_telescope(c, t, i)
	elif type == &"lynx":
		_draw_lynx(c, t, i)
	elif type == &"ruler":
		_draw_ruler(c, t, i)
	elif type == &"reticle":
		_draw_reticle(c, t, i)
	elif charge > 0.0:
		# 撃つ前の予告：前の方に光が集まっていく
		var muzzle := p + Vector2.from_angle(t.facing[i]) * r
		c.draw_circle(muzzle, _px(3.0) + r * 0.45 * charge, Color(1.0, 0.9, 0.6, 0.35 + 0.55 * charge))
	if t.gate[i] == EnemyTable.Gate.MOUTH and t.mode[i] == EnemyTable.Mode.WINDUP:
		# 吸い込んでいる間は口が開いている
		c.draw_circle(p + Vector2.from_angle(t.facing[i]) * r * 0.6, r * 0.45, Color(0.1, 0.05, 0.15, 0.9))
		c.draw_arc(p, r * 2.4, 0, TAU, 32, Color(t.color[i], 0.25), _px(2.0))
	if t.gate[i] == EnemyTable.Gate.SHELL:
		if t.shell_open[i] > 0.0:
			# 殻が割れて、星がむき出しになっている
			c.draw_circle(p, r * 0.45, Color("#fff4b0"))
		else:
			# 殻：傷が増えるほど欠ける
			var hurt := clampf(t.shell_dmg[i] / float(t.def[i].params.shell_hp), 0.0, 1.0)
			c.draw_arc(p, r + _px(3.0), t.facing[i], t.facing[i] + TAU * (1.0 - hurt), 24, Color("#d9dde6"), _px(4.0))
	if t.beh[i] == EnemyTable.Beh.TRIANGLE and t.mode[i] != EnemyTable.Mode.RECOVER and t.parts[i].size() == 6:
		# 3つの星の間に張った光の膜。揺らめく内側の縁で厚みを見せる
		var parts := t.parts[i]
		var tri := PackedVector2Array([t.pos[parts[0]], t.pos[parts[2]], t.pos[parts[4]]])
		var shimmer := 0.5 + 0.5 * sin(state.world_time * 3.0 + float(t.id[i]))
		c.draw_colored_polygon(tri, Color(t.color[i], 0.1 + 0.06 * shimmer))
		var mid := (tri[0] + tri[1] + tri[2]) / 3.0
		for s: float in [0.82, 0.6]:
			var inner := PackedVector2Array()
			for v in tri:
				inner.append(mid + (v - mid) * (s + 0.04 * shimmer))
			inner.append(inner[0])
			c.draw_polyline(inner, Color(t.color[i].lightened(0.4), 0.18 * s), _px(1.5))
	if t.gate[i] == EnemyTable.Gate.CLAW:
		# ハサミ：構えから挟んだ直後まで開いている
		var open := t.mode[i] == EnemyTable.Mode.WINDUP or t.mode[i] == EnemyTable.Mode.RECOVER
		for side: float in [-1.0, 1.0]:
			var a := t.facing[i] + side * (0.75 if open else 0.35)
			c.draw_circle(p + Vector2.from_angle(a) * r * 1.15, r * 0.38, Color("#ffb38a") if open else t.color[i])
	if t.beh[i] == EnemyTable.Beh.AQUARIUS and t.mode[i] == EnemyTable.Mode.DASH:
		# 太い水流
		var u := Vector2.from_angle(t.facing[i])
		var v := Vector2(-u.y, u.x) * float(t.def[i].params.stream_width) * 0.5
		var a0 := p + u * r
		var a1 := a0 + u * float(t.def[i].params.stream_len)
		c.draw_colored_polygon(PackedVector2Array([a0 + v * 0.5, a1 + v, a1 - v, a0 - v * 0.5]), Color(0.45, 0.75, 1.0, 0.22))
	if t.beh[i] == EnemyTable.Beh.CEPHEUS and t.mode[i] == EnemyTable.Mode.WINDUP:
		# 召喚の間、王冠の光が強まる
		var k := t.charge[i]
		c.draw_arc(p, r * (1.15 + 0.3 * k), 0, TAU, 40, Color(1.0, 0.85, 0.4, 0.35 + 0.5 * k), _px(3.0))
		c.draw_circle(p - Vector2.from_angle(t.facing[i]) * r * 0.55, r * (0.15 + 0.2 * k), Color(1.0, 0.92, 0.6, 0.5 + 0.4 * k))
	if t.beh[i] == EnemyTable.Beh.SOLDIER and t.mode[i] == EnemyTable.Mode.RECOVER:
		# 王を失って崩れていく兵
		var flick := 0.5 + 0.5 * sin(state.world_time * 30.0 + float(t.id[i]))
		c.draw_arc(p, r * 1.3, 0, TAU, 20, Color(1.0, 0.3, 0.3, 0.4 + 0.4 * flick), _px(2.0))
	if t.beh[i] == EnemyTable.Beh.CROW and t.carry[i] > 0.0:
		_draw_crow_bundle(c, t, i)
	var hp := t.hp[i]
	var max_hp := t.max_hp[i]
	if (r >= 25.0 or t.is_boss[i] != 0) and hp < max_hp:
		var w := r * 1.6
		var top := p + Vector2(-w / 2.0, -r - _px(10.0))
		c.draw_rect(Rect2(top, Vector2(w, _px(4.0))), Color(0, 0, 0, 0.6))
		c.draw_rect(Rect2(top, Vector2(w * maxf(0.0, hp / max_hp), _px(4.0))), Color("#ff6b5a"))

## 自爆する雑魚：カウントダウンに入ると赤く膨らむ光と、残り時間の輪、後ろの導火線の火花が強まる。
func _draw_bomber(c: CanvasItem, t: EnemyTable, i: int) -> void:
	var p := t.pos[i]
	var r := t.r[i]
	var u := Vector2.from_angle(t.facing[i])
	var fuse := p - u * r * 0.95
	var now := state.world_time
	if t.mode[i] != EnemyTable.Mode.WINDUP:
		c.draw_circle(fuse, maxf(_px(1.5), r * 0.12) * (0.7 + 0.3 * sin(now * 30.0 + float(t.id[i]))), Color("#ffd36b"))
		return
	var k := t.charge[i]
	var throb := 0.5 + 0.5 * sin(state.world_time * (10.0 + 20.0 * k))
	c.draw_arc(p, r * (1.05 + 0.25 * k * throb), 0, TAU, 32, Color(1.0, 0.3, 0.2, 0.35 + 0.45 * k), maxf(_px(2.0), r * (0.15 + 0.2 * k)))
	c.draw_arc(p, r * 1.45, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - k), 32, Color(1.0, 0.85, 0.5, 0.9), maxf(_px(2.0), r * 0.18))
	for n in 4:
		var q := fuse + Vector2.from_angle(now * 25.0 + n * 1.7) * r * (0.25 + 0.35 * k)
		c.draw_circle(q, maxf(_px(1.5), r * (0.08 + 0.1 * k)), Color(1.0, 0.8 - 0.4 * float(n % 2), 0.3))

## 分裂する雑魚：体に詰まった経験値の結晶が透けて光る。倒すとこれがその場に全部落ちる。
func _draw_splitter_crystals(c: CanvasItem, t: EnemyTable, i: int) -> void:
	var p := t.pos[i]
	var r := t.r[i]
	var u := Vector2.from_angle(t.facing[i])
	var v := Vector2(-u.y, u.x)
	var pulse := 0.5 + 0.5 * sin(state.world_time * 3.0 + float(t.id[i]))
	c.draw_circle(p, r * 0.75, Color(1.0, 0.85, 0.3, 0.12 + 0.08 * pulse))
	for k in 3:
		var o := float(k - 1)
		var q := p + v * o * r * 0.42 - u * absf(o) * r * 0.1
		var s := r * (0.34 if k == 1 else 0.24)
		var pts := PackedVector2Array([q - u * s * 1.3, q + v * s * 0.75, q + u * s * 1.3, q - v * s * 0.75])
		c.draw_colored_polygon(pts, Color("#ffd23f"))
		pts.append(pts[0])
		c.draw_polyline(pts, Color("#fff4c0"), maxf(_px(1.0), s * 0.18))

## ビームの敵：構えると、周りの光の粒が砲口へ吸い込まれて集まり、撃つ瞬間に砲口が白く光る。
func _draw_beamer(c: CanvasItem, t: EnemyTable, i: int) -> void:
	var p := t.pos[i]
	var r := t.r[i]
	var muzzle := p + Vector2.from_angle(t.facing[i]) * r * 0.9
	var col := t.color[i].lightened(0.35)
	var k := t.charge[i]
	if t.mode[i] != EnemyTable.Mode.WINDUP:
		c.draw_circle(muzzle, maxf(_px(1.5), r * 0.1), Color(col, 0.6))
		return
	if k < 1.0:
		for n in 8:
			var f := fmod(k * 2.5 + n / 8.0, 1.0)
			var q := muzzle + Vector2.from_angle(n * TAU / 8.0 + k * 3.0) * r * (1.8 - 1.6 * f)
			c.draw_circle(q, maxf(_px(1.5), r * 0.08), Color(col, f))
		c.draw_circle(muzzle, _px(2.0) + r * 0.45 * k, Color(col, 0.25 + 0.5 * k))
		c.draw_circle(muzzle, _px(1.5) + r * 0.2 * k, Color(1, 1, 1, 0.5 + 0.5 * k))
	else:
		c.draw_circle(muzzle, r * 0.7, Color(1, 1, 1, 0.55))
		c.draw_circle(muzzle, r * 0.45, Color(col, 0.9))

## 波動の敵：次の輪までの溜まり具合で中心の光が強まり、構えると光の輪が中心へ縮んで集まる。
func _draw_pulser(c: CanvasItem, t: EnemyTable, i: int) -> void:
	var p := t.pos[i]
	var r := t.r[i]
	var dp: Dictionary = t.def[i].params
	var col := t.color[i].lightened(0.4)
	if t.mode[i] == EnemyTable.Mode.WINDUP:
		var k := 1.0 - clampf(t.timer[i] / float(dp.telegraph), 0.0, 1.0)
		for n in 3:
			var f := fmod(k * 1.5 + n / 3.0, 1.0)
			c.draw_arc(p, r * (2.4 - 2.0 * f), 0, TAU, 32, Color(col, f * 0.8), _px(2.0))
		c.draw_circle(p, r * (0.25 + 0.2 * k), Color(1, 1, 1, 0.6 + 0.4 * k))
		return
	var ready := 1.0 - clampf(t.fire_t[i] / float(dp.fire_interval), 0.0, 1.0)
	c.draw_circle(p, r * (0.12 + 0.14 * ready), Color(col, 0.3 + 0.6 * ready))
	var spin := state.world_time * 2.0
	for n in 3:
		var a := spin + n * TAU / 3.0
		c.draw_arc(p, r * 1.18, a, a + 0.8 * ready, 8, Color(col, 0.6 * ready), _px(2.0))

## ぼうえんきょう座：レンズから伸びるサーチライトの帯。狙いが溜まるほど細く赤くなり、本体の周りの輪が狙いの溜まり具合を示す。
## 光は隕石・惑星・月で遮られ、その裏には描かない（光線の束の届く長さで形を作る）。
## 機体が光の中にいる間は帯が明るくなる。撃ったあとの休みの間は暗い。
func _draw_telescope(c: CanvasItem, t: EnemyTable, i: int) -> void:
	var p := t.pos[i]
	var r := t.r[i]
	var dp: Dictionary = t.def[i].params
	var k := t.charge[i]
	var f := t.facing[i]
	var lens := run.enemies.telescope_lens(i)
	var half := run.enemies.telescope_half(i)
	var length := float(dp.band_len)
	var rays := run.enemies.telescope_rays(i)
	var col := Color(0.62, 0.9, 1.0).lerp(Color(1.0, 0.22, 0.2), k)
	var resting := t.mode[i] == EnemyTable.Mode.RECOVER
	var seen := run.enemies.telescope_sight(i, state.ship_pos) == 1
	var a0 := (0.06 if resting else 0.16 + 0.22 * k) + (0.08 if seen else 0.0)
	var count := rays.size()
	if count < 2:
		return
	var pts := PackedVector2Array([lens])
	var cols := PackedColorArray([Color(col, a0)])
	for n in count:
		var reach := rays[n]
		pts.append(lens + Vector2.from_angle(f - half + 2.0 * half * n / float(count - 1)) * reach)
		cols.append(Color(col, a0 * (1.0 - reach / length)))
	if t.mode[i] == EnemyTable.Mode.WINDUP:
		# レーザーの溜め：帯がすぼまって赤い照準線になり脈打つ。光の粒がレンズへ吸い込まれ、レンズの光が膨らむ
		var w := 1.0 - clampf(t.timer[i] / float(dp.laser_charge), 0.0, 1.0)
		var reach := run.enemies.telescope_reach(i, f)
		var pulse := 0.5 + 0.5 * sin(state.world_time * (30.0 + 40.0 * w))
		var tip := lens + Vector2.from_angle(f) * reach
		c.draw_line(lens, tip, Color(1.0, 0.25, 0.2, 0.25 + 0.35 * pulse), maxf(_px(2.0), 4.0 + 10.0 * w))
		c.draw_line(lens, tip, Color(1.0, 0.85, 0.8, 0.5 + 0.4 * pulse), maxf(_px(1.0), 1.5 + 2.0 * w))
		for n in 10:
			var fr := fmod(w * 3.0 + n / 10.0, 1.0)
			var q := lens + Vector2.from_angle(n * TAU / 10.0 + w * 4.0) * r * (2.4 - 2.2 * fr)
			c.draw_circle(q, maxf(_px(1.5), r * 0.07), Color(1.0, 0.45, 0.3, fr))
		c.draw_circle(lens, r * (0.35 + 0.6 * w), Color(1.0, 0.3, 0.22, 0.35 + 0.3 * pulse))
		c.draw_circle(lens, r * (0.18 + 0.3 * w), Color(1.0, 0.92, 0.85, 0.9))
		return
	c.draw_polygon(pts, cols)
	c.draw_line(lens, pts[1], Color(col, a0 * 1.6), _px(1.5))
	c.draw_line(lens, pts[count], Color(col, a0 * 1.6), _px(1.5))
	c.draw_circle(lens, _px(2.0) + r * (0.2 + 0.2 * k), Color(col, 0.5 + 0.4 * k))
	if k > 0.0:
		c.draw_arc(p, r * 1.35, -PI / 2.0, -PI / 2.0 + TAU * k, 32, Color(col, 0.9), maxf(_px(2.0), r * 0.12))

## レチクル座：狙っている岩の周りに照準の四隅が縮みながら回り込み、本体から岩へ細い照準線が伸びる。
func _draw_reticle(c: CanvasItem, t: EnemyTable, i: int) -> void:
	var col := t.color[i].lightened(0.2)
	var p := t.pos[i]
	var r := t.r[i]
	var lens := p + Vector2.from_angle(t.facing[i]) * r
	c.draw_circle(lens, maxf(_px(1.5), r * 0.12), Color(col, 0.7))
	if t.mode[i] != EnemyTable.Mode.WINDUP:
		return
	var rock := t.target[i]
	if not run.enemies.is_same(rock, t.target_id[i]):
		return
	var k := t.charge[i]
	var at := t.pos[rock]
	var size := t.r[rock] * (1.6 - 0.5 * k)
	var spin := PI / 4.0 * (1.0 - k)
	for q in 4:
		var a := spin + q * PI / 2.0
		var corner := at + Vector2.from_angle(a) * size * 1.41
		var u := Vector2.from_angle(a + PI * 0.75)
		var v := Vector2.from_angle(a - PI * 0.75)
		c.draw_line(corner, corner + u * size * 0.5, Color(col, 0.5 + 0.5 * k), maxf(_px(2.0), 3.0))
		c.draw_line(corner, corner + v * size * 0.5, Color(col, 0.5 + 0.5 * k), maxf(_px(2.0), 3.0))
	c.draw_line(at - Vector2(size * 0.3, 0), at + Vector2(size * 0.3, 0), Color(col, 0.6 * k), _px(1.5))
	c.draw_line(at - Vector2(0, size * 0.3), at + Vector2(0, size * 0.3), Color(col, 0.6 * k), _px(1.5))
	var gap := at - lens
	var steps := int(gap.length() / 18.0)
	for n in range(0, steps, 2):
		c.draw_line(lens + gap * (float(n) / steps), lens + gap * (float(n + 1) / steps), Color(col, 0.25 + 0.5 * k), _px(1.5))

## じょうぎ座：照射の予告は、発射元から照射の向きへ伸びる点線。予告が進むほど濃く、先端の光が強まる。
func _draw_ruler(c: CanvasItem, t: EnemyTable, i: int) -> void:
	var p := t.pos[i]
	var r := t.r[i]
	var u := Vector2.from_angle(t.facing[i])
	var tip := p + u * r
	var col := t.color[i].lightened(0.2)
	if t.mode[i] == EnemyTable.Mode.WINDUP:
		var k := t.charge[i]
		var length := float(t.def[i].params.beam_len)
		var dash := 36.0
		var s := 0.0
		while s < length:
			c.draw_line(tip + u * s, tip + u * minf(s + dash * 0.55, length), Color(col, 0.25 + 0.6 * k), maxf(_px(2.0), 3.0 + 4.0 * k))
			s += dash
		c.draw_circle(tip, r * (0.2 + 0.4 * k), Color(1, 1, 1, 0.4 + 0.5 * k))
	elif t.mode[i] == EnemyTable.Mode.DASH and t.buds[i] != 0:
		c.draw_circle(tip, r * 0.18, Color(col, 0.6))

## やまねこ座の斬撃：潰れた弧の3本の爪痕。外側の光、橙の芯、白い刃の3重で描く。a は濃さ。
func _draw_slash(c: CanvasItem, pos: Vector2, travel: float, size: float, side: float, a: float) -> void:
	var thick := ProjectileManager.SLASH_THICK * size
	for k in 3:
		var pts := ProjectileManager.slash_points(pos, travel, size, side, k)
		c.draw_polyline(pts, Color(1.0, 0.45, 0.15, 0.28 * a), thick * 2.2)
		c.draw_polyline(pts, Color(1.0, 0.55, 0.22, 0.95 * a), thick)
		c.draw_polyline(pts.slice(1, pts.size() - 1), Color(1.0, 0.95, 0.85, a), maxf(_px(1.5), thick * 0.3))

## やまねこ座：構えると、次に斬撃を伸ばす側の前足に、爪痕の光が強まる。
func _draw_lynx(c: CanvasItem, t: EnemyTable, i: int) -> void:
	var k := t.charge[i]
	if k <= 0.0:
		return
	var r := t.r[i]
	var f := t.facing[i]
	var u := Vector2.from_angle(f)
	var side := run.enemies.lynx_side(i)
	var paw := t.pos[i] + u * r * 0.55 + Vector2(-u.y, u.x) * side * r * 0.6
	c.draw_circle(paw, r * (0.25 + 0.35 * k), Color(1.0, 0.55, 0.2, 0.25 * k))
	_draw_slash(c, paw, f, r * (0.5 + 0.5 * k), side, 0.3 + 0.7 * k)

## ポンプ座の絵（pump.png、48px）の継ぎ目の帯。前（画像の下）を + にした絵の中心からの位置と、半分の長さ（px）
const PUMP_SEAMS := [[-10.5, 14.7], [-3.0, 16.4], [4.5, 14.7]]

## ポンプ座：吸い込んだ数に応じて継ぎ目から光が漏れ、口へ流れ込む吸い込みの筋を描く。
## 構えている間は胴体が張り詰めて脈打ち、継ぎ目が強く光り、口元に巨大な塊がせり出す。
func _draw_pump(c: CanvasItem, t: EnemyTable, i: int) -> void:
	var p := t.pos[i]
	var r := t.r[i]
	var dp: Dictionary = t.def[i].params
	var full := clampf(float(t.buds[i]) / float(dp.store_max), 0.0, 1.0)
	var aiming := t.mode[i] == EnemyTable.Mode.WINDUP
	var px := r / 24.0
	var u := Vector2.from_angle(t.facing[i])
	var side := Vector2(-u.y, u.x)
	var mouth := p + u * r * EnemyManager.PUMP_MOUTH
	var now := state.world_time
	if t.mode[i] == EnemyTable.Mode.MOVE:
		# 口へ流れ込む吸い込みの筋（外から口へ動く短い光）
		for k in 9:
			var phase := fmod(now * 1.4 + k * 0.381966, 1.0)
			var ang := t.facing[i] + (float(k) - 4.0) * 0.26
			var dist := r * (2.6 - 2.2 * phase)
			var head := mouth + Vector2.from_angle(ang) * dist
			var tail := mouth + Vector2.from_angle(ang) * (dist + r * 0.5)
			c.draw_line(tail, head, Color(t.color[i].lightened(0.55), 0.55 * sin(phase * PI)), _px(2.0))
	# 継ぎ目から漏れる光：吸い込むほど強く、構えると白熱して脈打つ
	var pulse := 0.5 + 0.5 * sin(now * (22.0 if aiming else 5.0))
	var glow := Color("#fff0c8") if aiming else t.color[i].lightened(0.55)
	var a := (0.85 + 0.15 * pulse) if aiming else full * (0.55 + 0.25 * pulse)
	if a > 0.02:
		for seam in PUMP_SEAMS:
			var center: Vector2 = p + u * float(seam[0]) * px
			var half: Vector2 = side * float(seam[1]) * px * 0.92
			c.draw_line(center - half, center + half, Color(glow, a * 0.35), maxf(_px(2.0), px * 4.5))
			c.draw_line(center - half, center + half, Color(glow, a), maxf(_px(1.0), px * 1.6))
	if aiming:
		# 張り詰めた胴体の縁と、口元にせり出す塊
		c.draw_arc(p + u * -3.0 * px, 16.5 * px * (1.03 + 0.03 * pulse), 0, TAU, 48, Color(glow, 0.55 + 0.35 * pulse), maxf(_px(2.0), px * 1.5))
		var ball := float(dp.shell_r) * (0.35 + 0.65 * t.charge[i])
		var at := mouth + u * ball * 0.55
		_draw_shell_ball(c, at, ball, t.color[i], now)

## 圧縮した敵の塊（構えている口元と、撃った圧縮弾）。張り詰めた膜の中に、押し込められた敵がひしめいて回る。
func _draw_shell_ball(c: CanvasItem, at: Vector2, r: float, base: Color, now: float) -> void:
	var pulse := 0.5 + 0.5 * sin(now * 14.0)
	c.draw_circle(at, r * (1.25 + 0.08 * pulse), Color(base.lightened(0.5), 0.22))
	c.draw_circle(at, r, base.darkened(0.45))
	var kinds: Array[StringName] = [&"drifter", &"swarm", &"drifter", &"splitling", &"swarm", &"drifter", &"swarm"]
	for k in kinds.size():
		var ring := 0.0 if k == 0 else 0.55
		var a := now * (1.5 if k % 2 == 0 else -1.1) + k * TAU / 6.0
		var q := at + Vector2.from_angle(a) * r * ring
		var tex := _enemy_texture(kinds[k])
		var size := r * (0.62 if k == 0 else 0.5)
		if tex == null:
			c.draw_circle(q, size * 0.5, base)
			continue
		var ext := tex.get_size() / maxf(tex.get_width(), tex.get_height()) * size
		c.draw_set_transform(q, a * 2.0)
		c.draw_texture_rect(tex, Rect2(-ext / 2.0, ext), false, Color(1, 1, 1, 0.9))
		c.draw_set_transform(Vector2.ZERO)
	c.draw_circle(at, r, Color(base.lightened(0.3), 0.18))
	c.draw_arc(at, r, 0, TAU, 40, Color("#fff0c8", 0.75 + 0.25 * pulse), maxf(_px(1.5), r * 0.1))

## からす座が足に抱えた経験値の結晶の束（尾の側の足元）。運んでいる量が多いほど大きく、明るく光る。
func _draw_crow_bundle(c: CanvasItem, t: EnemyTable, i: int) -> void:
	var p := t.pos[i]
	var r := t.r[i]
	var n := clampi(t.buds[i], 1, 12)
	var amount := clampf(sqrt(t.carry[i]) / 8.0, 0.0, 1.0)
	var u := Vector2.from_angle(t.facing[i])
	var side := Vector2(-u.y, u.x)
	var center := p - u * r * 0.62
	var s := maxf(_px(2.0), r * (0.07 + 0.05 * amount))
	var pulse := 0.5 + 0.5 * sin(state.world_time * 6.0)
	c.draw_circle(center, s * (2.2 + 1.6 * amount), Color(XP_COLOR.lightened(0.3), 0.1 + 0.2 * amount * (0.6 + 0.4 * pulse)))
	# 足の爪
	for k: float in [-1.0, 1.0]:
		c.draw_line(center + side * s * 1.2 * k + u * s * 2.2, center + side * s * 1.8 * k + u * s * 0.4, Color("#d8d2dc"), maxf(_px(1.0), s * 0.4))
	var col := XP_COLOR.lightened(0.15 + 0.4 * amount)
	var edge := XP_COLOR.darkened(0.55)
	for k in n:
		var ring := 0 if k == 0 else (1 if k < 7 else 2)
		var a := float(k) * 2.399963
		var q := center + (side * cos(a) - u * sin(a) * 0.8) * s * 1.4 * float(ring)
		var pts := PackedVector2Array([q - u * s * 1.3, q + side * s * 0.8, q + u * s * 1.3, q - side * s * 0.8])
		c.draw_colored_polygon(pts, col)
		pts.append(pts[0])
		c.draw_polyline(pts, edge, maxf(_px(1.0), s * 0.22))
		c.draw_line(q - u * s * 0.8, q - side * s * 0.3, Color(1, 1, 1, 0.75), maxf(_px(1.0), s * 0.22))

func _draw_projectiles(c: CanvasItem) -> void:
	var view := view_rect().grow(40.0)
	for t in trails:
		var a: float = t.life / t.max
		var pts: PackedVector2Array = t.points
		if pts.size() > 1:
			c.draw_polyline(pts, Color(1.0, 0.6, 0.25, 0.6 * a), _px(3.0))
	var pr := run.projectiles
	var friend_alive := pr.friend_alive
	var friend_pos := pr.friend_pos
	for i in friend_alive.size():
		var pos := friend_pos[i]
		if friend_alive[i] == 0 or not view.has_point(pos):
			continue
		var r := pr.friend_r[i]
		if pr.friend_type[i] == &"saw":
			var pts := PackedVector2Array()
			for k in 24:
				pts.append(pos + Vector2.from_angle(pr.friend_angle[i] + TAU * k / 24.0) * r * (1.0 if k % 2 == 0 else 0.78))
			c.draw_colored_polygon(pts, Color("#d9dde6"))
		elif pr.friend_kind[i] == ProjectileManager.FriendKind.HULL:
			_draw_hull(c, pr.friend_type[i], pos, pr.friend_vel[i].angle(), r, Color("#ffbe65"))
		elif pr.friend_kind[i] == ProjectileManager.FriendKind.DEBRIS:
			var trail := pr.friend_trail[i]
			if trail.size() > 1:
				c.draw_polyline(trail, Color(1.0, 0.6, 0.25, 0.7), _px(3.0))
			var u := Vector2.from_angle(pr.friend_angle[i]) * r
			var v := Vector2(-u.y, u.x) * 0.6
			c.draw_colored_polygon(PackedVector2Array([pos + u, pos + v, pos - u * 0.7, pos - v]), Color("#aeb6c4"))
			c.draw_polyline(PackedVector2Array([pos + u, pos + v, pos - u * 0.7, pos - v, pos + u]), Color("#ff9a3c"), _px(1.5))
		else:
			var dir := pr.friend_vel[i].normalized()
			c.draw_line(pos - dir * r * 2.2, pos + dir * r * 1.2, Color("#9fe8ff"), maxf(_px(3.0), r * 0.9))
	_hostile_batch.begin()
	var hostile_alive := run.projectiles.hostile_alive
	var hostile_pos := run.projectiles.hostile_pos
	var hostile_r := run.projectiles.hostile_r
	for i in hostile_alive.size():
		var pos := hostile_pos[i]
		if hostile_alive[i] != 0 and view.has_point(pos):
			if pr.hostile_kind[i] == ProjectileManager.HostileKind.BOLT:
				# ケフェウス座の兵の細長い光弾
				var u := pr.hostile_vel[i].normalized()
				c.draw_line(pos - u * 34.0, pos + u * 6.0, Color(0.75, 0.6, 1.0, 0.35), 14.0)
				c.draw_line(pos - u * 30.0, pos + u * 4.0, Color(0.85, 0.75, 1.0), 6.0)
				c.draw_line(pos - u * 24.0, pos + u * 2.0, Color(1, 1, 1, 0.95), 2.5)
			elif pr.hostile_kind[i] == ProjectileManager.HostileKind.SLASH:
				_draw_slash(c, pos, pr.hostile_vel[i].angle(), hostile_r[i], pr.hostile_turn[i], 1.0)
			elif pr.hostile_kind[i] == ProjectileManager.HostileKind.SHELL:
				# ポンプ座の圧縮弾：後ろに尾を引く
				var u := pr.hostile_vel[i].normalized()
				var n := Vector2(-u.y, u.x) * hostile_r[i] * 0.8
				c.draw_polygon(PackedVector2Array([pos + n, pos - u * hostile_r[i] * 2.2, pos - n]),
					PackedColorArray([Color(0.85, 0.7, 1.0, 0.45), Color(0.85, 0.7, 1.0, 0.0), Color(0.85, 0.7, 1.0, 0.45)]))
				_draw_shell_ball(c, pos, hostile_r[i], Color("#b78cff"), state.world_time)
			elif pr.hostile_kind[i] == ProjectileManager.HostileKind.REFLECTED:
				var u := pr.hostile_vel[i].normalized()
				c.draw_line(pos - u * hostile_r[i] * 3.0, pos, Color("#ff84df"), hostile_r[i] * 0.9)
				c.draw_circle(pos, hostile_r[i], Color("#f45ec5"))
				c.draw_circle(pos, hostile_r[i] * 0.5, Color("#fff0fc"))
			else:
				_hostile_batch.add(pos, 0.0, hostile_r[i], Color.WHITE)
			if run.projectiles.hostile_stone[i] > 0.0:
				c.draw_circle(pos, hostile_r[i] * 1.3, Color(0.62, 0.6, 0.58, 0.9))
	_hostile_batch.end()
	_draw_hazards(c, view)

## 敵の攻撃の形（仕様書 11.7）。予告は攻撃する敵の側の光や模様で見せ、当たる範囲そのものは予告しない。
func _draw_hazards(c: CanvasItem, view: Rect2) -> void:
	var pr := run.projectiles
	var alive := pr.hazard_alive
	for i in alive.size():
		if alive[i] == 0:
			continue
		var p := pr.hazard_pos[i]
		var t := pr.hazard_t[i]
		var delay := pr.hazard_delay[i]
		var col := pr.hazard_color[i]
		var len := pr.hazard_len[i]
		var charging := t < delay
		var k := clampf(t / maxf(delay, 0.001), 0.0, 1.0)
		match pr.hazard_kind[i]:
			ProjectileManager.HazardKind.BEAM:
				if charging:
					# 砲口に光が集まっていく
					c.draw_circle(p, _px(4.0) + 10.0 * k, Color(col, 0.25 + 0.5 * k))
					continue
				var b := p + Vector2.from_angle(pr.hazard_angle[i]) * len
				if not view.grow(len).has_point(p):
					continue
				var w := pr.hazard_width[i]
				var fade := 1.0 - clampf((t - delay) / maxf(pr.hazard_active[i], 0.001), 0.0, 1.0) * 0.6
				c.draw_line(p, b, Color(col, 0.35 * fade), w * 1.6)
				c.draw_line(p, b, Color(col, 0.9 * fade), w)
				c.draw_line(p, b, Color(1, 1, 1, 0.85 * fade), maxf(_px(2.0), w * 0.3))
			ProjectileManager.HazardKind.ZONE:
				if not view.grow(len).has_point(p):
					continue
				var style := pr.hazard_style[i]
				if charging:
					if style == ProjectileManager.HazardStyle.RETICLE or style == ProjectileManager.HazardStyle.LIGHTNING:
						# 照準の模様（敵が刻む印）。溜まるほど濃く、内側の輪が閉じていく
						var a := 0.25 + 0.55 * k
						c.draw_arc(p, len, 0.0, TAU, 40, Color(col, a), _px(2.0))
						c.draw_arc(p, len * (1.0 - 0.7 * k), 0.0, TAU, 32, Color(col, a), _px(1.5))
						for q in 4:
							var u := Vector2.from_angle(q * PI / 2.0 + PI / 4.0)
							c.draw_line(p + u * len * 0.55, p + u * len * 1.15, Color(col, a), _px(2.0))
					else:
						# 弾ける前の点滅
						if fmod(t, 0.16) < 0.08:
							c.draw_circle(p, _px(6.0), Color(col, 0.9))
					continue
				var f := 1.0 - clampf((t - delay) / maxf(pr.hazard_active[i], 0.001), 0.0, 1.0)
				c.draw_circle(p, len, Color(col, 0.45 * f))
				c.draw_arc(p, len, 0.0, TAU, 40, Color(1, 1, 1, 0.8 * f), _px(3.0))
				if style == ProjectileManager.HazardStyle.LIGHTNING:
					var q := p + Vector2(0, -len * 3.0)
					var pts := PackedVector2Array([q])
					for s in 6:
						q = q.lerp(p, 0.4) + Vector2((s % 2 * 2 - 1) * len * 0.25, 0)
						pts.append(q)
					pts.append(p)
					c.draw_polyline(pts, Color(1, 1, 0.85, f), _px(4.0))
			ProjectileManager.HazardKind.WAVE:
				if charging:
					c.draw_circle(p, _px(4.0) + 8.0 * k, Color(col, 0.2 + 0.5 * k))
					continue
				var rad := pr.wave_radius(i)
				if rad <= 0.0 or not view.grow(rad).has_point(p):
					continue
				var w := pr.hazard_width[i]
				var arc := pr.hazard_arc[i]
				var center := pr.hazard_angle[i]
				var gap_w := pr.hazard_gap_w[i]
				var fade := 1.0 - 0.5 * clampf(rad / maxf(len, 1.0), 0.0, 1.0)
				if gap_w > 0.0:
					# 切れ目の反対側から一周、切れ目を空けて描く
					var g := pr.hazard_gap[i]
					c.draw_arc(p, rad, g + gap_w, g + TAU - gap_w, 48, Color(col, 0.85 * fade), w)
				else:
					c.draw_arc(p, rad, center - arc, center + arc, 48, Color(col, 0.85 * fade), w)
			ProjectileManager.HazardKind.WALL:
				var b := p + Vector2.from_angle(pr.hazard_angle[i]) * len
				if not view.grow(len).has_point(p):
					continue
				var w := pr.hazard_width[i]
				if pr.hazard_style[i] == ProjectileManager.HazardStyle.RAY and not charging:
					# じょうぎ座のビーム：発射元から伸びる、揺らめく光の柱
					var left := delay + pr.hazard_active[i] - t
					var f := clampf(left / 0.3, 0.0, 1.0) * clampf((t - delay) / 0.12, 0.0, 1.0)
					var flick := 0.85 + 0.15 * sin(t * 50.0 + float(i))
					c.draw_line(p, b, Color(col, 0.22 * f), w * 2.6 * flick)
					c.draw_line(p, b, Color(col.lightened(0.2), 0.9 * f), w)
					c.draw_line(p, b, Color(1, 1, 1, 0.9 * f), maxf(_px(2.0), w * 0.35))
					c.draw_circle(p, w * (0.9 + 0.2 * flick), Color(1, 1, 1, 0.8 * f))
					continue
				if charging:
					c.draw_line(p, b, Color(col, 0.15 + 0.35 * k), maxf(_px(2.0), w * 0.25 * k))
					continue
				var left := delay + pr.hazard_active[i] - t
				var f := clampf(left / 0.4, 0.0, 1.0)
				c.draw_line(p, b, Color(col, 0.35 * f), w * 1.5)
				c.draw_line(p, b, Color(col, 0.9 * f), w)

func _draw_path_band(c: CanvasItem) -> void:
	# ふたご座：取っておいた1本目と、双子の機体がなぞる線
	for twin in [state.twin_first, state.twin_path]:
		var tp: PackedVector2Array = twin
		if tp.size() > 1:
			c.draw_polyline(tp, Color(0.75, 0.9, 1.0, 0.5), cfg.wave_radius * 2.0)
	if state.twin_tracing:
		c.draw_circle(state.twin_pos, cfg.ship_radius * 1.3, Color(0.75, 0.92, 1.0, 0.55))
		c.draw_circle(state.twin_pos, cfg.ship_radius * 0.7, Color(1.0, 1.0, 1.0, 0.9))
	var pts := state.draw_points if state.drawing else state.trace_path
	if pts.size() < 2:
		return
	var leo := run.combat.leo_width()
	var color := Color(1.0, 0.85, 0.45) if leo > 1.0 else Color(0.55, 0.9, 1.0)
	var w := cfg.wave_radius * leo
	for i in pts.size() - 1:
		c.draw_line(pts[i], pts[i + 1], color, w * 2.0)
	for point in pts:
		c.draw_circle(point, w, color)

func _draw_path(c: CanvasItem) -> void:
	if state.drawing and state.draw_points.size() > 0:
		var pts := state.draw_points
		# 今の位置から描き始めまでの移動（なぞりで一緒に駆け抜ける）を点線で示す
		var gap := pts[0] - state.ship_pos
		var steps := int(gap.length() / _px(14.0))
		for k in range(0, steps, 2):
			c.draw_line(state.ship_pos + gap * (float(k) / steps), state.ship_pos + gap * (float(k + 1) / steps), Color(0.8, 0.97, 1.0, 0.55), _px(2.0))
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
	var tow = b.weapon_behaviors.get(&"W21")
	if tow != null:
		for j in mini(int(tow.p("visible")), tow.cargo.size()):
			var h: Dictionary = tow.cargo[j]
			_draw_hull(c, h.type, h.pos, h.angle, h.r, Color.TRANSPARENT)
	var bipolar = b.weapon_behaviors.get(&"W22")
	if bipolar != null and bipolar.origin != null:
		var o: Vector2 = bipolar.origin
		var col := Color(bipolar.p("color", "#69fff0"))
		c.draw_arc(o, 26.0, 0, TAU, 24, col, _px(3.0))
		c.draw_circle(o, 9.0, col)
		c.draw_line(o, state.ship_pos, Color(col, 0.25), _px(2.0))
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
		var bc: Color = bm.color
		c.draw_line(bm.from, bm.to, Color(bc.r, bc.g, bc.b, 0.7 * k), bm.width)
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
		var size := int(t.size / maxf(cam_zoom, 0.25))
		c.draw_string(_font, t.pos - Vector2(size * 0.8, 0), t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

## 敗北の暗転（機体以外を暗くする。仕様書 16）。
func _draw_dim(c: CanvasItem) -> void:
	if state.phase == RunState.Phase.DYING:
		c.draw_rect(view_rect().grow(400.0), Color(0, 0, 0, cfg.death_world_dim))

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
	var sonic := run.build.weapon_behaviors.has(&"W08")
	var trail_color := Color(0.3, 0.65, 1.0) if sonic else Color(1.0, 0.57, 0.3)
	for i in range(1, _exhaust.size()):
		var fade: float = _exhaust[i - 1].life / 0.24
		trail_color.a = fade * 0.18
		c.draw_line(_exhaust[i - 1].pos, _exhaust[i].pos,
			trail_color, 3.0 * cfg.character_scale)
	if state.phase == RunState.Phase.DYING or state.phase == RunState.Phase.ENDED:
		return
	var size := AIRSHIP.get_size() * cfg.character_scale
	# 上側10px・下側20pxの余白を除いた機体本体の中心へ合わせる。
	var rect := Rect2(Vector2(-AIRSHIP.get_width() / 2.0, -30.0) * cfg.character_scale, size)
	var frame := int(_jet_time * 12.0) % 3
	var region := Rect2(frame * AIRSHIP.get_width(), 0, AIRSHIP.get_width(), AIRSHIP.get_height())
	c.draw_set_transform(state.ship_pos, state.ship_heading.angle() + PI / 2.0)
	var flame := AIRSHIP_BLUE_FLAME if sonic else AIRSHIP_FLAME
	c.draw_texture_rect_region(flame, rect, region)
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
		if state.phase != RunState.Phase.PAUSED and state.phase != RunState.Phase.LEVELUP:
			p.x += randf_range(-1.0, 1.0) * _px(cfg.ship_hurt_shake)
	if state.ship_invuln > 0.0 and fmod(state.time * 20.0, 2.0) < 1.0:
		col.a = 0.5
	var dir := state.ship_heading
	var size := AIRSHIP.get_size() * cfg.character_scale
	c.draw_set_transform(p, dir.angle() + PI / 2.0)
	var rect := Rect2(Vector2(-AIRSHIP.get_width() / 2.0, -30.0) * cfg.character_scale, size)
	var weapons := run.build.weapon_behaviors
	if weapons.has(&"W01") or weapons.has(&"W02"):
		c.draw_texture_rect(AIRSHIP_CANON, rect, false, col)
	c.draw_texture_rect(AIRSHIP, rect, false, col)
	var attachments: Array[Texture2D] = []
	if weapons.has(&"W03") or weapons.has(&"W05"):
		attachments.append(AIRSHIP_ARMOR)
	if weapons.has(&"W17"):
		attachments.append(AIRSHIP_PROBE)
	if weapons.has(&"W07"):
		attachments.append(AIRSHIP_MINE)
	for attachment in attachments:
		c.draw_texture_rect(attachment, rect, false, col)
	var rear = run.build.weapon_behaviors.get(&"W23")
	if rear != null:
		c.draw_texture_rect(AIRSHIP_TURRET_BASE,
			Rect2(Vector2(-AIRSHIP_TURRET_BASE.get_width() / 2.0, -20.0) * cfg.character_scale,
				AIRSHIP_TURRET_BASE.get_size() * cfg.character_scale), false, col)
	c.draw_set_transform(Vector2.ZERO)
	if rear != null:
		# 元絵の砲身は下向き。キャンバスの中心ではなく取り付け軸で回す。
		var mount: Vector2 = rear.mount_position() + (p - state.ship_pos)
		var aim: Vector2 = rear.aim_direction()
		c.draw_set_transform(mount, aim.angle() - PI / 2.0)
		c.draw_texture_rect(AIRSHIP_TURRET,
			Rect2(-rear.MOUNT_PIXEL * cfg.character_scale, size), false, col)
		c.draw_set_transform(Vector2.ZERO)
	SHIELD_VISUAL.equipped(c, state, R, cfg.character_scale)
	for effect in shield_transfers:
		SHIELD_VISUAL.transfer(c, effect, state.ship_pos)
	# HP バー（機体の真下、仕様書 17）
	var frac := clampf(state.ship_hp / state.stats.max_hp, 0.0, 1.0)
	var w := _px(44.0)
	var top := p + Vector2(-w / 2.0, R + _px(10.0))
	c.draw_rect(Rect2(top - Vector2(_px(1), _px(1)), Vector2(w + _px(2), _px(7))), Color(0, 0, 0, 0.55))
	c.draw_rect(Rect2(top, Vector2(w * frac, _px(5.0))), Color("#ff5a4a") if frac < 0.3 else Color("#5dffa0"))

func _draw_top(c: CanvasItem) -> void:
	if flash > 0.0:
		c.draw_rect(view_rect().grow(400.0), Color(1, 1, 1, flash * 0.5))
