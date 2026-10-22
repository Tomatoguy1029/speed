## 描画の流れ（設計書 10）。ゲームの状態とイベントを読むだけで、状態は書き換えない。
##
## World の下に層（DrawLayer）を作り、層ごとに描く。カメラは RunSimulation が求めた位置とズームに合わせる。
## 敵と天体は透過ピクセルスプライト。見分けのルール（仕様書 17）を保つ。
class_name RunPresentation
extends Node

const XP_COLOR := Color("#b8a0ff")
const COIN_COLOR := Color("#ffd24a")
const XP_OUTLINE := Color("#39265e")
const SHIELD_VISUAL := preload("res://scripts/render/shield_visual.gd")
const PIXEL_LIGHTNING := preload("res://scripts/render/pixel_lightning.gd")
## 重ねた絵の外観の置き場（data/visuals/looks/<外観の名前>.tres）
const LOOKS_DIR := "res://data/visuals/looks"

@export var world_path: NodePath
@export var camera_path: NodePath
@export_group("ボス消滅の仮演出")
## 任意の自動再生 Node2D。World 座標に置き、寿命と素材は差替シーンが持つ。空なら共通の仮破片。
@export var finish_effect_scene: PackedScene
@export var finish_color := Color("#e2b96b")
@export_range(0.0, 1.0) var finish_flash := 0.2
@export_range(0.0, 40.0) var finish_shake := 6.0
@export_range(0, 200) var finish_particles := 80
@export_range(0.1, 3.0) var finish_wave_seconds := 0.8

## RunSession が木に入れる前に入れる
var run: RunSimulation
var state: RunState
var cfg: GameConfig

var _layers: Dictionary = {}
var pipeline: RenderPipeline
## 形ごとのまとめた描画（敵・経験値の結晶）
var _batches: Dictionary = {}
var _armor_batches: Dictionary = {}
## 外観の名前の一覧（並び順が照明のキャンバスの層の番号になる。出ない外観の層は作らない）
var _look_names: PackedStringArray = []
## 種類ごとの外観（なければ null）と、種類ごとの絵を合成した画像
var _looks: Dictionary = {}
var _layered_textures: Dictionary = {}
## 敵の見た目の処理（行動の種類の番号の順）と、出来事の種類から受け取る処理
var _visuals: Array[EnemyVisual] = []
var _visual_codes: Dictionary = {}
var _type_visuals: Dictionary = {}
var _friendly_visuals: Dictionary = {}
var _event_visuals: Dictionary = {}
var _enemy_mat: ShaderMaterial
var _armor_material: ShaderMaterial
var _lit_enemy_marks: DrawLayer
var _directional_lights: Dictionary = {}
var lighting_settings: Resource = preload("res://data/visuals/enemy_lighting.tres")
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
var _bolt_seed := 0
var shield_transfers: Array = []
var _attack_visuals: Dictionary = {}
var shake := 0.0
## 設定の「画面の揺れ」の強さ（0〜1。ポーズ中に変えるとすぐ反映）
var _shake_scale := 1.0
var flash := 0.0
var _stars: PackedVector3Array
var _star_batch: InstanceBatch
var _star_material: ShaderMaterial
var _hostile_batch: InstanceBatch
var _coin_batch: InstanceBatch
var _ship_visual: RefCounted
var _meteor_visual: RefCounted
var _body_visual: RefCounted
var _glide_wake: Node2D
var _equipment_visuals: Dictionary = {}

func _ready() -> void:
	state = run.state
	cfg = run.cfg
	_font = ThemeDB.fallback_font
	_ship_visual = load("res://scripts/render/ship_visual.gd").new()
	_ship_visual.setup(self)
	_body_visual = load("res://scripts/render/body_visual.gd").new()
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
	_build_directional_lights(world)
	pipeline = RenderPipeline.new()
	add_child(pipeline)
	pipeline.setup(world as Node2D, _camera, [_layers.projectiles, _layers.fx, _layers.path, _layers.exhaust], _look_names.size() + 2)
	_layers.exhaust.modulate = Color(1.15, 1.15, 1.15)
	_glide_wake = load("res://scenes/fx/glide_wake.tscn").instantiate()
	_layers.exhaust.add_child(_glide_wake)
	run.loadout.equipment_changed.connect(_sync_equipment_visuals)
	_sync_equipment_visuals()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 400:
		_stars.append(Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(0.2, 1.0)))
	_build_star_batch()
	run.frame_events.connect(_on_events)

