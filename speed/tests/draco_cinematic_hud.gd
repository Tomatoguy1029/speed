extends Node
var failures := 0
func check(ok: bool, text: String) -> void:
	if not ok:
		failures += 1
		push_error(text)
func _ready() -> void:
	var stage: RuntimeStage = ContentManager.runtime_stage(5).duplicate(true)
	stage.boss_enabled = false
	var session := RunManager.create_session(self,{"lab":true,"stage":stage,"stage_index":5,"seed":705},true)
	session.auto_step = false
	var sim := session.sim
	sim.bosses.spawn(load("res://data/bosses/draco.tres"),Vector2.ZERO)
	var actor = sim.bosses.actor
	actor.selection_enabled = false
	var hud = session.view.get_node("Hud/HudRoot")
	actor.entrance.begin()
	actor.entrance.time = 0.5
	hud._process(0.0)
	check(hud._entrance_skip.visible,"登場中だけ明示的なスキップボタンを表示する")
	check(not hud._frame.visible,"登場の黒帯中は通常HUDを隠す")
	check(not hud._can_show_draw_button(true),"タッチ操作も登場中は描くボタンを隠す")
	sim.command(&"skip_boss_entrance")
	check(not actor.entrance.active and actor.mode == &"idle","明示的なコマンドで登場を終えて戦闘へ渡す")
	hud._process(0.0)
	check(not hud._entrance_skip.visible and hud._frame.visible,"戦闘に戻るとスキップを隠し通常HUDを戻す")
	check(hud._can_show_draw_button(true),"登場後はタッチの描くボタンも通常PLAYのまま復帰する")
	sim.command(&"skip_boss_entrance")
	check(actor.mode == &"idle","戦闘中のスキップ連打で状態を変えない")
	sim.state.cinematic_bars = 1.0
	sim.state.final_modules = [&"legendary_stern",&"legendary_keel",&"legendary_sail",&"legendary_compass"]
	hud._process(0.0)
	check(hud._loadout_icons.visible and not hud._frame.visible,"合体後は黒帯中も伝説の武器欄を見せる")
	var count := 0
	for child in hud._loadout_icons.get_children():
		if child.get("module_id") != null: count += 1
	check(count == 4,"合体した四つの部品図が実際の武器欄にある")
	session.free()
	print("[draco_cinematic_hud] failures=",failures)
	get_tree().quit(1 if failures else 0)
