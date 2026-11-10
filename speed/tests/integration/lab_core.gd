extends Node
const RunIds := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS

var passed := 0
var failed := 0

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("[lab_core] " + label)

func _ready() -> void:
	if "--cpp-lab-appearance-edits" in OS.get_cmdline_user_args():
		await cpp_lab_appearance_edits()
		print("[cpp_lab_appearance_edits] passed=%d failed=%d" % [passed,failed])
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-lab-operation-ui" in OS.get_cmdline_user_args() or "--cpp-lab-undo-only" in OS.get_cmdline_user_args() or "--cpp-lab-appearance-only" in OS.get_cmdline_user_args() or "--cpp-lab-paint-display" in OS.get_cmdline_user_args():
		await cpp_lab_operation_ui()
		print("[実験場の実操作] 成功=%d 失敗=%d" % [passed,failed])
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-lab-actions" in OS.get_cmdline_user_args():
		await cpp_lab_actions()
		print("[cpp_lab_actions] passed=%d failed=%d" % [passed,failed])
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-lab-boss" in OS.get_cmdline_user_args():
		await cpp_lab_boss()
		print("[cpp_lab_boss] passed=%d failed=%d" % [passed,failed])
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-lab-settings" in OS.get_cmdline_user_args():
		await cpp_lab_settings()
		print("[cpp_lab_settings] passed=%d failed=%d" % [passed,failed])
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-lab-formations" in OS.get_cmdline_user_args() or "--cpp-lab-phase" in OS.get_cmdline_user_args():
		await cpp_lab_formations()
		print("[cpp_lab_formations] passed=%d failed=%d" % [passed,failed])
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-lab-replay" in OS.get_cmdline_user_args() or "--cpp-lab-replay-placement" in OS.get_cmdline_user_args():
		await cpp_lab_replay()
		print("[cpp_lab_replay] passed=%d failed=%d" % [passed,failed])
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-lab-history" in OS.get_cmdline_user_args():
		await cpp_lab_history()
		print("[cpp_lab_history] passed=%d failed=%d" % [passed,failed])
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-lab" in OS.get_cmdline_user_args():
		await cpp_lab()
		print("[cpp_lab_core] passed=%d failed=%d" % [passed,failed])
		get_tree().quit(1 if failed else 0)
		return
	if "--cpp-definition-edits" in OS.get_cmdline_user_args():
		check(await cpp_definition_edits(), "型付き定義編集の確認を最後まで行う")
		print("[cpp_definition_edits] passed=%d failed=%d" % [passed, failed])
		get_tree().quit(1 if failed else 0)
		return
	if not FileAccess.file_exists("res://gyms/enemy_lab/lab_session.gd"):
		check(false, "専用の実験セッションが存在する")
		get_tree().quit(1)
		return
	var script := load("res://gyms/enemy_lab/lab_session.gd")
	var lab = script.new()
	add_child(lab)
	check(is_equal_approx(lab.DT, 1.0 / Engine.physics_ticks_per_second), "実験場は本番と同じ物理更新の刻み")
	var data_before := JSON.stringify(SaveManager.data)
	var config_before := ContentManager.cfg.enemy_hp_mult
	await lab.reset({"seed": 932, "empty": true, "stage": 4})
	check(lab.run.state.stage.boss_id == &"hydra", "実験の基準はステージ4のヒュドラ")
	check(lab.run.state.phase == RunIds.Phase.Play, "カード選択なしで実験できる")
	check(lab.run.cfg != ContentManager.cfg, "設定を実験ごとに複製する")
	lab.perform("spawn", {"type": "missile", "pos": [200, 0], "count": 3})
	check(lab.run.enemies.count() == 3, "好きな敵を複数出せる")
	for n in 120:
		lab.step()
	check(is_equal_approx(lab.run.state.time, 1.0), "120回の更新で1秒進む")
	var track = load("res://gyms/enemy_lab/lab_timeline.gd").new()
	track.session = lab
	check(is_equal_approx(track.visible_span() * lab.DT, 10.0), "タイムラインの表示幅は10秒を保つ")
	track.free()
	var digest: String = lab.digest()
	check(not digest.is_empty(), "比較用の戦闘状態を取得できる")
	await lab.seek(0)
	check(lab.tick == 0, "開始へ巻き戻す")
	for checkpoint in lab.checkpoints: checkpoint.scene.queue_free()
	lab.checkpoints.clear()
	await lab.seek(120)
	check(lab.digest() == digest, "同じ時刻へ戻ると戦闘状態が一致する")
	check(JSON.stringify(SaveManager.data) == data_before and ContentManager.cfg.enemy_hp_mult == config_before, "実験でセーブと本番設定を変えない")
	await lab.reset({"seed": 932, "empty": true})
	check(lab.run.enemies.count() == 0, "実験を空の状態へ戻せる")
	await lab.reset({"seed": 801, "empty": true, "stage": 4})
	lab.perform("boss", {"type": "hydra", "pos": [400, 0]})
	for n in 150:
		lab.step()
	var boss_digest: String = lab.digest()
	await lab.seek(0)
	for checkpoint in lab.checkpoints: checkpoint.scene.queue_free()
	lab.checkpoints.clear()
	await lab.seek(150)
	check(lab.digest() == boss_digest, "うみへびの首と乱数も巻き戻して再現できる")
	await lab.seek(60)
	lab.perform("spawn", {"type": "rocket", "pos": [-300, 0]})
	check(lab.branches.size() == 1 and lab.furthest == 60, "過去を編集すると元の履歴を残して分岐する")
	lab.queue_free()
	await get_tree().process_frame
	print("[lab_core] passed=%d failed=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)

func cpp_lab_operation_ui() -> void:
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = Vector2i(1920,1080)
	var lab = load("res://gyms/enemy_lab/enemy_lab.tscn").instantiate()
	add_child(lab)
	for i in 1200:
		if lab.session!=null and lab.session.run!=null: break
		await get_tree().process_frame
	var paint_display := "--cpp-lab-paint-display" in OS.get_cmdline_user_args()
	var appearance_only := "--cpp-lab-appearance-only" in OS.get_cmdline_user_args() or paint_display
	var undo_only := "--cpp-lab-undo-only" in OS.get_cmdline_user_args() or appearance_only
	if not undo_only: check(lab.session.run!=null,"実験場の画面を開始する")
	if lab.session.run==null: lab.free();return
	if not paint_display: check(lab.controls._attack_meter!=null,"ラン生成前に攻撃一覧とメーターまで画面を構築する")
	await get_tree().process_frame
	var button: Control = lab.workspace.palette_buttons.biter
	ui_click(button)
	if not undo_only: check(lab.canvas.mode==1 and lab.canvas.spawn_type=="biter","敵パレットの実クリックで配置する敵を選ぶ")
	var before: int = lab.session.bridge.read_metrics().value.enemies
	ui_click(lab.canvas)
	if not undo_only: check(lab.session.bridge.read_metrics().value.enemies==before+1,"フィールドの実クリックで選んだ敵を置く")
	if appearance_only:
		await lab_appearance_operations(lab)
		lab.free()
		return
	ui_key(KEY_Z,true)
	for i in 1200:
		if not lab.session.seeking: break
		await get_tree().process_frame
	check(lab.session.bridge.read_metrics().value.enemies==before,"Ctrl+Zの実入力で配置を取り消す")
	ui_key(KEY_Z,true,true)
	for i in 1200:
		if not lab.session.seeking: break
		await get_tree().process_frame
	check(lab.session.bridge.read_metrics().value.enemies==before+1,"Ctrl+Shift+Zの実入力で配置を戻す")
	ui_click(lab._play)
	if not undo_only: check(lab.session.playing,"再生ボタンの実クリックで試遊を始める")
	ui_key(KEY_SPACE)
	if not undo_only: check(not lab.session.playing,"Spaceの実入力で試遊を停止する")
	lab.free()

func ui_click(control: Control) -> void:
	var point := control.get_global_transform_with_canvas()*(control.size*0.5)
	ui_click_point(point)

func ui_click_point(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion,true)
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.pressed = down
		get_viewport().push_input(event,true)

func show_control(control: Control) -> void:
	var parent := control.get_parent()
	while parent!=null:
		if parent is ScrollContainer: parent.ensure_control_visible(control)
		parent = parent.get_parent()
	await get_tree().process_frame

func lab_appearance_operations(lab) -> void:
	var display_only := "--cpp-lab-paint-display" in OS.get_cmdline_user_args()
	var controls = lab.controls
	for button in lab.find_children("*","Button",true,false):
		if button.text==tr("lab.appearance.title") and button.is_visible_in_tree():
			ui_click(button)
			break
	await get_tree().process_frame
	if not display_only: check(controls.current_tab==5,"外観タブへ実クリックで切り替える")
	for button in controls.find_children("*","Button",true,false):
		if button.text!=tr("lab.appearance.focus"): continue
		await show_control(button)
		ui_click(button)
		break
	if not display_only: check(lab.canvas.center==lab.session.run.enemies.table.pos[lab.session.selected] and is_finite(lab.canvas.zoom),"拡大ボタンの実クリックで選んだ敵に表示を合わせる")
	var armor: Control = controls._armor_view
	await show_control(armor)
	var colors: Dictionary = lab.session.run.enemies.def_of(&"biter").armor_colors.duplicate(true)
	var rect: Rect2 = armor._image_rect()
	var pixel: int = armor.data.regions.values()[0][0]
	var local: Vector2 = rect.position+(Vector2(pixel%int(armor.data.width),pixel/int(armor.data.width))+Vector2.ONE*0.5)*rect.size/armor.source.get_size()
	var presentation: RunPresentation = controls._render()
	var previous_scope := presentation.cpp_scope
	var builder = load("res://tools/content/build_run_content.gd")
	var builds: int = builder.preparation_build_count
	var index_path: String = lab.session._output.path_join("stage_%d.json" % lab.session._source.index)
	var index_hash := FileAccess.get_sha256(index_path)
	ui_click_point(armor.get_global_transform_with_canvas()*local)
	check(builder.preparation_build_count==builds and FileAccess.get_sha256(index_path)==index_hash,"装甲を塗っても戦闘データの生成・書込を行わない")
	var painted: Dictionary = lab.session.run.enemies.def_of(&"biter").armor_colors.duplicate(true)
	if not display_only: check(lab.session.run.enemies.def_of(&"biter").armor_colors!=colors,"装甲片の実クリックでその片だけ塗り替える")
	if not display_only: check(presentation.cpp_scope!=previous_scope,"塗り替えた表示資源を現在のランへ渡す")
	await get_tree().process_frame
	var view = presentation.frame_view
	check(not view.enemy_frames.is_empty(),"塗り替えた敵の描画実体がある")
	if not view.enemy_frames.is_empty():
		var id: int = view.enemy_frames.keys()[0]
		var entry: Dictionary = view.visuals[id]
		var look: EnemyLook = presentation.cpp_scope.resources[entry.path]
		var display = view.enemy_frames[id]
		var material: ShaderMaterial = display._parts[0].armor.material
		check(material.get_shader_parameter("paint_tex")==look.painted_armors[entry.paint],"実クリックで塗った色を描画中の材質へ反映する")
	ui_key(KEY_Z,true)
	if not display_only: check(lab.session.run.enemies.def_of(&"biter").armor_colors==colors,"装甲の塗り替えを実キー操作で取り消す")
	await lab.session.redo_edit()
	check(lab.session.run.enemies.def_of(&"biter").armor_colors==painted,"やり直しで未保存の配色を復元する")
	await lab.session.reset({"overrides":{"biter":{"armor_colors":painted}}})
	var restored: RunPresentation = lab.session.scene.view.get_node("RunPresentation")
	for entry: Dictionary in lab.session.scene.cpp_resources.visuals:
		if entry.role!=6: continue
		var look: EnemyLook = restored.cpp_scope.resources[entry.path]
		check(look.painted_armors.has(entry.paint),"未保存の配色を含むリセットでも描画前に塗装画像が揃う")


func ui_key(code: Key, ctrl := false, shift := false) -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		event.ctrl_pressed = ctrl and OS.get_name()!="macOS"
		event.meta_pressed = ctrl and OS.get_name()=="macOS"
		event.shift_pressed = shift
		get_viewport().push_input(event,true)

func cpp_lab_actions() -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"empty":true,"field":{"terrain":false,"rocks":true},"config":{"meteor_count":1,"iron_count":0,"saw_count":0},"director":{"enabled":true,"budget":2.0,"jitter":0.0}})
	check(lab.run!=null and lab.last_error.get("ok",false),"個別操作の確認用ランを開始する")
	if lab.run==null: lab.queue_free(); return
	var core = lab.bridge._core
	check(lab.run.projectiles.director.enabled and lab.run.projectiles.director.settings.budget==2.0,"保存した攻撃予算を開始時に適用する")
	check(lab.bridge.command("dev_field_query",{"action":"snapshot"}).value.bodies.is_empty() and not lab.bridge.command("dev_field_query",{"action":"rocks"}).value.is_empty(),"地形なし・岩ありを独立して指定できる")
	check(lab.perform("spawn",{"type":"iron","pos":[1700,800],"angle":0.6}),"手動の岩を配置する")
	var rock_id: int = lab.run.enemies.table.id[lab.selected]
	check(lab.bridge.command("dev_field_query",{"action":"rocks"}).value.any(func(rock): return rock.enemy_id==rock_id and rock.manual),"手動の岩と敵の参照を同じ操作で作る")
	check(lab.events.any(func(event): return event.type==&"lab_spawn" and event.enemy_type==&"iron"),"手動配置をタイムラインの出現通知へ渡す")
	check(lab.perform("move",{"id":rock_id,"pos":[1800,900]}) and is_equal_approx(lab.run.enemies.table.facing[lab.selected],0.6),"ドラッグで向きを省略したら元の向きを保つ")
	check(lab.bridge.command("dev_field_query",{"action":"rocks"}).value.any(func(rock): return rock.enemy_id==rock_id and rock.position==Vector2(1800,900)),"岩を移動した位置をフィールド側にも反映する")
	check(lab.perform("spawn",{"type":"missile","pos":[500,500],"angle":0.25}),"移動確認用の敵を配置する")
	var parent: int = lab.run.enemies.table.id[lab.selected]
	var part: Dictionary = lab.bridge.command("dev_spawn_part",{"parent_id":parent,"definition_id":"hydra_bite","position":Vector2(550,500)})
	check(part.ok,"移動確認用の部位を親に付ける")
	var child: int = int(part.value) if part.ok else -1
	var attack: Dictionary = lab.bridge.command("dev_emit_attack",{"pool":2,"position":Vector2(560,500),"owner_id":child,"attached":true,"life":10.0,"radius":2.0}) if part.ok else {"ok":false}
	check(attack.ok,"部位に付いた攻撃を作る")
	var before: Dictionary = core.enemy_motion_snapshot().filter(func(row): return row.id==parent)[0]
	check(lab.perform("move",{"id":parent,"pos":[700,500],"angle":0.25+PI/2}),"攻撃を止めずに親を回転して動かす")
	var after: Dictionary = core.enemy_motion_snapshot().filter(func(row): return row.id==parent)[0]
	check(before.fire_t==after.fire_t and before.age==after.age,"移動編集で攻撃と個体の時計を変えない")
	if part.ok:
		check(lab.run.enemies.table.pos[lab.row_for_id(child)].is_equal_approx(Vector2(700,550)),"子の相対位置を親と一緒に回す")
	if attack.ok:
		check(core.hazards_snapshot().any(func(hazard): return hazard.pos.is_equal_approx(Vector2(700,560))),"付属した攻撃を消さず同じ相対位置へ動かす")
	check(lab.perform("parameter",{"type":"missile","key":"attack_weight","value":0}) and core.enemy_attack_snapshot().any(func(row): return row.id==parent and not row.managed),"攻撃の重さ0を配置済みの個体にも適用する")
	check(lab.perform("config",{"key":"draw_time_scale","value":2.0}) and lab.run.cfg.draw_time_scale==1.0,"描いている間の速度の上限を維持する")
	check(lab.perform("config",{"key":"base_attack","value":0.0}) and lab.run.cfg.base_attack==0.01,"通常設定の正の下限を維持する")
	check(lab.perform("post_max",{"stacks":{"max_speed":2}}) and lab.perform("loadout",{"reset":true}) and lab.run.state.post_max_stacks.is_empty(),"装備リセットで最大強化も消す")
	check(lab.perform("command",{"name":"debug_time","args":{}}) and lab.run.state.time==30.0,"保存済みの旧時刻命令と既定の30秒を読み替える")
	check(lab.perform("command",{"name":"debug_grant","args":{"id":"W01"}}) and lab.run.state.weapons.has(&"W01"),"保存済みの旧装備命令を読み替える")
	check(lab.perform("command",{"name":"debug_reset_loadout"}) and lab.run.state.weapons.is_empty(),"旧装備リセット命令を同じ正式操作へ渡す")
	check(lab.perform("boss",{"type":"monoceros","pos":[1500,500]}),"削除確認用のボスを配置する")
	var boss: int = lab.run.enemies.table.id[lab.selected]
	check(lab.perform("edit_range",{"id":boss,"key":"approach_range","length":880.0,"angle":0.4}) and lab.definition_for_row(lab.row_for_id(boss)).params.approach_range==880.0,"ボスの射程編集もボス定義へ渡す")
	check(lab.perform("delete",{"id":boss}),"停止したままボスを削除する")
	var held: Dictionary = lab.bridge.checkpoint()
	check(held.ok,"ボス削除直後も保持点の参照が整合する")
	if held.ok: lab.bridge.release_checkpoint(held.value)
	var digest: String = lab.digest()
	check(lab.perform("schedule",{"entries":[{"type":"monoceros","pos":[1800,500],"start":0,"end":0,"count":2}]}),"ボスの予定配置を受け付ける")
	check(lab.digest()!=digest,"同じtickの予定変更でも古い候補の比較値を更新する")
	lab.step()
	var bodies: Array = lab.bridge.command("dev_boss_body_state",{}).value
	check(bodies.filter(func(body): return body.actor>0).size()==2 and lab.run.enemies.table.is_boss.count(1)==2,"予定配置のボスも本体とAIを持つ")
	check(lab.perform("clear") and lab.run.enemies.count()==0,"一括削除で通常敵・部位・ボスを消す")
	held = lab.bridge.checkpoint()
	check(held.ok,"一括削除直後も保持点の参照が整合する")
	if held.ok: lab.bridge.release_checkpoint(held.value)
	check(lab.bridge.read_frame().ok and lab.bridge.collect_frame().ok and lab.bridge.delivery_error.get("ok",false),"追加した出現通知も正式な配信形式で届ける")
	lab.queue_free()
	await get_tree().process_frame