## 法線付き装甲の敵の飾りを、照明の層の上の専用キャンバスに置く。照明の層は、その外観の敵が初めて出たときに作る。
func _build_directional_lights(world: Node2D) -> void:
	for file in DirAccess.get_files_at(LOOKS_DIR):
		var name := file.trim_suffix(".remap")
		if name.ends_with(".tres"):
			_look_names.append(name.get_basename())
	_look_names.sort()
	var marks := CanvasLayer.new()
	marks.name = "EnemyMarks"
	marks.layer = 1 + _look_names.size()
	marks.follow_viewport_enabled = true
	world.add_child(marks)
	_lit_enemy_marks = DrawLayer.new()
	_lit_enemy_marks.draw_fn = _draw_lit_enemy_marks
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_lit_enemy_marks.material = unshaded
	marks.add_child(_lit_enemy_marks)
	var hud := world.get_parent().get_node_or_null("Hud") as CanvasLayer
	if hud != null:
		hud.layer = maxi(hud.layer, marks.layer + 4)

## 外観の種類 type の照明を、外観の名前の順の層に置く。DirectionalLight2D は light_mask を無視するため、種類ごとにキャンバスを分ける。
func _build_lighting(type: StringName, look: EnemyLook) -> void:
	var lighting := CanvasLayer.new()
	lighting.name = String(type) + "Lighting"
	lighting.layer = 1 + maxi(0, _look_names.find(look.resource_path.get_file().get_basename()))
	lighting.follow_viewport_enabled = true
	get_node(world_path).add_child(lighting)
	_batches[type].reparent(lighting)
	_armor_batches[type].reparent(lighting)
	var lights: Array[DirectionalLight2D] = []
	for light_name in ["UpperLeftLight", "LowerRightLight"]:
		var light := DirectionalLight2D.new()
		light.name = light_name
		light.range_layer_min = lighting.layer
		light.range_layer_max = lighting.layer
		lighting.add_child(light)
		lights.append(light)
	_directional_lights[type] = lights
	_apply_lighting()

## 種類ごとのスプライトと経験値の結晶を MultiMesh でまとめる。
## 照明の値を敵データに合わせる。照明を作ったときと、実験場で外観を編集したときに呼ぶ。
func _apply_lighting() -> void:
	for type in _armor_batches:
		var def := run.enemies.def_of(type)
		var lights: Array = _directional_lights[type]
		for i in 2:
			var prefix := "key_" if i == 0 else "fill_"
			lights[i].energy = def.visual_value(prefix + "energy", lighting_settings.get(prefix + "energy"))
			lights[i].rotation_degrees = def.visual_value(prefix + "angle", lighting_settings.get(prefix + "angle"))
			lights[i].height = def.visual_value("height", lighting_settings.height)
		var armor := _armor_batches[type].material as ShaderMaterial
		armor.set_shader_parameter("ambient", def.visual_value("ambient", lighting_settings.ambient))
		armor.set_shader_parameter("normal_strength", def.visual_value("normal_strength", lighting_settings.normal_strength))

## 隕石・経験値の結晶・部品・敵の弾を MultiMesh でまとめる。敵の種類ごとのまとめは、その種類が初めて出たときに作る。
func _build_batches() -> void:
	_enemy_mat = ShaderMaterial.new()
	_enemy_mat.shader = load("res://shaders/pixel_sprite.gdshader")
	_armor_material = ShaderMaterial.new()
	_armor_material.shader = preload("res://shaders/pixel_armor.gdshader")
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

## 敵の種類 type のまとめた描画。外観があれば重ねた絵と照明、なければ assets/pixel/<type ID>.png の絵、
## それもなければ敵の定義の形（EnemyDef.shape）の図形で描く。png を置けば絵に替わる。
func _ensure_enemy_batch(type: StringName) -> InstanceBatch:
	if _batches.has(type):
		return _batches[type]
	var b := InstanceBatch.new()
	var look := look_of(type)
	var path := _enemy_sprite_path(type)
	if look != null:
		b.setup_texture(look.base)
		b.material = _enemy_mat.duplicate()
	elif ResourceLoader.exists(path):
		b.setup_texture(load(path) as Texture2D)
		b.material = _enemy_mat
	else:
		var def := run.enemies.def_of(type)
		b.setup_polygon(_placeholder_points(def.shape if def != null else &""))
		_shape_ids[type] = true
	b.z_index = -1
	_layers.enemies.add_child(b)
	_batches[type] = b
	if look != null:
		var armor := CanvasTexture.new()
		armor.diffuse_texture = look.armor
		armor.normal_texture = look.normal
		var batch := InstanceBatch.new()
		batch.name = String(type) + "Armor"
		batch.setup_texture(armor)
		batch.material = _armor_material.duplicate()
		batch.z_index = -1
		_layers.enemies.add_child(batch)
		_armor_batches[type] = batch
		_build_lighting(type, look)
	return b

## その戦いに出た行動の種類の見た目の処理を作る。ファイルがなければ共通の飾りだけを描く。
func _sync_visuals() -> void:
	for behavior in run.enemies.behaviors:
		_visual_for_code(behavior.name, behavior.name)

