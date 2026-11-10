## かじき座の停止予告・現在位置の固定照準・高速掃引・共通撃破との接続。
extends Node
const RunIds := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS
var failed := 0

func check(ok: bool, label: String) -> void:
	if "--cpp-marlin-tail" in OS.get_cmdline_user_args() and label in ["かじき座の編集値と外観を生成する","かじき座のランと通常表示を準備する","巡航の旋回・加速・軌跡が現行と一致する","停止した現在位置を固定し予告を開始する","画面外から続く停止予告を共通の表示経路へ渡す"]: return
	if not ok:
		failed += 1
		push_error(label)

func _ready() -> void:
	await check_cpp_marlin()
	print("[marlin] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)

func cpp_motion(core, id: int) -> Dictionary:
	for item: Dictionary in core.enemy_motion_snapshot():
		if item.id==id: return item
	return {}

func cpp_enemy(core, id: int) -> Dictionary:
	for item: Dictionary in core.enemies_snapshot():
		if item.id==id: return item
	return {}

func check_cpp_marlin() -> void:
	var cfg: GameConfig = ContentManager.base.duplicate(true)
	cfg.start_radius = 900.0
	cfg.planet_radius = 0.0
	for key in ["moon_count","meteor_count","iron_count","saw_count"]: cfg.set(key,0)
	var stage := RuntimeStage.new()
	stage.index = 80
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["marlin","splitling","hydra_bite"])
	stage.enemy_tuning = {"splitling":{"speed":0.0}}
	var output := "res://.content/dev/run_marlin"
	var built: Error = preload("res://tools/content/build_run_content.gd").build(stage,cfg,output,"かじき座の巡航と通過時命中".sha256_text())
	check(built==OK,"かじき座の編集値と外観を生成する")
	if built!=OK: return
	var path := output.path_join("stage_80.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":981},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"かじき座のランと通常表示を準備する")
	if session.bridge==null:
		session.free()
		return
	var bridge = session.bridge
	var core = bridge._core
	bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	var target: Vector2 = core.ship_snapshot().ship_pos
	core.set_motion_context(target,target,Vector2(640,360))
	var position := target-Vector2(560,0)
	var id: int = core.spawn_enemy(&"marlin",position,{"vel":Vector2(200,300)})
	core.set_enemy_motion(id,{"fire_t":3.0})
	for tick in 5:
		core.step(0.05)
	position = Vector2(cpp_enemy(core,id).pos[0],cpp_enemy(core,id).pos[1])
	target = position+Vector2(600,0)
	core.set_motion_context(target,target,Vector2(640,360))
	core.set_enemy_motion(id,{"fire_t":0.85})
	core.step(0.1)
	check(cpp_motion(core,id).mode==RunIds.EnemyModeId.Windup and cpp_motion(core,id).anchor==target and cpp_motion(core,id).charge==0.01,"停止した現在位置を固定し予告を開始する")
	var pending: Dictionary = bridge.checkpoint()
	var pending_motion: Array = core.enemy_motion_snapshot()
	var frame: Dictionary = bridge.read_render(Rect2(position-Vector2(100,300),Vector2(1400,600))).value
	var presentation: RunPresentation = session.view.get_node("RunPresentation")
	check(frame.marlin.ids.size()==1 and frame.marlin.values.size()==14 and presentation.frame_view.apply_frame(frame),"画面外から続く停止予告を共通の表示経路へ渡す")
	await get_tree().process_frame
	var victims: Array[int] = []
	for x in [100,400,900]: victims.append(core.spawn_enemy(&"splitling",position+Vector2(x,0),{}))
	var outside: int = core.spawn_enemy(&"splitling",position+Vector2(400,150),{})
	var guarded: int = core.spawn_enemy(&"splitling",position+Vector2(600,0),{"guard":8.0})
	var parent: int = core.spawn_enemy(&"splitling",position+Vector2(800,200),{"is_boss":true})
	var part: int = bridge.command("dev_spawn_part",{"parent_id":parent,"definition_id":"hydra_bite","position":position+Vector2(700,0)}).value
	core.set_motion_context(target+Vector2(0,800),target,Vector2(640,360))
	for tick in 9:
		core.step(0.1)
		if cpp_motion(core,id).mode==RunIds.EnemyModeId.Dash: break
	check(cpp_motion(core,id).mode==RunIds.EnemyModeId.Dash and absf(cpp_enemy(core,id).facing)<0.001,"発進後も停止時の方向を固定する")
	frame = bridge.read_render(Rect2(position-Vector2(100,300),Vector2(1400,600))).value
	check(presentation.frame_view.apply_frame(frame),"突進の筋を同じシェーダーと通常画面へ表示する")
	await get_tree().process_frame
	core.step(0.9)
	for victim_id in victims: check(cpp_enemy(core,victim_id).dead,"高速移動の区間にいた敵を共通の撃破処理へ渡す")
	check(not cpp_enemy(core,outside).dead and not cpp_enemy(core,guarded).dead and not cpp_enemy(core,parent).dead and not cpp_enemy(core,part).dead,"進路外・保護中・ボス・ボス部位を破壊しない")
	var end := cpp_enemy(core,id)
	check(absf(Vector2(end.pos[0],end.pos[1]).distance_to(position)-1170.0)<0.03,"更新の余り時間で突進距離を伸ばさない")
	core.step(0.1)
	check(cpp_motion(core,id).mode==RunIds.EnemyModeId.Recover and cpp_motion(core,id).charge==0.0,"突進終了時に静止して休む")
	core.step(1.4)
	check(cpp_motion(core,id).mode==RunIds.EnemyModeId.Move and Vector2(cpp_enemy(core,id).vel[0],cpp_enemy(core,id).vel[1])==Vector2.ZERO,"休み終了で巡航へ戻る")
	check(bridge.restore(pending.value).ok and core.enemy_motion_snapshot()==pending_motion,"固定照準・予告の時計を値から復帰する")
	core.step(0.1)
	var next: Array = core.enemy_motion_snapshot()
	bridge.restore(pending.value)
	core.step(0.1)
	check(core.enemy_motion_snapshot()==next,"復帰後の更新が一致し保持元へ変更を漏らさない")
	bridge.restore(pending.value)
	bridge.command("dev_kill",{"entity_id":id,"cause":"bullet"})
	core.step(1.0)
	check(cpp_enemy(core,id).dead and cpp_motion(core,id).mode!=RunIds.EnemyModeId.Dash,"途中撃破で新しい突進を始めない")
	core.remove_enemy(id)
	var replacement: int = core.spawn_enemy(&"marlin",position,{})
	check(replacement!=id and cpp_motion(core,replacement).anchor==Vector2.ZERO and cpp_motion(core,replacement).charge==0.0,"行の再利用で固定照準・溜めを引き継がない")
	var owner: int = core.spawn_enemy(&"splitling",target,{})
	core.set_enemy_motion(replacement,{"pump_owner":owner,"fire_t":0.8})
	core.remove_enemy(owner)
	core.step(0.1)
	check(cpp_motion(core,replacement).mode==RunIds.EnemyModeId.Windup,"参照相手が先に消えても古い行を参照せず予告へ進む")
	bridge.release_checkpoint(pending.value)
	session.free()