func cpp_definition_edits() -> bool:
	var builder = load("res://tools/content/build_run_content.gd")
	var schema = load("res://tools/content/generated/run_schema.gd")
	var definition: EnemyDef = ContentManager.enemies[&"splitling"].duplicate(true)
	definition.armor = 0.0
	definition.speed = 0.0
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.moon_count = 0
	config.meteor_count = 0
	config.iron_count = 0
	config.saw_count = 0
	var records: Dictionary = builder.chase_records(definition,config)
	var original: PackedByteArray = schema.write_content(records,"定義編集の確認".sha256_text().hex_decode())
	var first = load("res://scripts/runtime/run_bridge.gd").new()
	var second = load("res://scripts/runtime/run_bridge.gd").new()
	for bridge in [first,second]:
		if not bridge.configure(original,{"api_version":1,"run_id":1 if bridge==first else 2,"mode":1,"stage_id":"編集確認","profile":{},"settings":{}}).ok or not bridge.start(832,{}).ok: return false
		bridge.subscribe("編集確認",func(_frame: Dictionary) -> bool: return true)
		if not bridge.command("dev_remove_weapon",{"id":"W01"}).ok: return false
		if not bridge.command("dev_spawn",{"definition_id":"splitling","position":Vector2(-500,300)}).ok: return false
	var id: int = first._core.enemies_snapshot()[0].id
	if not first.command("dev_damage",{"entity_id":id,"amount":1.0,"cause":"shot","no_crit":true}).ok: return false
	if not first.step(1.0/120.0,first.pack_intent(Intent.new()),{"logical_size":Vector2(1280,720)}).ok: return false
	var before: Dictionary = first._core.enemies_snapshot()[0]
	var tick: int = first.read_frame().value.tick
	var held: Dictionary = first.checkpoint()
	if not held.ok: return false
	definition.stage_hp = definition.base_hp(config)*2.0
	definition.armor = 7.0
	definition.speed = 20.0
	var changed: PackedByteArray = schema.write_content(builder.chase_records(definition,config),"定義編集の確認".sha256_text().hex_decode())
	var edited: Dictionary = first.replace_definition("splitling",changed)
	check(edited.ok,"検証済みの定義を停止境界で原子的に編集する")
	var after: Dictionary = first._core.enemies_snapshot()[0]
	check(after.id==id and after.max_hp>before.max_hp and is_equal_approx(after.hp/after.max_hp,before.hp/before.max_hp),"生存個体のIDとHP割合を保つ")
	check(after.armor>0.0 and after.speed==20.0,"旧値0から装甲と速度を再計算する")
	check(first.read_frame().value.tick==tick and second._core.enemies_snapshot()[0].armor==0.0,"編集は現在tickと別ランを変えない")
	var failed_edit: Dictionary = first.replace_definition("splitling",PackedByteArray([1,2,3]))
	check(not failed_edit.ok and first._core.enemies_snapshot()[0]==after,"不正な定義は個体を部分変更しない")
	check(first.replace_definition("splitling",original).ok and first.read_frame().value.tick==tick,"逆命令も現在tickで適用する")
	check(first.restore(held.value).ok and first._core.enemies_snapshot()[0]==before,"編集後も保持した旧ContentBundleと個体へ戻る")
	first.release_checkpoint(held.value)
	for bridge in [first,second]:
		check(bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.get("ok",false),"編集後の読取・回収・通知配信が成功する")
		bridge.dispose()
	return true