func _visual_for_code(code: StringName, behavior_name: StringName) -> EnemyVisual:
	if not _visual_codes.has(code):
		var path := "res://scripts/render/enemies/%s.gd" % code
		var visual: EnemyVisual = load(path).new() if ResourceLoader.exists(path) else EnemyVisual.new()
		visual.setup(self, behavior_name)
		_visual_codes[code] = visual
		_visuals.append(visual)
		for event in visual.events:
			if not _event_visuals.has(event):
				_event_visuals[event] = []
			_event_visuals[event].append(visual)
	return _visual_codes[code]

func _visual_for_type(type: StringName) -> EnemyVisual:
	if not _type_visuals.has(type):
		var def := run.enemies.def_of(type)
		if def == null:
			return null
		var path := "res://scripts/render/enemies/%s.gd" % type
		var code := type if ResourceLoader.exists(path) else def.behavior
		_type_visuals[type] = _visual_for_code(code, def.behavior)
	return _type_visuals[type]

func _visual_of(table: EnemyTable, row: int) -> EnemyVisual:
	return _visual_for_type(table.type[row]) if table.def[row] != null else null

func _read_settings() -> void:
	_shake_scale = float(SaveManager.settings.screen_shake)

func _process(delta: float) -> void:
	if run != null and run.loadout != null:
		for scope: ContentResourceScope in run.loadout.resource_scopes(): warm_resources(self, scope)
	var phase := state.phase
	var frozen := phase == RunState.Phase.PAUSED or phase == RunState.Phase.LEVELUP \
		or (phase == RunState.Phase.DYING and run.sequence_t < cfg.death_freeze_time)
	var dt := 0.0 if frozen else delta
	# 停止中は減衰も止まるため、残った画面揺れを持ち越さない。
	if phase == RunState.Phase.PAUSED or phase == RunState.Phase.LEVELUP:
		shake = 0.0
	_update_fx(dt)
	_ship_visual.update(dt)
	_glide_wake.step(dt, state, cfg, _blue_exhaust())
	for key in _equipment_visuals.keys():
		var visual: WeaponVisual = _equipment_visuals[key]
		visual.tick(dt)
		if visual.finished():
			visual.dispose()
			_equipment_visuals.erase(key)
	_update_view()
	var offset := Vector2.ZERO
	if not frozen and shake > 0.0 and phase != RunState.Phase.DYING and view_override == null:
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * _shake_scale / maxf(cam_zoom, 0.01)
	_camera.position = cam_center + offset
	_camera.zoom = Vector2(cam_zoom, cam_zoom)
	pipeline.step(dt, _camera.position, cam_zoom)
	for layer in _layers.values():
		layer.queue_redraw()
	_lit_enemy_marks.queue_redraw()
	var brightness := 1.0 - cfg.death_world_dim if phase == RunState.Phase.DYING else 1.0
	for type in _armor_batches:
		(_batches[type].material as ShaderMaterial).set_shader_parameter("brightness", brightness)
		(_armor_batches[type].material as ShaderMaterial).set_shader_parameter("brightness", brightness)
	_lit_enemy_marks.self_modulate = Color(brightness, brightness, brightness)
	_path_band_group.visible = state.drawing or state.tracing
	_path_band_group.self_modulate = Color(1, 1, 1, 0.25 if state.drawing else 0.18)
	_path_band.queue_redraw()

# ── イベント → 演出 ───────────────────────────────────────────────

func _on_events(events: Array[Dictionary]) -> void:
	_sync_visuals()
	for ev in events:
		for v in _event_visuals.get(ev.type, []):
			v.on_event(ev)
		for visual in _equipment_visuals.values():
			visual.on_event(ev)
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
				var killed_visual := _visual_for_type(StringName(ev.get("enemy_type", &"")))
				if killed_visual != null:
					killed_visual.on_kill(ev)
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
			&"gem_burst":
				_ring(ev.pos, float(ev.r) * 2.4, Color("#ffe27a"), 0.3)
				_burst(ev.pos, Color("#ffd23f"), 14, Vector2.ZERO, 360.0)
			&"aquarius_aim":
				flood().aim(ev)
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
				_ship_visual.clear()
				ghosts.append({"from": ev.from, "to": ev.to, "life": 0.18, "max": 0.18})
			&"beam":
				var life: float = ev.get("life", 0.4)
				beams.append({"from": ev.from, "to": ev.to, "width": ev.width, "life": life, "max": life,
					"color": ev.get("color", Color(1.0, 0.95, 0.6))})
			&"bolt":
				_bolt_seed += 1
				bolts.append({"segments": ev.segments, "life": 0.22, "max": 0.22, "seed": _bolt_seed})
				if bolts.size() > 80:
					bolts.pop_front()
			&"debris_trail":
				trails.append({"points": ev.points, "color": ev.color, "life": cfg.corpse_trail_life, "max": cfg.corpse_trail_life})
			&"sonic":
				shake = maxf(shake, 10.0)
				pipeline.add_wave(ev.pos, ev.radius, 0.5)
			&"boss_spawn":
				shake = maxf(shake, 8.0)
			&"boss_explode":
				flash = finish_flash
				shake = finish_shake
				if finish_effect_scene != null:
					var effect := finish_effect_scene.instantiate() as Node2D
					effect.position = ev.pos
					get_node(world_path).add_child(effect)
				else:
					_burst(ev.pos, finish_color, finish_particles, Vector2.ZERO, 700.0)
				pipeline.add_wave(ev.pos, 1600.0, finish_wave_seconds)
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
	_meteors().shatter(ev)

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
	for v in _visuals:
		v.update(dt)
	for list in [rings, texts, ghosts, impacts, trails, beams, bolts, shield_transfers]:
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
	for visual in _attack_visuals.values():
		visual.update(dt)

