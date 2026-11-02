extends Node

var passed := 0
var failed := 0

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("[lab_core] " + label)

func _ready() -> void:
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
	check(lab.run.state.phase == RunState.Phase.PLAY, "カード選択なしで実験できる")
	check(lab.run.cfg != ContentManager.cfg, "設定を実験ごとに複製する")
	lab.perform("spawn", {"type": "gunner", "pos": [200, 0], "count": 3})
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

func cpp_definition_edits() -> bool:
	var builder = load("res://tools/content/build_run_content.gd")
	var schema = load("res://tools/content/generated/run_schema.gd")
	var definition: EnemyDef = ContentManager.enemies[&"drifter"].duplicate(true)
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
		if not bridge.command("dev_spawn",{"definition_id":"drifter","position":Vector2(-500,300)}).ok: return false
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
	var edited: Dictionary = first.replace_definition("drifter",changed)
	check(edited.ok,"検証済みの定義を停止境界で原子的に編集する")
	var after: Dictionary = first._core.enemies_snapshot()[0]
	check(after.id==id and after.max_hp>before.max_hp and is_equal_approx(after.hp/after.max_hp,before.hp/before.max_hp),"生存個体のIDとHP割合を保つ")
	check(after.armor>0.0 and after.speed==20.0,"旧値0から装甲と速度を再計算する")
	check(first.read_frame().value.tick==tick and second._core.enemies_snapshot()[0].armor==0.0,"編集は現在tickと別ランを変えない")
	var failed_edit: Dictionary = first.replace_definition("drifter",PackedByteArray([1,2,3]))
	check(not failed_edit.ok and first._core.enemies_snapshot()[0]==after,"不正な定義は個体を部分変更しない")
	check(first.replace_definition("drifter",original).ok and first.read_frame().value.tick==tick,"逆命令も現在tickで適用する")
	check(first.restore(held.value).ok and first._core.enemies_snapshot()[0]==before,"編集後も保持した旧ContentBundleと個体へ戻る")
	first.release_checkpoint(held.value)
	for bridge in [first,second]:
		check(bridge.read_frame().ok and bridge.collect_frame().ok and bridge.delivery_error.get("ok",false),"編集後の読取・回収・通知配信が成功する")
		bridge.dispose()
	return true
