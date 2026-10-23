## 攻撃の範囲と見た目の種類を別々に選び、必要な表示だけを生成する。
extends Node
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	var render := RunPresentation.new()
	check(render.has_method("_hazard_visual"), "攻撃の形と見た目から表示を選べる")
	if render.has_method("_hazard_visual"):
		var session := RunManager.create_session(self, {"lab": true, "seed": 42}, false)
		var pr := session.sim.projectiles
		for style in [ProjectileSystem.HazardStyle.RETICLE, ProjectileSystem.HazardStyle.LIGHTNING, ProjectileSystem.HazardStyle.BITE]:
			var row := pr.fire_zone(Vector2.ZERO, 100, 1, 10, style)
			var visual: AttackVisual = render.call("_hazard_visual", pr, row)
			var expected := "res://scripts/render/attacks/zone_%s.gd" % ProjectileSystem.HazardStyle.keys()[style].to_lower()
			check(visual.get_script().resource_path == expected, "見た目ごとに表示を選ぶ: " + expected)
			check(render.call("_hazard_visual", pr, row) == visual, "生成した表示を再利用する")
		var row := pr.fire_flood(Vector2.ZERO, 0, 500, 30, 0.3, 1, 2, 10)
		check(render.call("_hazard_visual", pr, row).get_script().resource_path.ends_with("/beam_flood.gd"), "水流のビームを専用表示へ渡す")
		session.free()
	render.free()
	print("[hazard_visual_styles] %d failures" % failed)
	get_tree().quit(1 if failed else 0)
