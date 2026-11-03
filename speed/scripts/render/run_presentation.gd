## C++の出力と資源一覧だけを読み、画面・音・HUDへ渡す。
class_name RunPresentation
extends Node
const PickupKind := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS.PickupKind

const MAGNET_COLOR := Color("#b8a0ff")
const COIN_COLOR := Color("#ffd24a")
const CRYSTAL_COLORS := [Color("#08deff"),Color("#945cff"),Color("#ffb609")]

@export var world_path: NodePath
@export var camera_path: NodePath
@export_group("ボス消滅の仮演出")
@export var finish_effect_scene: PackedScene
@export var finish_color := Color("#e2b96b")
@export_range(0.0,1.0) var finish_flash := 0.2
@export_range(0.0,40.0) var finish_shake := 6.0
@export_range(0,200) var finish_particles := 80
@export_range(0.1,3.0) var finish_wave_seconds := 0.8

var bridge: RefCounted
var cpp_resources: Resource
var cpp_scope: ContentResourceScope
var frame_view: Node2D
var cpp_background: Node2D
var pipeline: RenderPipeline
var _camera: Camera2D
var cam_center := Vector2.ZERO
var cam_zoom := 1.0
var view_override: Variant = null
var shake := 0.0

func _ready() -> void:
	if bridge!=null:_ready_cpp()

func _process(delta: float) -> void:
	if bridge!=null:_present_cpp(delta)


static func draw_warp(c: CanvasItem, position: Vector2, radius: float, now: float, pixel: float) -> void:
	c.draw_circle(position,radius,Color(0.6,0.3,1.0,0.25))
	for n in 3:
		var start := now*(2.0+n)+n*2.1
		c.draw_arc(position,radius*(0.5+0.2*n),start,start+PI*1.4,24,Color(0.85,0.7,1.0,0.8),pixel*3.0)

## 値型フレームの重力を描く。

static func draw_gravity(c: CanvasItem, position: Vector2, born: float, life: float, radius: float, now: float, pixel: float) -> void:
	var reach := radius*(1.0-(now-born)/life)
	c.draw_circle(position,reach,Color(0.35,0.2,0.6,0.12))
	for n in 3:
		var r := reach*fposmod(1.0-now*0.6-n/3.0,1.0)
		c.draw_arc(position,maxf(r,1.0),0,TAU,40,Color(0.7,0.55,1.0,0.35),pixel*2.0)
	c.draw_circle(position,maxf(6.0,reach*0.08),Color(0.08,0.02,0.15,0.9))


static func draw_capsule_values(c: CanvasItem, at: Vector2, kind: int, now: float) -> void:
	match kind:
		PickupKind.Heal:
			c.draw_rect(Rect2(at-Vector2(14,11),Vector2(28,22)),Color.WHITE)
			c.draw_rect(Rect2(at-Vector2(3,8),Vector2(6,16)),Color("#e8434f"))
			c.draw_rect(Rect2(at-Vector2(8,3),Vector2(16,6)),Color("#e8434f"))
		PickupKind.CometWeapon:
			var pulse := 0.5+0.5*sin(now*5.0)
			c.draw_circle(at,30.0+pulse*6.0,Color(1.0,0.75,0.25,0.25))
			c.draw_colored_polygon(PackedVector2Array([at+Vector2(0,-22),at+Vector2(18,0),at+Vector2(0,22),at+Vector2(-18,0)]),Color("#efcb70"))
			c.draw_circle(at,7.0,Color("#fff1bf"))
		PickupKind.Magnet:
			c.draw_arc(at,14.0,PI,TAU,16,MAGNET_COLOR,6.0)
			c.draw_rect(Rect2(at+Vector2(-17,0),Vector2(6,10)),Color.WHITE)
			c.draw_rect(Rect2(at+Vector2(11,0),Vector2(6,10)),Color.WHITE)

static func draw_comet_values(c: CanvasItem, p: Vector2, r: float, vel: Vector2, rare: bool, now: float) -> void:
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
			var a := now * 3.0 + k * TAU / 4.0
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

static func load_look(type: StringName, stage: StageDef = null, scope: ContentResourceScope = null) -> EnemyLook:
	var skin := String(stage.enemy_sprite_path(type).get_file().get_basename()) if stage != null else String(type)
	var index: StageResources = stage.resources if stage is RuntimeStage else ContentManager.visual_index
	for name in [skin, String(type)]:
		if index.look_paths.has(name):
			var path: String = index.look_paths[name]
			if scope == null: return load(path) as EnemyLook
			assert(scope.resources.has(path), "外観の準備が必要: " + path)
			return scope.resources.get(path) as EnemyLook
	return null

## 本番の船体と実験場の一覧に、同じベース・装甲の合成画像を使う。

static func look_texture(look: EnemyLook, cache: Dictionary, palettes: Dictionary = {}, live: Callable = Callable()) -> Texture2D:
	var key := look.source_path + ":" + look.preview_key(palettes)
	if not cache.has(key):
		if cache.size() >= 64:
			cache.erase(cache.keys()[0])
		if not look.previews.has(look.preview_key(palettes)) and live.is_valid(): look = live.call(look, palettes)
		assert(look.prepared and look.previews.has(look.preview_key(palettes)), "生成済みの合成画像が必要: " + look.source_path)
		cache[key] = look.previews[look.preview_key(palettes)]
	return cache[key]

## 外観の絵は元画像の寸法を、敵データの半径との比で拡大縮小する（半径には実験場の倍率・個体の大きさが反映済み）。