func cpp_lab() -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	var data_before := JSON.stringify(SaveManager.data)
	await lab.reset({"seed":932,"empty":true,"stage":4})
	check(lab.bridge!=null and lab.scene.runtime_kind=="cpp" and lab.run!=null,"実験場は旧RunSimulationを作らずC++Sessionを使う")
	if lab.run==null: lab.queue_free(); return
	check(lab.last_error.get("ok",false),"開始設定が成功する: "+str(lab.last_error))
	if not lab.last_error.get("ok",false): lab.queue_free(); return
	check(lab.run.state.stage.boss_id==&"hydra" and lab.run.state.phase==RunIds.Phase.Play,"元のステージとカード待ちのない入口を保つ")
	check(lab.perform("spawn",{"type":"missile","pos":[200,0],"count":3}) and lab.run.enemies.count()==3,"手動配置は通常の生成サービスへ接続する")
	var id: int = lab.run.enemies.table.id[lab.selected]
	check(lab.perform("move",{"id":id,"pos":[300,50],"angle":0.25}) and lab.run.enemies.table.pos[lab.selected]==Vector2(300,50),"論理IDで選択と移動を行う")
	check(lab.perform("pin",{"value":true,"pos":[-600,0]}),"機体固定を正式命令で設定する")
	for n in 120: lab.step()
	check(is_equal_approx(lab.run.state.time,1.0) and lab.run.state.ship_pos==Vector2(-600,0),"120Hzで進めながら機体だけを固定する")
	check(lab.bridge.read_frame().ok and lab.bridge.collect_frame().ok and lab.bridge.delivery_error.get("ok",false),"更新・読取・回収・通知配信が成功する")
	check(lab.perform("delete",{"id":id}) and lab.row_for_id(id)<0,"削除後の選択に再利用した行を混ぜない")
	var digest: String = lab.digest()
	await lab.seek(0)
	for checkpoint in lab.checkpoints: checkpoint.scene.queue_free()
	lab.checkpoints.clear()
	await lab.seek(120)
	check(lab.digest()==digest,"同じ入力と手動配置を固定tickで再現する")
	check(JSON.stringify(SaveManager.data)==data_before,"実験で共有セーブを変えない")
	await lab.reset({"empty":true})
	check(lab.run.enemies.count()==0,"Resetで開始状態へ戻る")
	check(lab.perform("schedule",{"entries":[{"type":"splitling","pos":[500,500],"start":0,"end":0,"interval":1}]}),"予定配置をC++へ渡す")
	lab.step()
	check(lab.run.enemies.count()==1,"予定配置をC++の時計と乱数で実行する")
	print("[cpp_lab_core] 未実施: うみへびの首を含む再生（該当種類の移行待ち）")
	lab.queue_free()
	await get_tree().process_frame