## みずがめ座の照射の演出を進める。照射の瞬間に揺れと衝撃波、照射中は細かい揺れ。
## 予告中に本体が倒れたら演出をやめ、照射中に倒れたらその場で崩れ始める。
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
	if f.battle_arenas.is_empty():
		c.draw_arc(Vector2.ZERO, cfg.field_radius, 0, TAU, 256, Color(1.0, 0.4, 0.4, 0.35), _px(2.0))
	_draw_hero(c)
	# ヘルクレス座の火の隕石：落ちてくる影と、燃える跡
	for fall in run.heroes.behavior(&"hercules").falls:
		var k := clampf(1.0 - fall.z / 0.6, 0.0, 1.0)
		var at := Vector2(fall.x, fall.y)
		c.draw_circle(at, 30.0 + 60.0 * k, Color(1.0, 0.4, 0.1, 0.12 + 0.25 * k))
		c.draw_circle(at - Vector2(-0.6, 1.0) * 500.0 * (1.0 - k), 22.0, Color("#ffb060"))
	for b in run.heroes.behavior(&"hercules").burns:
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
			_body_visual.draw(c, b)

## 英雄の星座：全体から淡金色の光がにじみ、つないだ星と光線がさらに強く輝く。
func _draw_hero(c: CanvasItem) -> void:
	var h := run.heroes
	if h.hero == null or h.stars.is_empty():
		return
	var view := view_rect().grow(900.0)
	if not view.has_point(h.center):
		return
	var gold := Color("#ffe8a0")
	var brass := Color("#e2b96b")
	var hot := Color(gold.r * 1.7, gold.g * 1.7, gold.b * 1.7)
	var links := h.hero.links
	var connected := PackedByteArray()
	connected.resize(h.stars.size())
	var bounds := Rect2(h.stars[0], Vector2.ZERO)
	for star in h.stars:
		bounds = bounds.expand(star)
	# 星間の空間まで包む光の雲。線に沿った細い縁取りにせず、星座全体を一つの光源として見せる。
	var center := bounds.get_center()
	var radii := bounds.size * 0.65 + Vector2.ONE * _px(72.0)
	var aura_pixel := _px(8.0)
	var columns := ceili(radii.x * 2.0 / aura_pixel)
	var rows := ceili(radii.y * 2.0 / aura_pixel)
	var breath := 0.95 + 0.05 * sin(state.world_time * 0.8)
	for row in rows:
		for column in columns:
			var at := center - radii + Vector2(column, row) * aura_pixel
			var q := (at - center) / radii
			var cloud := 0.78 + 0.22 * sin(q.x * 4.0 + q.y * 2.0) * cos(q.y * 5.0 - q.x)
			var density := exp(-q.length_squared() * 2.8) * cloud
			var alpha := floorf(density * 12.0) / 12.0 * 0.25 * breath
			if alpha > 0.0:
				c.draw_rect(Rect2(at.snapped(Vector2.ONE * aura_pixel), Vector2.ONE * aura_pixel),
					Color(gold, alpha))
	# 基本線は操作線と共通。光の広がりと芯を同じ経路に重ねて光線として見せる。
	for n in h.lit.size():
		var a := h.stars[links[n * 2]]
		var b := h.stars[links[n * 2 + 1]]
		var points := PackedVector2Array([a, b])
		var lit: bool = h.lit[n] != 0
		if lit:
			connected[links[n * 2]] = 1
			connected[links[n * 2 + 1]] = 1
		if lit:
			_draw_route_line(c, points, Color(brass, 0.055), 22.0)
			_draw_route_line(c, points, Color(gold, 0.13), 12.0)
			_draw_route_line(c, points, Color(gold, 0.32), 6.0)
			_draw_route_line(c, points, Color(gold, 0.95), 4.0)
			_draw_route_line(c, points, Color(hot, 0.95), 2.0)
		else:
			# 光が戻る前の経路には、弱い金色の光だけを点線で残す。
			_draw_route_line(c, points, Color(gold, 0.35), 2.0, true)
	var pixel := _px(2.0)
	var grid := Vector2.ONE * pixel
	var glow_pixel := _px(4.0)
	for index in h.stars.size():
		var p := h.stars[index].snapped(grid)
		var lit: bool = connected[index] != 0
		# 同じ星光の強さと広がりを変え、残り火のような星が接続すると輝きを取り戻す。
		var strength := 1.3 if lit else 0.6
		var light_strength := 1.0 if lit else 0.32
		for layer in 4:
			var radius := _px([34.0, 25.0, 17.0, 10.0][layer]) * strength
			var alpha: float = [0.035, 0.06, 0.12, 0.24][layer] * light_strength
			var count := ceili(radius / glow_pixel)
			for y in range(-count, count + 1):
				var dy := y * glow_pixel
				var half_width := floorf(sqrt(maxf(0.0, radius * radius - dy * dy)) / glow_pixel) * glow_pixel
				if half_width > 0.0:
					c.draw_rect(Rect2(p + Vector2(-half_width, dy - glow_pixel * 0.5),
						Vector2(half_width * 2.0, glow_pixel)), Color(gold, alpha))
		var arm := _px(26.0 if lit else 9.0)
		c.draw_rect(Rect2(p - Vector2(arm, pixel), Vector2(arm * 2.0, pixel * 2.0)), Color(gold, 0.45 * light_strength))
		c.draw_rect(Rect2(p - Vector2(pixel * 0.5, arm * 1.15), Vector2(pixel, arm * 2.3)), Color(gold, 0.85 * light_strength))
		var light_rows := [1, 3, 5, 7, 9, 7, 5, 3, 1] if lit else [1, 3, 5, 7, 5, 3, 1]
		for row in light_rows.size():
			var width: int = light_rows[row]
			c.draw_rect(Rect2(p + Vector2(-width * 0.5, row - light_rows.size() * 0.5) * pixel,
				Vector2(width, 1) * pixel), Color(gold, 1.0 if lit else 0.4))
		var core := grid * (3.0 if lit else 2.0)
		c.draw_rect(Rect2(p - core * 0.5, core), hot if lit else Color(gold, 0.55))