static func warm_resources(parent: Node, scope: ContentResourceScope) -> void:
	if scope == null or scope.cancelled or not scope.is_ready() or scope.warming or scope.warmup_complete: return
	var viewport: Node = load("res://scripts/render/shader_warmup.gd").new()
	parent.add_child(viewport)
	viewport.prepare(scope)

func _ready_cpp() -> void:
	_camera = get_node(camera_path) as Camera2D
	var snapshot: Dictionary = bridge.latest_frame()
	if not snapshot.ok: return
	frame_view = load("res://scripts/render/run_frame_view.gd").new()
	get_node(world_path).add_child(frame_view)
	frame_view.setup(cpp_scope,cpp_resources.visuals,float(snapshot.value.ui.character_scale))
	frame_view.finish_settings = {"flash":finish_flash,"shake":finish_shake,"effect":finish_effect_scene,"color":finish_color,"particles":finish_particles,"wave_seconds":finish_wave_seconds}
	cpp_background = preload("res://scripts/render/run_stage_background.gd").new()
	cpp_background.z_index = -10
	frame_view.add_child(cpp_background)
	cpp_background.setup(cpp_scope,cpp_resources,snapshot.value.ui.ship.ship_pos)
	bridge.subscribe("presentation",frame_view.receive_frame,["world_time","boss_bodies"])
	pipeline = RenderPipeline.new()
	add_child(pipeline)
	var layer_count: int = cpp_resources.visuals.size()-3
	pipeline.setup(get_node(world_path),_camera,[frame_view._layer(10),frame_view._layer(14)],layer_count)
	frame_view.pipeline = pipeline
	var hud := get_node(world_path).get_parent().get_node_or_null("Hud") as CanvasLayer
	if hud!=null: hud.layer = maxi(hud.layer,layer_count+3)

func _present_cpp(delta: float) -> void:
	if frame_view==null: return
	var snapshot: Dictionary = bridge.latest_frame()
	if not snapshot.ok:
		frame_view.hide()
		return
	var frame: Dictionary = snapshot.value
	var view: Dictionary = view_override if view_override is Dictionary else {}
	cam_center = view.get("center",frame.camera.center)
	cam_zoom = float(view.get("zoom",frame.camera.zoom))
	_camera.position = cam_center
	_camera.zoom = Vector2.ONE*cam_zoom
	var half := get_viewport().get_visible_rect().size/(2.0*cam_zoom)
	var began := Time.get_ticks_usec()
	var render: Dictionary = bridge.read_render(Rect2(cam_center-half,half*2.0),1.0)
	frame_view.build_us = Time.get_ticks_usec()-began
	frame_view.boss_hit_feedback.tick(0.0 if frame_view.authoring_paused or frame.ui.get("presentation_frozen",false) else delta)
	if not render.ok or not frame_view.apply_frame(render.value):
		frame_view.hide()
		return
	frame_view.show()
	var effects_start := Time.get_ticks_usec() if frame_view.perf.active else 0
	cpp_background.update_frame(frame.camera)
	frame_view.update_effects(frame,delta)
	shake=maxf(shake,frame_view.ruler_shake)
	frame_view.ruler_shake=0.0
	if frame_view.finish_shake>0.0:
		shake = maxf(shake,frame_view.finish_shake)
		frame_view.finish_shake = 0.0
	if frame_view._end_blast_visual!=null:
		shake = maxf(shake,frame_view._end_blast_visual.frame_shake)
		frame_view._end_blast_visual.frame_shake = 0.0
	if frame_view._vortex_visual!=null:
		shake = maxf(shake,frame_view._vortex_visual.frame_shake)
		frame_view._vortex_visual.frame_shake = 0.0
	if frame_view._knockback_visual!=null:
		shake = maxf(shake,frame_view._knockback_visual.frame_shake)
		frame_view._knockback_visual.frame_shake = 0.0
	if not frame.ui.get("presentation_frozen",false):
		shake = maxf(0.0,shake-delta*40.0)
		_camera.offset = Vector2.ZERO if not view.is_empty() and not view.get("shake",false) else Vector2(randf_range(-1,1),randf_range(-1,1))*shake*float(SaveManager.settings.screen_shake)/maxf(cam_zoom,0.01)
	else: _camera.offset = Vector2.ZERO
	frame_view.perf.since(&"view_effects",effects_start)
	var tail_start := Time.get_ticks_usec() if frame_view.perf.active else 0
	var hud := get_node(world_path).get_parent().get_node_or_null("Hud/HudRoot")
	if hud!=null: hud.apply_snapshot(frame.ui)
	pipeline.step(0.0 if frame.ui.get("presentation_frozen",not frame.ui.input_enabled) else delta,cam_center,cam_zoom)
	frame_view.perf.since(&"view_tail",tail_start)

## 表示側も読む人ごとの窓で差分を取り、共有の累積値を消さない。

func metrics_snapshot() -> Dictionary:
	if bridge==null: return {}
	var result: Dictionary = bridge.read_metrics()
	if not result.ok: return {}
	var metrics: Dictionary = result.value
	if frame_view!=null:
		var update := [0,0,0]
		var draw := [0,0,0]
		for key in frame_view.metrics_record:
			var values: Array = frame_view.metrics_record[key]
			var target: Array = draw if String(key).begins_with("view_draw.") else update
			if not String(key).begins_with("view_draw.") and key not in [&"view_submit",&"view_effects",&"view_tail"]: continue
			target[0] += values[0]
			target[1] += values[1]
			target[2] = maxi(target[2],values[2])
		metrics.timings["view_update"] = update
		metrics.timings["view_draw"] = draw
	return metrics