func cpp_lab_history() -> void:
	var script := load("res://gyms/enemy_lab/lab_session.gd")
	var first = script.new()
	var second = script.new()
	add_child(first)
	add_child(second)
	for lab in [first,second]:
		await lab.reset({"empty":true,"overrides":{"splitling":{"armor":0.0,"speed":0.0}}})
		check(lab.perform("spawn",{"type":"splitling","pos":[500,300]}),"編集確認の個体を正式入口で配置する")
	for n in 24: first.step()
	var before: Dictionary = first.bridge.read_lab().value.enemies[0].duplicate(true)
	var id: int = before.id
	var tick: int = first.tick
	check(first.perform("parameter",{"type":"splitling","key":"armor","value":7.0}),"Labの現在tickで旧値0の装甲を編集する")
	check(first.run.enemies.table.armor[first.row_for_id(id)]>0.0 and first.tick==tick,"装甲を再算出しIDと現在tickを維持する")
	await first.undo_edit()
	check(first.run.enemies.table.armor[first.row_for_id(id)]==0.0 and first.tick==tick,"値のundoは同じtickの逆命令で戻す")
	await first.redo_edit()
	check(first.run.enemies.table.armor[first.row_for_id(id)]>0.0 and first.tick==tick,"値のredoも同じtickに適用する")
	check(first.perform("parameter",{"type":"splitling","key":"speed","value":20.0}),"Labの旧値0の速度を編集する")
	var after: Dictionary = first.bridge.read_lab().value.enemies[0].duplicate(true)
	check(after.speed==20.0 and after.id==id and is_equal_approx(after.hp/after.max_hp,before.hp/before.max_hp),"速度編集でもIDとHP割合を維持する")
	var count: int = first.history.size()
	check(not first.perform("parameter",{"type":"unknown","key":"speed","value":1.0}) and first.bridge.read_lab().value.enemies[0]==after and first.history.size()==count,"失敗は状態と履歴を部分変更しない")
	check(second.bridge.read_lab().value.enemies[0].speed==0.0 and second.bridge.read_lab().value.enemies[0].armor==0.0,"別Sessionへ編集値を漏らさない")
	check(first.history.slice(-3).all(func(command): return command.tick==tick),"適用した逆命令を同じtickの履歴へ保存する")
	await first.seek(12)
	check(first.perform("time",{"value":3.0}) and first.branches.size()==1 and first.furthest==12,"過去表示中の値編集は履歴を分岐する")
	for lab in [first,second]:
		check(lab.bridge.read_frame().ok and lab.bridge.collect_frame().ok and lab.bridge.delivery_error.get("ok",false),"履歴編集後の読取・回収・通知配信が成功する")
		lab.queue_free()
	await get_tree().process_frame

