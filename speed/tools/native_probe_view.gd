## 比較用の追跡・表示だけを起動する。通常ステージの性能判定には使わない。
extends Node2D
var core: RefCounted
var batch: InstanceBatch
var visual_scale := 1.0
var started_us := 0
var options := {}
var frames := 0

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair := arg.trim_prefix("--").split("=", false, 1)
		if pair.size() == 2: options[pair[0]] = pair[1]
	core = load("res://tools/compare_runtime.gd").new().create_native()
	if core == null:
		get_tree().quit(1)
		return
	var definition: EnemyDef = ContentManager.enemies[&"drifter"]
	var data: Dictionary = load("res://tools/content/build_native_data.gd").compile_enemy(definition, ContentManager.base)
	if not core.configure(data) or not core.start(932):
		get_tree().quit(1)
		return
	visual_scale = 1.0 / definition.visual_value("collision_scale", 1.0)
	batch = InstanceBatch.new()
	batch.setup_texture(load("res://assets/pixel/drifter.png"))
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/pixel_sprite.gdshader")
	batch.material = material
	add_child(batch)
	var camera := Camera2D.new()
	add_child(camera)
	var canvas := CanvasLayer.new()
	var label := Label.new()
	label.text = "C++の追跡・表示の動作確認（戦闘は未接続）"
	canvas.add_child(label)
	add_child(canvas)
	var count := clampi(int(options.get("count", "1300")), 1, 10000)
	for i in count:
		var pos := Vector2.from_angle(i * 2.399963) * (100.0 + sqrt(float(i)) * 12.0)
		core.spawn_enemy(&"drifter", pos)
	started_us = Time.get_ticks_usec()

func _physics_process(dt: float) -> void:
	if core == null: return
	core.set_motion_context(Vector2.ZERO, Vector2.ZERO, get_viewport_rect().size / 2.0)
	core.step(dt)

func _process(_dt: float) -> void:
	if core == null or batch == null: return
	var buffer: PackedFloat32Array = core.enemy_buffer(&"drifter", visual_scale, PI / 2.0)
	var count := buffer.size() / InstanceBatch.STRIDE
	if batch.multimesh.instance_count != count: batch.multimesh.instance_count = count
	batch.multimesh.buffer = buffer
	frames += 1
	if (Time.get_ticks_usec() - started_us) / 1000000.0 < float(options.get("seconds", "3")): return
	set_process(false)
	set_physics_process(false)
	if options.has("capture") and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(options.capture)
	print("NATIVE_PROBE ", JSON.stringify({"enemies": count, "frames": frames, "ticks": core.inspect().ticks}))
	core.close()
	get_tree().quit()
