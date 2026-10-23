## GPUでロード中に描いたshaderを、実際の敵描画のバッチで初めて使うときのコンパイルを確認する。
extends Node
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	var path := "res://scripts/render/shader_warmup.gd"
	check(ResourceLoader.exists(path), "ロード中のshader準備がある")
	if ResourceLoader.exists(path):
		var scope := ContentManager.prepare_resources(PackedStringArray(["res://shaders/pixel_sprite.gdshader", "res://shaders/pixel_armor.gdshader", "res://shaders/water_flood.gdshader", "res://shaders/hydra_area.gdshader"]), false)
		var warmer: Node = load(path).new()
		add_child(warmer)
		warmer.prepare(scope)
		while not scope.warmup_complete: await get_tree().process_frame
		if DisplayServer.get_name() != "headless":
			get_viewport().use_hdr_2d = RenderingServer.get_current_rendering_method() != "gl_compatibility"
			await get_tree().create_timer(1.1).timeout
			var canvas := Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS)
			var draw := Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)
			var texture := load("res://assets/pixel/drifter.png") as Texture2D
			for resource in scope.resources.values():
				if not resource is Shader: continue
				var batch := InstanceBatch.new()
				batch.setup_texture(texture)
				var material := ShaderMaterial.new()
				material.shader = resource
				batch.material = material
				batch.begin()
				batch.add(Vector2(30, 30), 0.0, 10.0, Color.WHITE)
				batch.end()
				add_child(batch)
			await get_tree().create_timer(1.1).timeout
			var canvas_delta := Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS) - canvas
			var draw_delta := Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW) - draw
			print("[shader_warmup] canvas_delta=%d draw_delta=%d" % [canvas_delta, draw_delta])
			check(canvas_delta == 0 and draw_delta == 0, "準備済みの敵描画で初回コンパイルが増えない")
		else:
			print("[shader_warmup] headless: GPU確認は実描画の実行で行う")
		scope.cancel()
	print("[shader_warmup] %d failures" % failed)
	get_tree().quit(1 if failed else 0)