func cpp_lab_replay() -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"empty":true,"overrides":{"missile":{"speed":0.0}}})
	check(lab.perform("spawn",{"type":"missile","pos":[500,0]}),"攻撃を持つ敵を配置する")
	for n in 48: lab.step()
	var tick: int = lab.tick
	var firing: String = lab.digest()
	check(lab.perform("spawn",{"type":"splitling","pos":[700,400]}),"攻撃中の現在tickで敵を追加する")
	for n in 12: lab.step()
	await lab.undo_edit()
	check(lab.tick==tick+12 and lab.run.enemies.count()==1,"配置の取消は後続入力を保ち現在tickまで再構築する")
	await lab.redo_edit()
	check(lab.tick==tick+12 and lab.run.enemies.count()==2,"再配置も現在tickまで再構築する")
	await lab.seek(tick)
	check(lab.run.enemies.count()==2,"配置時刻の命令を同じ境界で適用する")
	if "--cpp-lab-replay-placement" in OS.get_cmdline_user_args():
		lab.queue_free()
		await get_tree().process_frame
		return
	await lab.reset({"empty":true,"overrides":{"splitling":{"speed":0.0}}})
	lab.perform("spawn",{"type":"splitling","pos":[500,0]})
	for n in 12: lab.step()
	var old_hash: String = lab.bridge.read_recording(true).value.identity.payload_sha256
	var old_epoch: int = lab.bridge.read_frame().value.epoch
	await lab.seek(0)
	for n in 24: lab.step()
	lab.perform("parameter",{"type":"splitling","key":"speed","value":20.0})
	var new_hash: String = lab.bridge.read_recording(true).value.identity.payload_sha256
	await lab.seek(12)
	check(old_hash!=new_hash and lab.bridge.read_recording(true).value.identity.payload_sha256==old_hash and lab.run.enemies.table.speed[0]==0.0,"seekで保持した旧ContentBundleへ戻る")
	check(lab.bridge.read_frame().value.epoch>old_epoch,"復帰は共通保持の新epochへ切り替える")
	for target in [0,24,6,18,3]: await lab.seek(target)
	check(lab.checkpoints.size()<=3,"保持するSessionとC++保持点の上限を守る")
	lab.perform("command",{"name":"dev_add_xp","args":{"amount":100.0}})
	lab.step()
	check(lab.run.state.phase==RunIds.Phase.Levelup,"カード待ちを復元対象に含める")
	var card_tick: int = lab.tick
	lab.perform("spawn",{"type":"splitling","pos":[900,500]})
	await lab.undo_edit()
	check(lab.tick==card_tick and lab.run.state.phase==RunIds.Phase.Levelup,"カード待ちでも配置取消のtickと候補待ちを維持する")
	lab.cancel_seek()
	check(not lab.seeking and not lab.playing,"取消後の古いseekを進めない")
	await lab.reset({"empty":true})
	check(lab.tick==0 and lab.checkpoints.is_empty() and lab.edit_undo.is_empty() and lab.edit_redo.is_empty(),"Resetで開始状態とundo/redoと保持点へ戻る")
	check(lab.bridge.read_frame().ok and lab.bridge.collect_frame().ok and lab.bridge.delivery_error.get("ok",false),"再構築の後の読取・回収・通知配信が成功する")
	var ids: Array = RunManager._sessions.keys().duplicate()
	lab.queue_free()
	await get_tree().process_frame
	check(ids.all(func(id): return RunManager.session(id)==null),"画面破棄で現在と保持中の全Sessionを解放する")

