## 終了時の装備処理をLoadoutSystemへ通知し、通常の選択タイミングを保つ。
extends Node
var failed := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failed += 1
		push_error(message)
func _ready() -> void:
	var session := RunManager.create_session(self, {"lab": true, "seed": 42}, false)
	session.auto_step = false
	var loadout := session.sim.loadout
	loadout.grant(&"weapon", &"W27")
	var echo = loadout.weapon_behaviors[&"W27"]
	echo.on_launch(false)
	check(not echo.echoes.is_empty(), "突進開始で残像の経路を作る")
	check(loadout.has_method("on_phase_changed"), "装備管理がランの状態変更を受け取る")
	if loadout.has_method("on_phase_changed"):
		loadout.on_phase_changed(RunState.Phase.FINISHING)
		check(echo.echoes.is_empty(), "終了演出の開始で残像の攻撃を終了する")
	loadout.open_start_cards()
	check(session.sim.state.start_pick and session.sim.state.cards.size() == session.sim.cfg.start_weapon_choices,
		"最初の武器はラン開始後の選択として表示する")
	session.free()
	await get_tree().process_frame
	print("[equipment_phase] %d failures" % failed)
	get_tree().quit(1 if failed else 0)
