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
	var config := ContentManager.cfg.duplicate() as GameConfig
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
	await _test_async_resources()
	_test_pending_shutdown()
	print("[resource_scope] %d failures" % failed)
	get_tree().quit(1 if failed else 0)

func _test_async_resources() -> void:
	var path := "res://shaders/intro_sky_mist.gdshader"
	var paths := PackedStringArray([path, path])
	var kept := ContentManager.prepare_resources(paths)
	check(ContentManager.pending_resources() > 0, "非同期の読込要求を開始する")
	var cancelled := ContentManager.prepare_resources(paths)
	var dropped: ContentResourceScope = ContentManager.prepare_resources(paths)
	var reference: WeakRef = weakref(dropped)
	dropped = null
	check(reference.get_ref() == null, "読込中の要求は利用側を保持しない")
	cancelled.cancel()
	var limit := Time.get_ticks_msec() + 10000
	while ContentManager.pending_resources() > 0 and Time.get_ticks_msec() < limit:
		await get_tree().process_frame
	check(ContentManager.pending_resources() == 0, "読込と取り消しのタスクを最後まで回収する")
	check(kept.is_ready() and not kept.failed and kept.resources.get(path) is Shader,
		"重複する要求をまとめ、継続した利用側へ資源を渡す")
	check(cancelled.resources.is_empty() and cancelled.pending.is_empty(),
		"共有読込の完了後も取り消した利用側へ資源を戻さない")
	kept.cancel()
	await get_tree().process_frame

func _test_pending_shutdown() -> void:
	var loader: Node = load("res://scripts/managers/content_manager.gd").new()
	add_child(loader)
	var paths := PackedStringArray(["res://data/weapons/W03_knockback.tres", "res://data/meta_upgrades/charge.tres",
		"res://shaders/hydra_tornado.gdshader"])
	if DisplayServer.get_name() != "headless":
		paths.append_array(PackedStringArray(["res://scenes/bosses/hydra_tornado.tscn",
			"res://scenes/bosses/hydra_presentation.tscn", "res://assets/pixel/meteor_spritesheet.png"]))
	# 起動済みの定義やShaderのキャッシュ状況と独立して、未読込の要求を一つ作る。
	var probe_path := "res://.godot/scope_shutdown_probe.gdshader"
	var probe := Shader.new()
	probe.code = "shader_type canvas_item;"
	check(ResourceSaver.save(probe, probe_path) == OK, "終了時の未読込要求に使う資源を作れる")
	paths.append(probe_path)
	var scope: ContentResourceScope = loader.prepare_resources(paths)
	check(loader.pending_resources() > 0, "未回収の読込がある状態で終了を確認する")
	scope.cancel()
	loader.free()
	check(scope.resources.is_empty() and scope.pending.is_empty(), "読込中の所有者を破棄しても取り消し状態を保つ")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(probe_path))
