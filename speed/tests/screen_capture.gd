## 画面の確認用：決まった手順で画面を移り、それぞれの画面を PNG に保存する（tasks/plan.md の確認のコマンド）。
## 実行中はセーブを退避し、終わったら元に戻す。
##
##   Godot --path speed res://tests/screen_capture.tscn -- --out=<フォルダ> [--steps=flow|run]
extends Node

const SAVE := "user://save.json"
const BACKUP := "user://save.json.capture_backup"

var out_dir := "user://captures"
var steps := "flow"
var main: Node

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.get_slice("=", 1)
		elif a.begins_with("--steps="):
			steps = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out_dir)
	_backup()
	SaveManager.data = SaveManager.default_data()
	main = load("res://scenes/app/main.tscn").instantiate()
	add_child(main)
	await _wait(0.5)
	match steps:
		"run":
			await _run_steps()
		"dash":
			await _dash_steps()
		"boss":
			await _boss_steps()
		"perf":
			await _perf_steps()
		"weapons":
			await _weapons_steps()
		"death":
			await _death_steps()
		"panel":
			await _panel_steps()
		"reroll":
			await _reroll_steps()
		_:
			await _flow_steps()
	_restore()
	get_tree().quit()

func _flow_steps() -> void:
	await _shot("01_title")
	GameManager.goto(GameManager.Screen.SETTINGS)
	await _shot("02_settings")
	GameManager.back()
	GameManager.goto(GameManager.Screen.MAIN_MENU)
	await _shot("03_main_menu")
	GameManager.goto(GameManager.Screen.STAGE_SELECT)
	await _shot("04_stage_select")
	GameManager.start_run(1)
	await _shot("05_run")
	_run_manager().command(&"debug_clear")
	await _shot("06_result")
	GameManager.reset_to_main_menu()
	GameManager.goto(GameManager.Screen.STAGE_SELECT)
	await _shot("07_stage_select_after_clear")
	GameManager.back()
	GameManager.goto(GameManager.Screen.UPGRADE)
	await _shot("08_upgrade")
	GameManager.back()
	GameManager.goto(GameManager.Screen.ENCYCLOPEDIA)
	await _shot("09_encyclopedia")

## ランの中の確認（段階2以降で使う）。
func _run_steps() -> void:
	GameManager.start_run(1)
	for i in 6:
		await _shot("run_%02d" % i, 1.0)

## 線を描いて駆け抜ける確認：クリックで描き始め、マウスを動かして線を引き、もう一度クリックで確定する。
func _dash_steps() -> void:
	GameManager.start_run(1)
	await _wait(2.5)
	var c := get_viewport().get_visible_rect().size / 2.0
	_mouse_move(c + Vector2(80, 0))
	await _wait(0.1)
	_click(c + Vector2(80, 0))
	var pts := [Vector2(200, -120), Vector2(320, -60), Vector2(380, 80), Vector2(250, 160), Vector2(80, 120)]
	for p in pts:
		for k in 6:
			await get_tree().process_frame
		_mouse_move(c + p)
	await _shot("dash_00_drawing", 0.2)
	_click(c + pts[pts.size() - 1])
	await _shot("dash_01_tracing", 0.15)
	await _shot("dash_02_after", 0.6)
	await _shot("dash_03_glide", 1.0)

## ボスの出現から撃破の演出、結果画面までの確認。
func _boss_steps() -> void:
	GameManager.start_run(1)
	await _wait(1.0)
	_run_manager().command(&"debug_boss_time")
	await _shot("boss_00_spawn", 1.5)
	await _shot("boss_01_fight", 2.0)
	_run_manager().command(&"debug_kill_boss")
	await _shot("boss_02_replay", 0.6)
	await _shot("boss_03_blast", 1.2)
	await _shot("boss_04_clear", 2.2)
	await _shot("boss_05_result", 2.0)

## 敵が最も多い時間帯（無双期）での処理時間の確認。
func _perf_steps() -> void:
	GameManager.start_run(1)
	await _wait(0.5)
	var run := _run_manager()
	run.ship.invincible = true
	run.command(&"debug_time", {"seconds": 320.0})
	await _wait(6.0)
	run.profiling = true
	var phys := 0.0
	var proc := 0.0
	var n := 0
	var frames := 0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5000:
		await get_tree().process_frame
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		n += 1
	frames = n
	var alive := 0
	for e in run.enemies.list:
		if not e.dead:
			alive += 1
	print("[perf] enemies=%d fps=%.1f physics_ms=%.2f process_ms=%.2f" % [alive, frames / 5.0, phys / n, proc / n])
	for k in run.profile:
		var rec: Array = run.profile[k]
		print("[perf]   %s %.3f ms/tick" % [k, float(rec[0]) / maxi(1, rec[1]) / 1000.0])
	await _shot("perf_rampage", 0.1)

