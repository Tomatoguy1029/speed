## 装備は、それぞれのランのContextだけから状態と他のSystemを引く。
extends Node
var failed := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failed += 1
		push_error(message)
func _ready() -> void:
	var a := RunManager.create_session(self, {"lab": true, "seed": 7}, false)
	var b := RunManager.create_session(self, {"lab": true, "seed": 8}, false)
	a.auto_step = false
	b.auto_step = false
	for session in [a, b]:
		for id in [&"fullCharge", &"critBeam", &"endBlast", &"reactive", &"vortex", &"killSonic"]:
			var behavior = load("res://scripts/traits/%s.gd" % id).new()
			var props := {}
			for prop in behavior.get_property_list():
				props[prop.name] = true
			check(props.has("ctx") and not props.has("build"), "%sはRunContextを受け取る" % id)
			if props.has("ctx"):
				behavior.setup(session.sim.ctx, TraitDef.new())
				check(behavior.state == session.sim.state and behavior.cfg == session.sim.cfg, "特性は自分のランだけを参照する")
				behavior.ctx = null
	a.free()
	b.free()
	await get_tree().process_frame
	print("[equipment_context] %d failures" % failed)
	get_tree().quit(1 if failed else 0)