func _draw_pickups(c: CanvasItem) -> void:
	var p := run.pickups
	var view := view_rect().grow(60.0)
	# 経験値の結晶：画面上で最低 8px の高さ（仕様書 17）
	var gs := maxf(5.0, _px(4.0))
	var gems: InstanceBatch = _batches[&"gem"]
	gems.begin()
	var gem_alive := p.gem_alive
	var gem_pos := p.gem_pos
	var gem_value := p.gem_value
	for i in gem_alive.size():
		var pos := gem_pos[i]
		if gem_alive[i] != 0 and view.has_point(pos):
			# 経験値の多い結晶ほど大きい（経験値1で等倍、最大3倍）
			var v := gem_value[i]
			gems.add_upright(pos, gs * (1.0 if v <= 1.0 else minf(pow(v, 0.2), 3.0)), XP_COLOR)
	gems.end()
	var cs := maxf(6.0, _px(3.5))
	_coin_batch.begin()
	var coin_alive := p.coin_alive
	var coin_pos := p.coin_pos
	for i in coin_alive.size():
		var pos := coin_pos[i]
		if coin_alive[i] != 0 and view.has_point(pos):
			_coin_batch.add_upright(pos, cs, COIN_COLOR)
	_coin_batch.end()
	for cap: Pickup in p.capsules:
		match cap.kind:
			Pickup.Kind.HEAL:
				c.draw_rect(Rect2(cap.pos - Vector2(14, 11), Vector2(28, 22)), Color.WHITE)
				c.draw_rect(Rect2(cap.pos - Vector2(3, 8), Vector2(6, 16)), Color("#e8434f"))
				c.draw_rect(Rect2(cap.pos - Vector2(8, 3), Vector2(16, 6)), Color("#e8434f"))
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