## すべての武器と発動する特性を持たせ、敵が多い時間帯で線を描いて駆け抜ける。
func _weapons_steps() -> void:
	GameManager.start_run(1)
	await _wait(0.5)
	var run := _run_manager()
	run.ship.invincible = true
	for id in ConfigManager.weapons:
		run.command(&"debug_grant", {"kind": &"weapon", "id": id, "levels": 5})
	for id in [&"T01", &"T02", &"T03", &"T05", &"T06"]:
		run.command(&"debug_grant", {"kind": &"trait", "id": id, "levels": 5})
	run.command(&"debug_time", {"seconds": 300.0})
	await _wait(3.0)
	await _shot("weapons_00_idle", 0.1)
	var c := get_viewport().get_visible_rect().size / 2.0
	_mouse_move(c + Vector2(60, 0))
	await _wait(0.1)
	_click(c + Vector2(60, 0))
	for p in [Vector2(300, -200), Vector2(450, 100), Vector2(150, 250), Vector2(-250, 150), Vector2(-350, -150)]:
		for k in 5:
			await get_tree().process_frame
		_mouse_move(c + p)
	_click(c + Vector2(-350, -150))
	await _shot("weapons_01_trace", 0.25)
	await _shot("weapons_02_after", 0.5)
	print("[weapons] loadout W=%s T=%s kills=%d" % [run.state.weapons, run.state.traits, run.state.kills])

## 被弾と致命傷の演出。
func _death_steps() -> void:
	GameManager.start_run(1)
	await _wait(1.0)
	var run := _run_manager()
	run.command(&"debug_hurt")
	await _shot("death_00_hurt", 0.05)
	await _wait(0.5)
	run.command(&"debug_die")
	await _shot("death_01_freeze", 0.4)
	await _shot("death_02_explode", 0.9)
	await _shot("death_03_gameover", 0.7)
	await _shot("death_04_result", 1.6)

## 調整パネルとポーズ、ランの後の図鑑。
func _panel_steps() -> void:
	GameManager.start_run(1)
	await _wait(1.0)
	_action(&"debug_panel")
	await _shot("panel_00_debug", 0.3)
	_action(&"debug_panel")
	_action(&"pause")
	await _shot("panel_01_pause", 0.3)
	_action(&"pause")
	var run := _run_manager()
	run.command(&"debug_grant", {"kind": &"weapon", "id": &"W08", "levels": 3})
	run.command(&"debug_grant", {"kind": &"trait", "id": &"T04", "levels": 2})
	run.command(&"debug_level_up")
	await _shot("panel_02_cards", 0.5)
	run.command(&"choose_card", {"index": 0})
	run.command(&"debug_clear")
	await _wait(0.5)
	GameManager.reset_to_main_menu()
	GameManager.goto(GameManager.Screen.ENCYCLOPEDIA)
	await _shot("panel_03_encyclopedia", 0.4)

## 3択の引き直しと、続けて上がったレベルの3択、強化画面。
func _reroll_steps() -> void:
	GameManager.start_run(1)
	await _wait(1.0)
	var run := _run_manager()
	run.command(&"debug_level_up")
	run.command(&"debug_level_up")
	await _shot("reroll_00_cards", 0.4)
	for i in 3:
		_action(&"reroll")
	await _shot("reroll_01_after_three", 0.4)
	run.command(&"choose_card", {"index": 0})
	await _shot("reroll_02_next_level", 0.4)
	run.command(&"choose_card", {"index": 0})
	run.command(&"abort")
	await _wait(0.5)
	GameManager.goto(GameManager.Screen.UPGRADE)
	await _shot("reroll_03_upgrade", 0.4)

func _action(name: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = name
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = name
	up.pressed = false
	Input.parse_input_event(up)

func _mouse_move(p: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = p
	ev.global_position = p
	Input.parse_input_event(ev)

func _click(p: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = p
		ev.global_position = p
		Input.parse_input_event(ev)

func _run_manager() -> RunManager:
	return get_tree().root.find_child("RunManager", true, false) as RunManager

func _shot(name: String, wait := 0.4) -> void:
	await _wait(wait)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("[capture] ", name)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _backup() -> void:
	if FileAccess.file_exists(SAVE):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE), ProjectSettings.globalize_path(BACKUP))

func _restore() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(BACKUP), ProjectSettings.globalize_path(SAVE))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP))
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