func cpp_lab_formations() -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"empty":true})
	var tick: int = lab.tick
	if "--cpp-lab-phase" not in OS.get_cmdline_user_args():
		check(lab.perform("formation",{"path":"res://data/formations/aquila.tscn","layout":0,"entry":0}),"配置シーンを共通生成した値から正式命令で追加する")
		check(lab.run.enemies.count()==1 and lab.run.enemies.table.type[0]==&"aquila" and lab.tick==tick,"配置した敵の種類と現在tickを保つ")
		var definition: String = lab.bridge.read_recording(true).value.identity.payload_sha256
		var before: Dictionary = lab.bridge.read_lab().value
		var history: int = lab.history.size()
		check(not lab.perform("formation",{"path":"res://data/formations/aquila.tscn","layout":1000,"entry":0}),"不正な並びを拒否する")
		check(lab.bridge.read_recording(true).value.identity.payload_sha256==definition and lab.bridge.read_lab().value==before and lab.history.size()==history,"失敗した配置は定義・個体・履歴を部分変更しない")
	else:
		lab.perform("spawn",{"type":"splitling","pos":[500,300]})
	check(lab.tick==tick and lab.run.enemies.count()==1,"配置で時計と配置済みの個体を維持する")
	check(lab.bridge.read_frame().ok and lab.bridge.collect_frame().ok and lab.bridge.delivery_error.get("ok",false),"配置後の読取・回収・通知配信が成功する")
	lab.queue_free()
	await get_tree().process_frame