func _draw_enemies(c: CanvasItem) -> void:
	_sync_visuals()
	var view := view_rect().grow(run.combat.enemy_query_padding)
	for batch: InstanceBatch in _armor_batches.values():
		batch.begin()
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
		var type := t.type[i]
		var visual := _visual_of(t, i)
		var sprite_radius := visual.sprite_radius(t, i) if visual != null else enemy_sprite_radius(type, t.r[i])
		if not view.grow(maxf(0.0, sprite_radius * sqrt(2.0) - run.combat.enemy_query_padding)).has_point(p):
			continue
		# 色のr成分はスプライトシェーダーの被弾フラッシュ。
		var col := Color(1.0 if t.flash[i] > 0.0 else 0.0, 0.0, 0.0, 1.0)
		if visual != null and visual.draw_body(c, t, i, p):
			continue
		if t.is_boss[i] != 0:
			var boss_actor := run.bosses.actor_for_row(i)
			if boss_actor != null and boss_actor.draws_self:
				continue
		var batch := _ensure_enemy_batch(type)
		if _shape_ids.has(type):
			batch.add(p, t.facing[i], t.r[i], Color.WHITE if t.flash[i] > 0.0 else t.color[i])
		else:
			batch.add(p, _enemy_sprite_angle(type, t.facing[i]), sprite_radius, col)
		if _armor_batches.has(type):
			_armor_batches[type].add(p, _enemy_sprite_angle(type, t.facing[i]), sprite_radius, col)
			continue
		# 飾りのある敵だけ、飾りを描く
		var v := _visual_of(t, i)
		if elite[i] != 0 or weak[i] > 0.0 or charge[i] > 0.0 or landmark[i] != 0 or stone[i] > 0.0 \
				or (radius[i] >= 25.0 and hp[i] < max_hp[i]) or (v != null and v.always_marked):
			_draw_enemy_marks(c, t, i)
	for key in _batches:
		if key != &"gem":
			_batches[key].end()
	_draw_meteor_shards(c)
	for batch: InstanceBatch in _armor_batches.values():
		batch.end()
	for v in _visuals:
		v.draw_layer(c, view)

func _draw_lit_enemy_marks(c: CanvasItem) -> void:
	var t := run.enemies.table
	var view := view_rect().grow(run.combat.enemy_query_padding)
	for i in t.alive.size():
		if t.alive[i] != 0 and t.dead[i] == 0 and _armor_batches.has(t.type[i]) and view.has_point(t.pos[i]):
			_draw_enemy_marks(c, t, i)

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

## 敵の種類 type の外観（ステージの敵の見た目で差し替える。重ねた絵を持たない種類は null）。
func look_of(type: StringName) -> EnemyLook:
	if not _looks.has(type):
		_looks[type] = load_look(type, state.stage)
	return _looks[type]

## 外観を読む。実験場の一覧も同じ規則で使う。
static func load_look(type: StringName, stage: StageDef = null) -> EnemyLook:
	var skin := String(stage.enemy_sprite_path(type).get_file().get_basename()) if stage != null else String(type)
	for name in [skin, String(type)]:
		var path := LOOKS_DIR.path_join(name + ".tres")
		if ResourceLoader.exists(path):
			return load(path) as EnemyLook
	return null

## 本番の船体と実験場の一覧に、同じベース・装甲の合成画像を使う。
static func look_texture(look: EnemyLook, cache: Dictionary) -> Texture2D:
	var key := look.resource_path
	if not cache.has(key):
		var body: Image = look.base.get_image()
		body.blend_rect(look.armor.get_image(), Rect2i(Vector2i.ZERO, body.get_size()), Vector2i.ZERO)
		cache[key] = ImageTexture.create_from_image(body)
	return cache[key]

## 外観の絵は元画像の寸法を、敵データの半径との比で拡大縮小する（半径には実験場の倍率・個体の大きさが反映済み）。
func enemy_sprite_radius(type: StringName, collision_radius: float) -> float:
	var look := look_of(type)
	if look == null or look.size_from_collision:
		return collision_radius
	var def := run.enemies.def_of(type)
	return maxf(look.base.get_width(), look.base.get_height()) * 0.5 * collision_radius / maxf(def.radius if def != null else collision_radius, 0.001)

func _enemy_sprite_angle(type: StringName, facing: float) -> float:
	var look := look_of(type)
	if look != null:
		return look.angle + (0.0 if look.fixed_angle else facing)
	return facing + (PI / 2.0 if type in EnemyDef.NATIVE_SPRITES else -PI / 2.0)

## 敵の種類の絵（牽引した船体を描くのに使う。絵のない種類は null）。
func _enemy_texture(type: StringName) -> Texture2D:
	if not _enemy_textures.has(type):
		var look := look_of(type)
		if look != null:
			_enemy_textures[type] = look_texture(look, _layered_textures)
			return _enemy_textures[type]
		var path := _enemy_sprite_path(type)
		_enemy_textures[type] = load(path) if ResourceLoader.exists(path) else null
	return _enemy_textures[type]

## 敵の種類の絵のファイル（ステージの敵の見た目に従う）。
func _enemy_sprite_path(type: StringName) -> String:
	if state.stage != null:
		return state.stage.enemy_sprite_path(type)
	return "res://assets/pixel/%s.png" % type

## 敵の船体を絵で描く（牽引中・撃ち出した船体）。glow は周りの光の色（透明なら光らせない）。
func _draw_hull(c: CanvasItem, type: StringName, p: Vector2, angle: float, r: float, glow: Color) -> void:
	var tex := _enemy_texture(type)
	if glow.a > 0.0:
		c.draw_circle(p, r * 1.1, Color(glow, 0.25))
	if tex == null:
		c.draw_circle(p, r, Color("#aeb6c4"))
		return
	var size := tex.get_size() / maxf(tex.get_width(), tex.get_height()) * enemy_sprite_radius(type, r) * 2.0
	c.draw_set_transform(p, _enemy_sprite_angle(type, angle))
	c.draw_texture_rect(tex, Rect2(-size / 2.0, size), false)
	c.draw_set_transform(Vector2.ZERO)

