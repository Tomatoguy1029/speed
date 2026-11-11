## 非表示中も通常の武器選択・ポーズ・再表示が使え、審査版には入口を作らない。
extends "res://tests/integration/card_input_guard.gd"

func _ready() -> void:
	var settings_copy: Dictionary = SaveManager.settings.duplicate(true)
	SaveManager.set_script(MemorySave)
	SaveManager.settings = settings_copy
	SaveManager.data = SaveManager.default_data()
	SaveManager.data.intro_seen = true
	scene = await _cpp_open(1, false)
	if scene.bridge == null:
		_check(false, "通常ランを開始できる")
		await _close()
		get_tree().quit(1)
		return
	bridge = scene.bridge
	router = scene.view.get_node("World/InputRouter")
	hud = scene.view.get_node("Hud/HudRoot")
	var panel: Control = scene.view.get_node_or_null("Hud/DebugPanel")
	if SaveManager.is_review_build():
		_check(panel == null, "審査モードにはデバッグパネルを生成しない")
		var rejected = load("res://scripts/dev/hud_visibility.gd").new()
		rejected.hud = hud
		add_child(rejected)
		rejected.set_hidden(true)
		_check(not rejected.hidden and hud.self_modulate.a == 1.0, "審査モードでは直接の切替も拒否する")
		rejected.free()
	else:
		_check(panel != null, "開発ランにはデバッグパネルがある")
		if panel != null:
			var button: CheckButton = panel.find_child("HidePlayUi", true, false)
			_check(button != null and not button.button_pressed, "新しいランではUI表示から始まる")
			var key := InputEventAction.new()
			key.action = &"debug_panel"
			key.pressed = true
			panel._input(key)
			_check(panel.visible, "P操作で設定を開ける")
			button.button_pressed = true
			panel._close()
			await get_tree().process_frame
			_check(hud.self_modulate.a == 0.0, "HUD自身のゲージ・マップ・文字を消す")
			for field: String in panel._hud_visibility.COMBAT_ITEMS:
				_check(hud.get(field).modulate.a == 0.0, "別ノードの戦闘UIも消す: " + field)
			_check(hud._draw_button.mouse_filter == Control.MOUSE_FILTER_IGNORE, "透明な操作ボタンは入力を遮らない")
			bridge.command("pause", {"paused": false})
			bridge.collect_frame()
			_check(bridge.command("dev_edit", {"kind": "progression", "payload": {"pending_levels": 1}}).ok, "レベルアップによる通常の候補を開く")
			_step()
			await _position_card()
			_check(hud._cards_box.visible and hud._cards_box.modulate.a == 1.0 and hud._cards_dim.modulate.a == 1.0, "武器候補と暗幕は表示を維持する")
			var chosen: Dictionary = {}
			for i in _ui().cards.candidates.size():
				var candidate: Dictionary = _ui().cards.candidates[i]
				if candidate.kind == "weapon":
					chosen = candidate
					point = hud._cards_row.get_child(i).get_global_rect().get_center()
					break
			_check(not chosen.is_empty(), "選択可能な武器候補がある")
			var before: Array = _ui().weapon_levels.duplicate(true)
			await _wait_real()
			_click_card()
			await _settle_choice()
			_check(_ui().weapon_levels != before, "UI非表示のまま実際の武器を選択・取得できる")
			_check(hud._rewards.modulate.a == 1.0, "獲得演出は透明にしない")
			bridge.command("pause", {"paused": true})
			bridge.collect_frame()
			_check(hud._pause_box.visible and hud._pause_box.modulate.a == 1.0, "非表示中もポーズメニューを使える")
			for enabled in [false, true, false]:
				panel._input(key)
				_check(panel.visible, "非表示中もP操作で開き直せる")
				button.button_pressed = enabled
				panel._close()
				_check(hud.self_modulate.a == (0.0 if enabled else 1.0), "繰り返し切替で表示を復元する")
			_check(hud._speed_indicator.modulate.a == 1.0 and hud._draw_button.mouse_filter == Control.MOUSE_FILTER_STOP, "子UIの色と入力も復元する")
			button.button_pressed = true
			var old_ui: Dictionary = hud._cpp_ui
			hud._cpp_ui = {"phase": CardPhase.Finishing, "boss_finish": {"active": true}}
			panel._hud_visibility._apply()
			_check(hud.self_modulate.a == 1.0, "伝説の武器獲得と終了演出は維持する")
			hud._cpp_ui = old_ui
			panel._hud_visibility.free()
			_check(hud.self_modulate.a == 1.0, "機能を外す際も元の表示へ戻す")
	await _close()
	print("[hide_play_ui] passed=%d failed=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)
