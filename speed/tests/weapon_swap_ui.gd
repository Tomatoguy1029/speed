## 交換画面の表示と選択を短時間確認する。セーブはメモリだけで扱う。
## Godot --headless --path speed res://tests/weapon_swap_ui.tscn
## 描画付きでは --headless を外し、-- --out=/tmp/speed-swap-ui を付ける。
extends "res://tests/card_input_guard.gd"

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			shots = arg.trim_prefix("--out=")
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
	var settings_copy: Dictionary = SaveManager.settings.duplicate(true)
	SaveManager.set_script(MemorySave)
	SaveManager.settings = settings_copy
	get_window().content_scale_size = Vector2i.ZERO
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1280, 720)
	await _start(1)
	run.input.set_process_unhandled_input(true)
	hud = scene.view.get_node("Hud/HudRoot")
	await _open_swap()
	var grid: GridContainer = hud.get("_swap_grid")
	var new_name: Label = hud.get("_swap_new_name")
	_check(grid != null and new_name != null, "交換専用の新武器情報と所持武器の選択欄を表示する")
	if grid == null or new_name == null:
		await _finish()
		return
	_check(not hud._cards_row.visible and grid.get_child_count() == run.cfg.weapon_slots, "交換候補には所持武器だけを並べる")
	_check(new_name.text == ContentManager.weapons[&"W22"].get_display_name(), "上の情報欄に拾った武器を1つ表示する")
	var before: Dictionary = run.state.weapons.duplicate()
	await _wait_real()
	point = new_name.get_global_rect().get_center()
	_click_card()
	_check(run.state.weapons == before and run.state.phase == RunState.Phase.LEVELUP, "新武器情報はクリックしても選択にならない")
	for i in grid.get_child_count():
		var b: Button = grid.get_child(i)
		var card: Dictionary = run.state.cards[i]
		var def: WeaponDef = ContentManager.weapons[card.id]
		_check(b.text.contains(def.get_description()) and b.text.contains("Lv%d" % card.level), "交換候補%dには固有の説明と所持Lvを表示する" % i)
		_check(b.get_theme_stylebox("normal").border_color == hud.RANK_COLORS[card.level - 1], "交換候補%dは所持Lvの枠色を使う" % i)
	await _shot("swap_wide")
	var removed: StringName = run.state.cards[1].id
	point = grid.get_child(1).get_global_rect().get_center()
	_click_card()
	_check(run.state.phase == RunState.Phase.PLAY and not run.state.weapons.has(removed) and run.state.weapons.get(&"W22") == run.cfg.weapon_max_level, "選んだ所持武器だけを新武器と交換する")
	for id in before:
		if id != removed:
			_check(run.state.weapons[id] == before[id], "交換しない所持武器のLvを保つ")
	_check(not run.loadout._receive_comet_weapon(&"W22") and run.state.phase == RunState.Phase.PLAY, "同じ彗星武器を受け取ったときの既存ルールを保つ")
	await _open_swap()
	before = run.state.weapons.duplicate()
	point = hud.get("_swap_keep").get_global_rect().get_center()
	_click_card()
	_check(run.state.phase == RunState.Phase.LEVELUP and run.state.weapons == before, "交換画面にも0.3秒ガードを適用する")
	await _wait_real()
	_click_card()
	_check(run.state.phase == RunState.Phase.PLAY and run.state.weapons == before, "受け取らないときは現在の装備を保つ")
	await _open_swap()
	# サイズ確認はHUDを対象にし、世界側のエフェクトは静止したまま描く。
	scene.view.get_node("RunPresentation").set_process(false)
	for viewport_size in [Vector2i(640, 720), Vector2i(360, 640), Vector2i(640, 360)]:
		get_window().size = viewport_size
		await _settle()
		var visible := get_viewport().get_visible_rect()
		_check(visible.encloses(hud._cards_box.get_global_rect()), "%s：交換画面が表示領域へ収まる" % viewport_size)
		_check(visible.encloses(hud.get("_swap_keep").get_global_rect()), "%s：受け取らないボタンを常に表示する" % viewport_size)
		var scroll: ScrollContainer = hud.get("_swap_scroll")
		for b: Button in grid.get_children():
			scroll.ensure_control_visible(b)
			await get_tree().process_frame
			var rect := b.get_global_rect()
			_check(rect.position.x >= scroll.global_position.x and rect.end.x <= scroll.get_global_rect().end.x + 1.0 and rect.intersects(scroll.get_global_rect()), "%s：各候補へ縦スクロールで到達できる" % viewport_size)
		scroll.scroll_vertical = 0
		await _shot("swap_%dx%d" % [viewport_size.x, viewport_size.y])
	get_window().size = Vector2i(360, 640)
	await _settle()
	await _wait_real()
	var touch_scroll: ScrollContainer = hud.get("_swap_scroll")
	touch_scroll.scroll_vertical = 0
	point = touch_scroll.get_global_rect().get_center()
	var emulating_touch := Input.emulate_touch_from_mouse
	Input.emulate_touch_from_mouse = true
	_touch(true)
	# ScrollContainer はタッチから変換されたマウスの動きでスクロールする。
	var drag := InputEventMouseMotion.new()
	drag.device = -1
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	drag.relative = Vector2(0, -160)
	drag.position = point + drag.relative
	drag.global_position = drag.position
	get_viewport().push_input(drag, true)
	await _settle()
	point = drag.position
	_touch(false)
	Input.emulate_touch_from_mouse = emulating_touch
	_check(touch_scroll.scroll_vertical > 0 and run.state.phase == RunState.Phase.LEVELUP, "タッチのスクロールを選択にせず、下の交換候補へ移動できる")
	TranslationServer.set_locale("en")
	await _open_swap()
	await _shot("swap_en_small")
	_check(hud.get("_swap_new_desc").text == ContentManager.weapons[&"W22"].get_description(), "英語も既存の武器説明を使う")
	TranslationServer.set_locale("ja")
	get_window().size = Vector2i(1280, 720)
	run.state.swap_pick = &""
	await _open()
	_check(hud._cards_row.visible and not hud.get("_swap_scroll").visible and hud._cards_row.get_child_count() == 3, "通常レベルアップは既存の3択を保つ")
	await _shot("normal_levelup")
	run.state.pending_levels = 0
	run.loadout.open_start_cards()
	await _settle()
	_check(hud._cards_row.visible and not hud.get("_swap_keep").visible and run.state.start_pick, "初期武器選択も既存の表示を保つ")
	await _shot("initial_weapon")
	await _finish()

func _open_swap() -> void:
	run.loadout.reset_loadout()
	for i in run.cfg.weapon_slots:
		run.loadout.grant(&"weapon", StringName("W%02d" % (i + 1)), i + 1)
	run.state.start_pick = false
	run.state.pending_levels = 0
	run.state.swap_pick = &""
	run.set_phase(RunState.Phase.PLAY)
	_check(run.loadout._receive_comet_weapon(&"W22"), "装備満杯で交換画面を開く")
	await _settle()

func _settle() -> void:
	for i in 4:
		await get_tree().process_frame

func _finish() -> void:
	await _close()
	print("[weapon-swap-ui] passed=%d failed=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)