## 数の少ない飾り（エリートの輪・背面の弱点・予告・HP バー）は個別に描く。種類ごとの飾りは見た目の処理が描く。
func _draw_enemy_marks(c: CanvasItem, t: EnemyTable, i: int) -> void:
	var p := t.pos[i]
	var r := t.r[i]
	var v := _visual_of(t, i)
	if t.elite[i] != 0:
		c.draw_arc(p, r + _px(3.0), 0, TAU, 32, Color("#ffd24a"), _px(2.0))
	var weak := t.weak_arc[i]
	if weak > 0.0 and t.type[i] not in EnemyDef.NATIVE_SPRITES and (v == null or v.draws_weak_arc):
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
	if v != null:
		v.draw_marks(c, t, i)
	var hp := t.hp[i]
	var max_hp := t.max_hp[i]
	if (r >= 25.0 or t.is_boss[i] != 0) and hp < max_hp:
		var w := r * 1.6
		var top := p + Vector2(-w / 2.0, -r - _px(10.0))
		c.draw_rect(Rect2(top, Vector2(w, _px(4.0))), Color(0, 0, 0, 0.6))
		c.draw_rect(Rect2(top, Vector2(w * maxf(0.0, hp / max_hp), _px(4.0))), Color("#ff6b5a"))

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
		_friendly_visual(pr, i).draw_friend(c, pr, i, pos)
	_hostile_batch.begin()
	for i in pr.hostile_alive.size():
		var pos := pr.hostile_pos[i]
		if pr.hostile_alive[i] != 0 and view.has_point(pos):
			if not _attack_visual(ProjectileSystem.HostileKind.keys()[pr.hostile_kind[i]]).draw_shot(c, pr, i, pos):
				_hostile_batch.add(pos, 0.0, pr.hostile_r[i], Color.WHITE)
			if pr.hostile_stone[i] > 0.0:
				c.draw_circle(pos, pr.hostile_r[i] * 1.3, Color(0.62, 0.6, 0.58, 0.9))
	_hostile_batch.end()
	_draw_hazards(c, view)

## 敵の攻撃の形（仕様書 11.7）。予告は攻撃する敵の側の光や模様で見せ、当たる範囲そのものは予告しない。
func _draw_hazards(c: CanvasItem, view: Rect2) -> void:
	var pr := run.projectiles
	for i in pr.hazard_alive.size():
		if pr.hazard_alive[i] != 0:
			_attack_visual(ProjectileSystem.HazardKind.keys()[pr.hazard_kind[i]]).draw_hazard(c, pr, i, view)

func _draw_path_band(c: CanvasItem) -> void:
	# ふたご座：取っておいた1本目と、双子の機体がなぞる線
	for twin in [state.twin_first, state.twin_path]:
		var tp: PackedVector2Array = twin
		if tp.size() > 1:
			c.draw_polyline(tp, Color(0.75, 0.9, 1.0, 0.5), cfg.trace_radius * 2.0)
	if state.twin_tracing:
		c.draw_circle(state.twin_pos, cfg.ship_radius * 1.3, Color(0.75, 0.92, 1.0, 0.55))
		c.draw_circle(state.twin_pos, cfg.ship_radius * 0.7, Color(1.0, 1.0, 1.0, 0.9))
	var pts := state.draw_points if state.drawing else state.trace_path
	if pts.size() < 2:
		return
	var leo := run.combat.trace_width()
	var color := Color(1.0, 0.85, 0.45) if leo > 1.0 else Color(0.55, 0.9, 1.0)
	var w := cfg.trace_radius * leo
	for i in pts.size() - 1:
		c.draw_line(pts[i], pts[i + 1], color, w * 2.0)
	for point in pts:
		c.draw_circle(point, w, color)

## 操作線と英雄の星間線で共有する実線・点線。太さと点線間隔は画面pxで扱う。
func _draw_route_line(c: CanvasItem, points: PackedVector2Array, color: Color, width_px: float, dashed := false) -> void:
	if points.size() < 2:
		return
	if not dashed:
		c.draw_polyline(points, color, _px(width_px))
		return
	for i in points.size() - 1:
		var gap := points[i + 1] - points[i]
		var steps := int(gap.length() / _px(14.0))
		for k in range(0, steps, 2):
			c.draw_line(points[i] + gap * (float(k) / steps), points[i] + gap * (float(k + 1) / steps), color, _px(width_px))

