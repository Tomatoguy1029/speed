## 専用の表示は装備時に作り、装備を外したあとは残る演出の終了で解放する。
extends Node
var failed := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failed += 1
		push_error(message)
func _ready() -> void:
	var session := RunManager.create_session(self, {"lab": true, "seed": 42}, true)
	session.auto_step = false
	var world := session.view.get_node("World")
	var presentation: Node = session.view.get_node("RunPresentation")
	presentation.set_process(false)
	check(world.find_child("LightLance", true, false) == null, "光の槍を装備する前に専用表示を作らない")
	check(world.find_child("Afterimages", true, false) == null, "残像を装備する前に専用表示を作らない")
	session.sim.loadout.grant(&"weapon", &"W24")
	session.sim.loadout.grant(&"weapon", &"W27")
	await get_tree().process_frame
	check(world.find_child("LightLance", true, false) != null, "装備した光の槍の表示を作る")
	check(world.find_child("Afterimages", true, false) != null, "装備した残像の表示を作る")
	world.find_child("LightLance", true, false).hit({"pos": Vector2.ZERO, "dir": Vector2.RIGHT, "level": 1})
	session.sim.loadout.remove_weapon(&"W24")
	session.sim.loadout.remove_weapon(&"W27")
	presentation._process(0.02)
	await get_tree().process_frame
	await get_tree().process_frame
	check(world.find_child("LightLance", true, false) != null, "取り外したあとも命中の閃光が終わるまで表示を保つ")
	presentation._process(0.2)
	await get_tree().process_frame
	check(world.find_child("LightLance", true, false) == null, "演出が終わった光の槍の表示を解放する")
	check(world.find_child("Afterimages", true, false) == null, "演出が終わった残像の表示を解放する")
	session.free()
	await get_tree().process_frame
	print("[equipment_presentation] %d failures" % failed)
	get_tree().quit(1 if failed else 0)