func cpp_lab_settings() -> void:
	var script := load("res://gyms/enemy_lab/lab_session.gd")
	var first = script.new()
	var second = script.new()
	add_child(first)
	add_child(second)
	await first.reset({"empty":true,"hero":"hercules","meta":{"hp":2,"xp":3,"atk":1}})
	await second.reset({"empty":true})
	check(first.run!=null and first.last_error.get("ok",false),"英雄と永続強化を指定して開始する")
	if first.run==null: return
	check(first.run.state.lab_mode and first.run.state.hero_power==&"hercules" and first.run.state.hero_active_t==0.0,"開始時から実験モードと英雄の正式読取を使う")
	check(first.run.state.meta_override.hp==2 and first.run.state.meta_override.xp==3,"開始設定の永続強化をC++から読み取る")
	var initial: Dictionary = first.bridge.read_lab().value
	check(initial.max_hp==first.run.cfg.base_hp+40.0 and is_equal_approx(initial.attack_power,first.run.cfg.base_attack*1.06),"永続HPと攻撃力を正式な数値へ反映する")
	var held: Dictionary = first.bridge.checkpoint()
	var tick: int = first.tick
	check(first.perform("hero",{"id":"perseus"}) and first.run.state.hero_power==&"perseus","英雄選択を同じtickの正式命令で変更する")
	await first.undo_edit()
	check(first.run.state.hero_power==&"hercules" and first.tick==tick,"英雄の取消を現在tickで適用する")
	check(first.perform("meta",{"id":"hp","level":4}) and first.bridge.read_lab().value.max_hp==first.run.cfg.base_hp+80.0,"永続強化を現在tickへ適用する")
	await first.undo_edit()
	check(first.run.state.meta_override.hp==2 and first.bridge.read_lab().value.max_hp==initial.max_hp and first.tick==tick,"永続強化の取消で数値と読取を戻す")
	check(second.run.state.hero_power==&"" and second.run.state.meta_override.is_empty(),"別Sessionへ試行値を漏らさない")
	var before: Dictionary = first.bridge.read_lab().value
	var history: int = first.history.size()
	check(not first.perform("hero",{"id":"unknown"}) and not first.perform("meta",{"id":"unknown","level":1}) and first.bridge.read_lab().value==before and first.history.size()==history,"不正な選択は状態と履歴を部分変更しない")
	check(first.bridge.restore(held.value).ok and first.bridge.read_lab().value.hero.power=="hercules" and first.bridge.read_lab().value.meta_levels[2]==2,"保持点へ英雄と永続強化を復元する")
	first.bridge.release_checkpoint(held.value)
	for lab in [first,second]: lab.queue_free()
	await get_tree().process_frame

func cpp_lab_boss() -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"empty":true,"boss_overrides":{"monoceros":{"speed":21.0}}})
	check(lab.run!=null and lab.last_error.get("ok",false),"ボス上書きを通常の生成形式へ通して開始する: "+str(lab.last_error))
	if lab.run==null: return
	check(lab.perform("boss",{"type":"monoceros","pos":[700,0]}),"型付き本体とフローからボスを配置する")
	if lab.selected<0: lab.queue_free(); return
	var id: int = lab.run.enemies.table.id[lab.selected]
	var tick: int = lab.tick
	check(lab.run.enemies.table.is_boss[lab.selected] and lab.run.enemies.table.speed[lab.selected]==21.0,"ボスの論理IDと開始時上書きを読み取る")
	check(lab.perform("boss_parameter",{"type":"monoceros","key":"speed","value":42.0}) and lab.run.enemies.table.speed[lab.row_for_id(id)]==42.0 and lab.tick==tick,"生存中のボスも同じtickで定義を置換する")
	await lab.undo_edit()
	check(lab.run.enemies.table.speed[lab.row_for_id(id)]==21.0 and lab.tick==tick,"ボスの値の取消は時計を戻さない")
	var old: Dictionary = lab.run.bosses.definitions[&"monoceros"].part_appearance.duplicate(true)
	check(lab.perform("boss_appearance",{"type":"monoceros","parts":{"body":{"color":"ff8844","offset":[2,3]}}}),"ボス外観を戦闘定義と同じ命令境界へ通す")
	check(lab.scene.cpp_resources.visuals.any(func(entry): return entry.get("boss","")=="monoceros" and entry.appearance.body.color=="ff8844"),"外観はGodotの表示資源へ反映する")
	await lab.undo_edit()
	check(lab.run.bosses.definitions[&"monoceros"].part_appearance==old,"ボス外観の取消で元の版へ戻す")
	var before: Dictionary = lab.bridge.read_lab().value
	var history: int = lab.history.size()
	var signature: String = lab.bridge.read_recording(true).value.identity.payload_sha256
	check(not lab.perform("boss",{"type":"hydra","pos":[0,0]}) and not lab.perform("boss_parameter",{"type":"hydra","key":"speed","value":2.0}),"未移行のボスを別の実装で補完しない")
	check(lab.bridge.read_lab().value==before and lab.history.size()==history and lab.bridge.read_recording(true).value.identity.payload_sha256==signature,"拒否した編集は個体・定義・履歴を部分変更しない")
	check(lab.bridge.read_frame().ok and lab.bridge.collect_frame().ok and lab.bridge.delivery_error.get("ok",false),"ボス編集後の読取と通知配信が成功する")
	lab.queue_free()
	await get_tree().process_frame

