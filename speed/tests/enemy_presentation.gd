## 同じ移動を使う敵でも、固有の本体表示を持てる。
extends Node
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	var session := RunManager.create_session(self, {"lab": true, "seed": 42}, false)
	session.auto_step = false
	var render := RunPresentation.new()
	render.run = session.sim
	render.state = session.sim.state
	render.cfg = session.sim.cfg
	check(render.has_method("_visual_for_type"), "敵の固有表示を取得できる")
	if render.has_method("_visual_for_type"):
		var row := session.sim.enemies.spawn(session.sim.enemies.def_of(&"meteor"), Vector2.ZERO)
		var visual = render._visual_for_type(&"meteor")
		check(visual != null and visual.get_script().resource_path.ends_with("/meteor.gd"), "隕石は移動の種類と独立した表示を持つ")
		check(visual.sprite_radius(session.sim.enemies.table, row) == session.sim.enemies.table.r[row], "隕石の描画半径を維持する")
		check(render._visual_for_type(&"meteor") == visual, "同じ種類の表示を再利用する")
	render.free()
	session.free()
	await get_tree().process_frame
	print("[enemy_presentation] %d failures" % failed)
	get_tree().quit(1 if failed else 0)
