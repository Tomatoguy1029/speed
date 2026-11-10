## 審査版のラン内変更、通常版の拒否、交換失敗時の保持を確かめる。
extends Node
var failed := 0
const BRIDGE = preload("res://scripts/runtime/run_bridge.gd")
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func make_run(mode: int, stage := 1) -> RefCounted:
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.content/run/stage_%d.json" % stage))
	var bridge = BRIDGE.new()
	if not bridge.configure(FileAccess.get_file_as_bytes(index.binary), {"api_version":1,"run_id":901,"mode":mode,"stage_id":str(stage),"profile":{},"settings":{}}).ok: return null
	if not bridge.start(391).ok: return null
	return bridge
func equipment(bridge: RefCounted, id: String, level: int, replace := "", kind := "weapon") -> Dictionary:
	return bridge.command("review_equipment", {"kind":kind,"id":id,"level":level,"replace":replace})
func _ready() -> void:
	if "--ui-only" in OS.get_cmdline_user_args():
		await check_ui()
		print("[review_ui] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	for mode in [0, 1]:
		var normal = make_run(mode)
		check(normal != null, "通常・開発モードを開始する")
		if normal == null: continue
		normal.command("pause", {"paused":true})
		check(not normal.command("review_invincible", {"value":true}).ok, "通常・開発ランは審査版操作を拒否する")
		normal.dispose()
	var bridge = make_run(2)
	check(bridge != null, "審査版を開始する")
	if bridge == null:
		get_tree().quit(1)
		return
	check(not bridge.read_frame().value.ui.invincible, "無敵の初期値はオフ")
	check(not equipment(bridge,"W01",2).ok, "プレイ中の変更を拒否する")
	bridge.command("pause", {"paused":true})
	check(equipment(bridge,"W01",3).ok and equipment(bridge,"W01",1).ok, "装備レベルを上下できる")
	check(equipment(bridge,"W02",2,"W01").ok, "武器を入れ替える")
	var ui: Dictionary = bridge.read_frame().value.ui
	check(ui.weapon_levels.size()==1 and ui.weapon_levels[0].id=="W02" and ui.weapon_levels[0].level==2, "交換後の武器とレベルが一致する")
	check(not equipment(bridge,"W01",999,"W02").ok and bridge.read_frame().value.ui.weapon_levels[0].id=="W02", "無効なレベルでは交換前の武器を保持する")
	var catalog: Dictionary = bridge.command("review_catalog").value
	for id: String in catalog.limits:
		if id.begins_with("W") and id!="W02" and bridge.read_frame().value.ui.weapon_levels.size()<int(catalog.weapon_slots): equipment(bridge,id,1)
	ui = bridge.read_frame().value.ui
	check(ui.weapon_levels.size()==int(catalog.weapon_slots), "通常の所持枠まで追加できる")
	for id: String in catalog.limits:
		if id.begins_with("W") and not ui.weapon_levels.any(func(item): return item.id==id):
			check(not equipment(bridge,id,1).ok, "所持枠を超える追加を拒否する")
			break
	check(not equipment(bridge,"W01",1,"W02").ok and bridge.read_frame().value.ui.weapon_levels.size()==int(catalog.weapon_slots), "所持済み武器への交換指定で別の武器を消さない")
	check(equipment(bridge,"T03",2,"","trait").ok and equipment(bridge,"T03",1,"","trait").ok and equipment(bridge,"T03",0,"","trait").ok, "特性を追加・降格・削除できる")
	bridge.command("dev_edit", {"kind":"debug_action","payload":{"action":"hurt","args":{}}})
	var before: Dictionary = bridge.read_frame().value.ui
	var profile := {"mult":{},"reduce":{},"add":{"max_hp":20.0,"reroll":2.0}}
	check(bridge.command("review_meta", {"levels":PackedInt32Array([0,0,0,0,0,0,0,0]),"profile":profile}).ok, "機体強化を即時適用する")
	ui = bridge.read_frame().value.ui
	check(is_equal_approx(ui.hp, before.hp+20.0) and is_equal_approx(ui.max_hp,before.max_hp+20.0), "最大HPの増加分だけ回復する")
	check(bridge.command("review_meta", {"levels":PackedInt32Array([0,0,0,0,0,0,0,0]),"profile":{}}).ok and bridge.read_frame().value.ui.hp<=before.max_hp, "最大HPの減少時は切り詰める")
	check(bridge.command("review_hero", {"id":"gemini"}).ok, "英雄の力を変更する")
	check(bridge.command("review_invincible", {"value":true}).ok, "無敵を切り替える")
	ui = bridge.read_frame().value.ui
	var owned: Array = ui.weapon_levels.duplicate(true)
	var hp: float = ui.hp
	var enemy: Dictionary = bridge.command("dev_spawn", {"definition_id":"shield","position":Vector2(200,0)})
	check(enemy.ok, "移動前の敵を配置する")
	for pool in [0,1]: check(bridge.command("dev_emit_attack", {"pool":pool,"position":Vector2(300,0),"life":10.0}).ok, "移動前の敵味方の弾を配置する")
	check(not bridge._core.attack_snapshot().is_empty(), "移動前に弾が存在する")
	check(bridge.command("review_boss").ok, "ボス出現へ移動する")
	ui = bridge.read_frame().value.ui
	check(ui.weapon_levels==owned and ui.hp==hp and ui.hero.power=="gemini" and not ui.boss_bodies.is_empty(), "ボス移動で装備・英雄・HPを引き継ぐ")
	check(bridge._core.attack_snapshot().is_empty(), "ボス移動で敵味方の弾を消去する")
	if enemy.ok: check(not bridge._core.enemies_snapshot().any(func(item): return item.id==enemy.value), "ボス移動で配置した敵を消去する")
	check(not bridge.command("review_boss").ok, "出現済みのボスへ重ねて移動しない")
	bridge.dispose()
	var fresh = make_run(2)
	check(fresh != null and not fresh.read_frame().value.ui.invincible and fresh.read_frame().value.ui.weapon_levels.size()==1, "次のランへ変更を引き継がない")
	if fresh != null: fresh.dispose()
	for stage in [2,3,4,5]:
		var boss_run = make_run(2,stage)
		check(boss_run != null, "ステージ%dの審査版を開始する" % stage)
		if boss_run == null: continue
		boss_run.command("pause", {"paused":true})
		check(boss_run.command("review_boss").ok and not boss_run.read_frame().value.ui.boss_bodies.is_empty(), "ステージ%dのボスへ通常の登場処理で移動する" % stage)
		boss_run.dispose()
	print("[review_mode] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)

func check_ui() -> void:
	check(SaveManager.is_review_build(), "審査版の識別を使う")
	check(SaveManager.save_path()!=SaveManager.SAVE_PATH and SaveManager.settings_path()!=SaveManager.SETTINGS_PATH, "審査版の保存先を分離する")
	var original: String = FileAccess.get_file_as_string(SaveManager.SAVE_PATH) if FileAccess.file_exists(SaveManager.SAVE_PATH) else ""
	check(SaveManager.record_run({"cleared":true,"stage":5,"time":300.0}), "全解放での後半クリアを保存する")
	check(SaveManager.is_stage_unlocked(5), "後半クリアを審査版の通常進行へ反映する")
	check((FileAccess.get_file_as_string(SaveManager.SAVE_PATH) if FileAccess.file_exists(SaveManager.SAVE_PATH) else "")==original, "通常版のセーブを変えない")
	var owner := RunSession.new()
	owner.bridge = make_run(2)
	owner.auto_step = false
	add_child(owner)
	owner.bridge.command("pause", {"paused":true})
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.content/run/stage_1.json"))
	owner.cpp_resources = load(index.resources)
	owner.cpp_choices = load("res://scripts/runtime/run_choice_resources.gd").new()
	owner.cpp_choices.attach(owner.bridge, owner.cpp_resources, owner)
	var panel := preload("res://scripts/ui/review_settings.gd").new()
	panel.session = owner
	add_child(panel)
	await get_tree().process_frame
	var apply: Button = panel._buttons[0]
	var row := apply.get_parent()
	var target: OptionButton = row.get_child(0)
	var source: OptionButton = row.get_child(1)
	source.select(1)
	source.item_selected.emit(1)
	for i in target.item_count:
		if target.get_item_metadata(i)=="W02":
			target.select(i)
			target.item_selected.emit(i)
	apply.pressed.emit()
	for frame in 600:
		if not panel._busy: break
		await get_tree().process_frame
	check(not panel._busy and panel._status.text==tr("review.applied"), "設定画面から資源を準備して武器を交換する")
	check(owner.bridge.read_frame().value.ui.weapon_levels[0].id=="W02", "画面の入力をC++の装備へ反映する")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/speed-review-settings.png")
	panel.free()
	RunManager.ensure_registered(owner)
	RunManager.current_id = owner.id
	var hud := preload("res://scripts/ui/hud.gd").new()
	hud.bridge = owner.bridge
	hud.cpp_resources = owner.cpp_resources
	hud.size = get_viewport().get_visible_rect().size
	add_child(hud)
	hud.apply_snapshot(owner.bridge.read_frame().value.ui)
	var codex: Button = hud._pause_box.get_node("CodexButton")
	var custom: Button = hud._pause_box.get_node("ReviewSettingsButton")
	check(codex != null and custom != null, "図鑑とカスタム設定の両方をメニューに保持する")
	codex.pressed.emit()
	check(hud._menu_overlay is UiScreen and owner.bridge.read_frame().value.ui.phase==hud.Phase.Paused, "図鑑を開いて停止状態を保つ")
	if hud._menu_overlay is UiScreen: hud._menu_overlay.close_fn.call()
	await get_tree().process_frame
	custom.pressed.emit()
	check(hud._menu_overlay != null and hud._menu_overlay.get_script()==preload("res://scripts/ui/review_settings.gd"), "図鑑から戻ってカスタム設定を開ける")
	if hud._menu_overlay != null: hud._menu_overlay.finished.emit()
	hud.free()
	owner.free()