## 外観の連続編集は時計・保持済み資源・判定を守り、表示だけなら戦闘生成を呼ばない。
func cpp_lab_appearance_edits() -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"empty":true})
	check(lab.run!=null,"外観編集の検査用ランを開始する")
	if lab.run==null: lab.free(); return
	lab.perform("spawn",{"type":"biter","pos":[800,0]})
	var id: int = lab.run.enemies.table.id[lab.selected]
	lab.perform("spawn",{"type":"splitling","pos":[-800,0]})
	var other: int = lab.run.enemies.table.id[lab.selected]
	for n in 120: lab.step()
	var at: int = lab.tick
	var original_radius: float = lab.run.enemies.table.r[lab.row_for_id(id)] / lab.run.enemies.def_of(&"biter").visual_value("scale",1.0) / lab.run.enemies.def_of(&"biter").visual_value("collision_scale",1.0)
	var other_radius: float = lab.run.enemies.table.r[lab.row_for_id(other)]
	var position: Vector2 = lab.run.enemies.table.pos[lab.row_for_id(id)]
	var held_resources: Resource = lab.scene.cpp_resources
	var held_visuals: Array = held_resources.visuals.duplicate(true)
	var held_enemy: EnemyDef = lab.run.enemies.def_of(&"biter")
	var held_boss: BossDef = lab.run.bosses.definitions[&"monoceros"]
	var boss_parts := held_boss.part_appearance.duplicate(true)
	var signature: String = lab.bridge.read_recording(true).value.identity.payload_sha256
	var builder = load("res://tools/content/build_run_content.gd")
	var builds: int = builder.preparation_build_count
	var index_path: String = lab._output.path_join("stage_%d.json" % lab._source.index)
	var index_hash := FileAccess.get_sha256(index_path)
	for ambient in [0.5,0.7]:
		check(lab.perform("parameter",{"type":"biter","key":"visual.ambient","value":ambient}),"照明を連続変更できる")
	var visual_id: int = lab._source.resources.enemy_ids.find("biter")+6
	var entries: Array = lab.scene.cpp_resources.visuals.filter(func(entry): return entry.id==visual_id)
	check(entries.size()==1 and is_equal_approx(entries[0].settings.ambient,0.7),"照明を現在の表示定義へ反映する")
	check(not is_equal_approx(held_enemy.visual_value("ambient",-1.0),0.7),"保持した敵定義の照明を変更しない")
	check(lab.perform("boss_appearance",{"type":"monoceros","parts":{"body":{"color":"ff8844","offset":[2,3]}}}),"ボスの色と位置を表示専用で変更できる")
	check(lab.scene.cpp_resources.visuals.any(func(entry): return entry.get("boss","")=="monoceros" and entry.appearance.body.color=="ff8844"),"ボスの表示定義へ配色を反映する")
	check(held_boss.part_appearance==boss_parts and held_resources.visuals==held_visuals,"以前の定義と表示資源を変更しない")
	await lab.undo_edit()
	check(lab.run.bosses.definitions[&"monoceros"].part_appearance==boss_parts,"表示専用の編集を取り消せる")
	await lab.redo_edit()
	check(lab.run.bosses.definitions[&"monoceros"].part_appearance.body.color=="ff8844","表示専用の編集をやり直せる")
	check(builder.preparation_build_count==builds and lab.bridge.read_recording(true).value.identity.payload_sha256==signature,"照明・ボス外観の変更と取消で戦闘定義を生成・交換しない")
	var memo_size: int = lab._program_memo.size()
	for factor in [1.1,1.2,1.3]:
		var began := Time.get_ticks_usec()
		check(lab.perform("parameter",{"type":"biter","key":"visual.scale","value":factor}),"サイズを連続変更できる")
		print("[appearance_edit] scale_ms=",(Time.get_ticks_usec()-began)/1000.0)
		check(is_equal_approx(lab.run.enemies.table.r[lab.row_for_id(id)],original_radius*factor),"サイズの変更を当たり判定にも従来どおり反映する")
	check(lab._program_memo.size()==memo_size,"サイズを連続変更しても旧版の生成結果を溜めない")
	await lab.undo_edit()
	check(is_equal_approx(lab.run.enemies.table.r[lab.row_for_id(id)],original_radius*1.2),"サイズの取消で判定を戻す")
	await lab.redo_edit()
	check(lab.perform("parameter",{"type":"biter","key":"visual.collision_scale","value":1.4}),"当たり判定倍率も更新できる")
	check(is_equal_approx(lab.run.enemies.table.r[lab.row_for_id(id)],original_radius*1.3*1.4),"サイズと当たり判定倍率を掛け合わせる")
	check(lab.tick==at and lab.run.enemies.table.pos[lab.row_for_id(id)]==position and is_equal_approx(lab.run.enemies.table.r[lab.row_for_id(other)],other_radius),"連続編集で時計・配置・他の種類の判定を変えない")
	check(lab.perform("config",{"key":"base_attack","value":37.0}) and is_equal_approx(lab.run.cfg.base_attack,37.0),"共通設定の編集は古い生成結果を使わない")
	check(lab.perform("parameter",{"type":"biter","key":"visual.scale","value":1.5}),"共通設定変更後もサイズを変更できる")
	builds = builder.preparation_build_count
	var unchanged_history: int = lab.history.size()
	for command in [["config",{"key":"base_attack","value":37.0}],["parameter",{"type":"biter","key":"visual.scale","value":1.5}]]:
		check(lab.perform(command[0],command[1]),"同じ値の再確定を受け付ける")
	check(builder.preparation_build_count==builds and lab.history.size()==unchanged_history,"同じ値の再確定で生成や取消履歴を増やさない")
	var before: Dictionary = lab.run.enemies.def_of(&"biter").visual_settings.duplicate(true)
	var history: int = lab.history.size()
	check(not lab.perform("parameter",{"type":"biter","key":"visual.scale","value":NAN}) and lab.run.enemies.def_of(&"biter").visual_settings==before and lab.history.size()==history,"不正な外観値を部分変更せず拒否する")
	var fresh := {}
	check(builder.build(lab._source,lab._config,lab._output,"実験場".sha256_text(),lab._definitions,lab._formation_sources,lab._boss_definitions,lab.scene.cpp_resources,lab._boss_programs,PackedStringArray(),false,fresh)==OK,"同じ入力をキャッシュなしでも生成できる")
	if fresh.has("bytes"):
		check(fresh.bytes.slice(56,88).hex_encode()==lab.bridge.read_recording(true).value.identity.payload_sha256,"キャッシュ経路と通常生成の戦闘バイナリが一致する")
		check(fresh.resources.visuals==lab.scene.cpp_resources.visuals,"キャッシュ経路と通常生成の外観が一致する")
	check(FileAccess.get_sha256(index_path)==index_hash,"連続編集では生成済みの起動ファイルを書き換えない")
	lab.free()
