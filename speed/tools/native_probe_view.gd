## 対応済みの戦闘経路を描画して確認する。通常ステージの性能判定とは分ける。
extends Node2D
var core: RefCounted
var batch: InstanceBatch
var gem_batch: InstanceBatch
var coin_batch: InstanceBatch
var camera: Camera2D
var label: Label
var ship_texture: Texture2D
var visual_scale := 1.0
var character_scale := 1.0
var started_us := 0
var options := {}
var frames := 0
var input_tick := 0
var collected_xp := 0.0
var ship := {}
var drawing := {}
var origin := Vector2.ZERO
var pen_origin := Vector2.ZERO

func _ready() -> void:
	set_physics_process(false)
	for arg in OS.get_cmdline_user_args():
		var pair := arg.trim_prefix("--").split("=", false, 1)
		if pair.size() == 2: options[pair[0]] = pair[1]
	core = load("res://tools/compare_runtime.gd").new().create_native()
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://.content/dev/native_probe.json"))
	if core == null or not data is Dictionary or not data.has("config"):
		push_error("比較用データと拡張を共通生成で準備してください")
		get_tree().quit(1)
		return
	var config: Dictionary = data.config
	var stats := _base_stats()
	if not (core.configure(data) and core.configure_ship(config, stats) and core.configure_draw(config, stats)
		and core.configure_combat(config, stats) and core.configure_pickups(config, stats)
		and core.configure_frame(config) and core.start(932)):
		push_error("比較経路の準備に失敗しました")
		get_tree().quit(1)
		return
	visual_scale = float(data.visual_scale)
	character_scale = float(config.character_scale)
	batch = InstanceBatch.new()
	batch.setup_texture(load("res://assets/pixel/drifter.png"))
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/pixel_sprite.gdshader")
	batch.material = material
	batch.z_index = -1
	add_child(batch)
	gem_batch = InstanceBatch.new()
	gem_batch.setup_polygon(PackedVector2Array([Vector2(0,-1.4),Vector2(1,0),Vector2(0,1.4),Vector2(-1,0)]))
	var gem_material := ShaderMaterial.new()
	gem_material.shader = load("res://shaders/xp_crystal.gdshader")
	gem_batch.material = gem_material
	gem_batch.z_index = -1
	add_child(gem_batch)
	coin_batch = InstanceBatch.new()
	coin_batch.z_index = -1
	coin_batch.setup_polygon(InstanceBatch.circle_points(24))
	add_child(coin_batch)
	ship_texture = load("res://assets/pixel/airship.png")
	camera = Camera2D.new()
	add_child(camera)
	var canvas := CanvasLayer.new()
	label = Label.new()
	canvas.add_child(label)
	add_child(canvas)
	ship = core.ship_snapshot()
	origin = ship.ship_pos
	camera.position = origin
	var count := clampi(int(options.get("count", "1300")), 1, 10000)
	for i in count:
		var pos := origin + Vector2.from_angle(i * 2.399963) * (100.0 + sqrt(float(i)) * 12.0)
		core.spawn_enemy(&"drifter", pos)
	core.rebuild_enemy_grid(float(config.grid_cell))
	started_us = Time.get_ticks_usec()
	set_physics_process(true)

## 比較場面は装備・永続強化なし。能力値の式は既存の計算を一度だけ使い、状態を解放する。
func _base_stats() -> Dictionary:
	var context := RunContext.new()
	context.cfg = ContentManager.base
	context.state = RunState.new()
	context.profile = {"mult":{}, "add":{}, "reduce":{}}
	context.loadout = LoadoutSystem.new()
	context.loadout.setup(context)
	var values := {}
	for property in context.state.stats.get_property_list():
		if property.type in [TYPE_FLOAT, TYPE_INT]: values[property.name] = context.state.stats.get(property.name)
	context.loadout.dispose()
	context.loadout = null
	return values

func _physics_process(dt: float) -> void:
	if core == null or batch == null: return
	var cycle := input_tick % 150
	if cycle == 0: pen_origin = core.ship_snapshot().ship_pos
	var command := {"has_cursor":true, "cursor":origin+Vector2.from_angle(input_tick/180.0)*900.0,
		"touch":false, "press":cycle==0 or cycle==12, "pen":pen_origin+Vector2(cycle*35, sin(cycle*0.3)*35)}
	if not core.step_frame(dt, command, camera.position, get_viewport_rect().size/2.0, 1.0):
		push_error("比較経路の更新に失敗しました")
		get_tree().quit(1)
		return
	for item in core.drain_collections():
		if item.kind == "gem": collected_xp += float(item.value)
	core.drain_events()
	input_tick += 1

func _upload(target: InstanceBatch, buffer: PackedFloat32Array) -> int:
	var count := buffer.size()/InstanceBatch.STRIDE
	if target.multimesh.instance_count != count: target.multimesh.instance_count = count
	target.multimesh.buffer = buffer
	return count

func _process(_dt: float) -> void:
	if core == null or batch == null: return
	ship = core.ship_snapshot()
	drawing = core.draw_snapshot()
	camera.position = ship.ship_pos
	var count := _upload(batch, core.enemy_buffer(&"drifter", visual_scale, PI/2.0))
	var size := get_viewport_rect().size
	var view := Rect2(camera.position-size/2.0, size).grow(60.0)
	_upload(gem_batch, core.pickup_buffer(&"gem", 5.0, Color("#b8a0ff"), view))
	_upload(coin_batch, core.pickup_buffer(&"coin", 6.0, Color("#ffd24a"), view))
	label.text = "C++の代表経路：移動・描線・接触・撃破・回収\n敵 %d ／ 撃破 %d ／ 回収XP %.1f\n装備・地形・成長・全演出は未接続。通常ステージの性能判定には使いません。" % [count, core.combat_snapshot().kills, collected_xp]
	queue_redraw()
	frames += 1
	if (Time.get_ticks_usec()-started_us)/1000000.0 < float(options.get("seconds", "3")): return
	set_process(false)
	set_physics_process(false)
	if options.has("capture") and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(options.capture)
	print("NATIVE_PROBE ", JSON.stringify({"enemies":count,"frames":frames,"ticks":core.inspect().ticks,"kills":core.combat_snapshot().kills,"collected_xp":collected_xp}))
	core.close()
	get_tree().quit()

func _draw() -> void:
	if ship.is_empty() or drawing.is_empty(): return
	var points: PackedVector2Array = drawing.draw_points if drawing.drawing else drawing.trace_path if drawing.tracing else PackedVector2Array()
	if points.size() >= 2: draw_polyline(points, Color("#6dffb0"), 3.0)
	var heading: Vector2 = ship.ship_heading
	draw_set_transform(ship.ship_pos, heading.angle()+PI/2.0)
	draw_texture_rect(ship_texture, Rect2(Vector2(-ship_texture.get_width()/2.0,-30.0)*character_scale,ship_texture.get_size()*character_scale), false)
	draw_set_transform(Vector2.ZERO)
