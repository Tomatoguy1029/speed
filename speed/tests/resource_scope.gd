## 表示なしのランと、未使用の演出が専用素材を保持しないことを確認する。
extends Node
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	var session := RunManager.create_session(self, {"lab": true, "seed": 42}, false)
	session.auto_step = false
	for path in ["res://assets/pixel/meteor_spritesheet.png", "res://assets/pixel/drone.png",
		"res://assets/pixel/airship.png", "res://scenes/run/ult_cutin.tscn", "res://scenes/run/legendary_reveal.tscn"]:
		check(not ResourceLoader.has_cached(path), "表示なしのランが専用資源を読まない: " + path)
	session.free()
	await get_tree().process_frame
	var config := ConfigManager.cfg.duplicate() as GameConfig
	config.meteor_count = 0
	config.iron_count = 0
	config.saw_count = 0
	session = RunManager.create_session(self, {"lab": true, "seed": 42, "config": config}, true)
	session.auto_step = false
	for path in ["res://assets/pixel/meteor_spritesheet.png", "res://assets/pixel/drone.png",
		"res://scenes/run/ult_cutin.tscn", "res://scenes/run/legendary_reveal.tscn"]:
		check(not ResourceLoader.has_cached(path), "未使用の演出・隕石は表示付きでも専用資源を読まない: " + path)
	session.free()
	await get_tree().process_frame
	print("[resource_scope] %d failures" % failed)
	get_tree().quit(1 if failed else 0)