func _draw_path(c: CanvasItem) -> void:
	if state.drawing and state.draw_points.size() > 0:
		var pts := state.draw_points
		# 今の位置から描き始めまでの移動（なぞりで一緒に駆け抜ける）を点線で示す
		_draw_route_line(c, PackedVector2Array([state.ship_pos, pts[0]]), Color(0.8, 0.97, 1.0, 0.55), 2.0, true)
		if pts.size() > 1:
			_draw_route_line(c, pts, Color(0.8, 0.97, 1.0, 0.95), 3.0)
		c.draw_circle(pts[0], _px(6.0), Color("#c8f7ff"))
	if state.tracing and state.trace_path.size() > 1:
		_draw_route_line(c, state.trace_path, Color(0.8, 0.97, 1.0, 0.6), 2.0)
	for g in ghosts:
		var a: float = g.life / g.max
		c.draw_line(g.from, g.to, Color(0.75, 0.95, 1.0, 0.6 * a), _px(4.0))

## 武器・特性が残すもの（機雷・ドローン・渦）。
func _draw_build_objects(c: CanvasItem) -> void:
	for visual in _equipment_visuals.values():
		if visual.active:
			visual.draw_objects(c)

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
		var age: float = bo.max - bo.life
		var alpha := PIXEL_LIGHTNING.intensity(age, bo.max)
		var shape := int(age / PIXEL_LIGHTNING.SHAPE_INTERVAL)
		var segments: PackedVector2Array = bo.segments
		for i in range(0, segments.size(), 2):
			PIXEL_LIGHTNING.draw(c, segments[i], segments[i + 1], _px(2.0), int(bo.seed) * 7919 + i * 313 + shape * 101, alpha)
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

func _draw_exhaust(c: CanvasItem) -> void:
	_ship_visual.draw_exhaust(c)

func _draw_ship(c: CanvasItem) -> void:
	_ship_visual.draw_ship(c)

func _draw_top(c: CanvasItem) -> void:
	if flash > 0.0:
		c.draw_rect(view_rect().grow(400.0), Color(1, 1, 1, flash * 0.5))

## 種類の表示は、その種類を初めて使ったときに作る。
func _attack_visual(kind: String) -> AttackVisual:
	var key := kind.to_lower()
	if not _attack_visuals.has(key):
		var visual: AttackVisual = load("res://scripts/render/attacks/%s.gd" % key).new()
		visual.setup(self)
		_attack_visuals[key] = visual
	return _attack_visuals[key]

func flood() -> AttackVisual:
	return _attack_visual("flood")

func _sync_equipment_visuals() -> void:
	var current := {}
	for behavior in run.loadout.weapon_behaviors.values() + run.loadout.trait_behaviors.values():
		var key: int = behavior.get_instance_id()
		current[key] = true
		if _equipment_visuals.has(key):
			continue
		var path := "res://scripts/render/equipment/%s.gd" % behavior.def.code_id
		if ResourceLoader.exists(path):
			var visual: WeaponVisual = load(path).new()
			visual.setup(self, behavior)
			_equipment_visuals[key] = visual
	for key in _equipment_visuals:
		_equipment_visuals[key].active = current.has(key)

func _blue_exhaust() -> bool:
	for visual in _equipment_visuals.values():
		if visual.active and visual.blue_exhaust:
			return true
	return false

func _draw_equipment_parts(c: CanvasItem, rect: Rect2, color: Color, under: bool) -> void:
	var drawn := {}
	var visuals := _equipment_visuals.values()
	visuals.sort_custom(func(a, b): return a.overlay_order < b.overlay_order)
	for visual in visuals:
		var texture: Texture2D = visual.underlay if under else visual.overlay
		if visual.active and texture != null and not drawn.has(texture):
			c.draw_texture_rect(texture, rect, false, color)
			drawn[texture] = true

func _meteors() -> RefCounted:
	if _meteor_visual == null:
		_meteor_visual = load("res://scripts/render/meteor_visual.gd").new()
		_meteor_visual.setup(self)
	return _meteor_visual

func _friendly_visual(projectiles: ProjectileSystem, row: int) -> AttackVisual:
	var code := String(projectiles.friend_type[row])
	if code.is_empty() or not ResourceLoader.exists("res://scripts/render/friendly/%s.gd" % code):
		code = String(ProjectileSystem.FriendKind.keys()[projectiles.friend_kind[row]]).to_lower()
	if not _friendly_visuals.has(code):
		var visual: AttackVisual = load("res://scripts/render/friendly/%s.gd" % code).new()
		visual.setup(self)
		_friendly_visuals[code] = visual
	return _friendly_visuals[code]

## 表示を組み立てる前のロード画面と、装備候補の表示中で共有する入口。
static func warm_resources(parent: Node, scope: ContentResourceScope) -> void:
	if scope == null or scope.cancelled or not scope.is_ready() or scope.warming or scope.warmup_complete: return
	var viewport: Node = load("res://scripts/render/shader_warmup.gd").new()
	parent.add_child(viewport)
	viewport.prepare(scope)
