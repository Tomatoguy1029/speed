## 攻撃の表示を読み込めることと、水流の資源を初回使用時だけ準備することを確認する。
extends Node

var failed := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failed += 1
		push_error(message)

func _ready() -> void:
	var script = load("res://scripts/managers/render_manager.gd")
	check(script != null and script.can_instantiate(), "攻撃の表示を含む描画を生成できる")
	if failed > 0:
		get_tree().quit(1)
		return
	var render = script.new()
	var world := Node2D.new()
	world.name = "World"
	render.add_child(world)
	render.world_path = NodePath("World")
	var projectiles := DrawLayer.new()
	world.add_child(projectiles)
	render._layers.projectiles = projectiles
	render.pipeline = RenderPipeline.new()
	render.add_child(render.pipeline)
	check(not ResourceLoader.has_cached("res://shaders/water_flood.gdshader"), "水流を使う前に専用shaderを読まない")
	for kind in ["bullet", "missile", "reflected", "shell", "slash", "bolt", "beam", "zone", "wave", "wall"]:
		var visual = render._attack_visual(kind)
		check(visual != null, "%sの表示を生成できる" % kind)
	check(not ResourceLoader.has_cached("res://shaders/water_flood.gdshader"), "通常の攻撃は水流のshaderを読まない")
	var flood = render.flood()
	check(flood != null and ResourceLoader.has_cached("res://shaders/water_flood.gdshader"), "水流の初回使用でshaderを準備する")
	check(render.flood() == flood and world.get_node_or_null("Flood") != null, "水流の層を再利用する")
	render.free()
	print("[attack_presentation] %d failures" % failed)
	get_tree().quit(1 if failed else 0)
