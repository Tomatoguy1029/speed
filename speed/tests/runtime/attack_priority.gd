## 攻撃優先度・予算予約・照準の開始条件と取消の対象チェック。
extends Node
const RunIds := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS
var failed := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed += 1
		push_error(message)
func _ready() -> void:
	await check_cpp_sniper()
	print("[attack_priority] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)

func check_cpp_sniper() -> void:
	var cfg: GameConfig = ContentManager.base.duplicate(true)
	cfg.start_radius = 900.0
	cfg.planet_radius = 0.0
	for key in ["moon_count","meteor_count","iron_count","saw_count"]: cfg.set(key,0)
	var stage := RuntimeStage.new()
	stage.index = 80
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["telescope"])
	var output := "res://.content/dev/run_sniper"
	var built: Error = preload("res://tools/content/build_run_content.gd").build(stage,cfg,output,"ぼうえんきょう座の遮蔽と照準".sha256_text())
	check(built==OK,"ぼうえんきょう座の編集値と外観を生成する")
	if built!=OK: return
	var path := output.path_join("stage_80.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":981},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	check(session.bridge!=null,"ぼうえんきょう座のランと表示を準備する")
	if session.bridge==null:
		session.free()
		return
	var bridge = session.bridge
	var core = bridge._core
	bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":Vector2(640,480)})
	var target: Vector2 = core.ship_snapshot().ship_pos
	core.set_motion_context(target,target,Vector2(640,360))
	var position := target-Vector2(560,0)
	var id: int = core.spawn_enemy(&"telescope",position,{})
	core.set_attack_formation_mode(true)
	core.configure_attack_budget({"enabled":true,"budget":0.0,"jitter":0.0})
	var rock_id := 0
	var pending: Dictionary = {}
	var pending_motion: Array = []
	var next_motion: Array = []
	var fired := false
	for tick in 30:
		if tick==1:
			core.configure_attack_budget({"enabled":true,"budget":1.0,"jitter":0.0})
		if tick==4:
			var tracked_enemy: Dictionary = core.enemies_snapshot().filter(func(value): return value.id==id)[0]
			var at := Vector2(tracked_enemy.pos[0],tracked_enemy.pos[1]).lerp(target,0.5)
			check(bridge.command("dev_add_rock",{"position":at,"kind":0,"manual":true}).ok,"光を遮る岩を生成する")
			bridge.command("dev_stream_rocks",{"center":target,"half":Vector2(640,360),"dt":0.3})
			var rock: Dictionary = {}
			for enemy: Dictionary in core.enemies_snapshot():
				if enemy.type=="meteor": rock = enemy
			rock_id = int(rock.id)
		if tick==6:
			bridge.command("dev_kill",{"entity_id":rock_id,"cause":"bullet"})
		core.advance_attack_budget(float(core.inspect().world_time)+0.1)
		core.step(0.1)
		var motion: Dictionary = core.enemy_motion_snapshot().filter(func(item): return item.id==id)[0]
		if tick==0: check(motion.charge==0.0 and core.attack_budget_snapshot().groups.is_empty(),"予算0では照準の進行と表示を始めない")
		if tick==4: check(motion.charge==0.0 and core.enemy_motion_snapshot()[0].charge==0.0,"岩陰で照準と未発射の予約を取り消す")
		if motion.mode==RunIds.EnemyModeId.Windup and pending.is_empty():
			pending = bridge.checkpoint()
			pending_motion = core.enemy_motion_snapshot()
			var frame: Dictionary = bridge.read_render(Rect2(target-Vector2(1100,500),Vector2(1600,1000))).value
			var shown := false
			for batch: Dictionary in frame.batches:
				if batch.has("sniper"): shown = batch.sniper.size()==59
			var presentation: RunPresentation = session.view.get_node("RunPresentation")
			check(shown and presentation.frame_view.apply_frame(frame),"狭まる48光線と溜めの光を通常画面へ表示する")
			presentation._present_cpp(0.0)
			await get_tree().process_frame
		elif not pending.is_empty() and next_motion.is_empty(): next_motion = core.enemy_motion_snapshot()
		if not core.hazards_snapshot().is_empty():
			fired = true
			check(core.hazards_snapshot().size()==1 and motion.mode==RunIds.EnemyModeId.Recover,"遮蔽が先に消えると再照準しレーザーを撃つ")
			break
	check(fired and not pending.is_empty(),"照準から独立したレーザーの発射まで進む")
	if fired:
		check(bridge.command("dev_kill",{"entity_id":id,"cause":"bullet"}).value.killed and core.hazards_snapshot().size()==1,"発射後に本体を倒しても独立したレーザーは残る")
		core.step_hazards(0.06)
		var frame: Dictionary = bridge.read_render(Rect2(target-Vector2(1100,500),Vector2(1600,1000))).value
		var rounded := false
		for shape: Dictionary in frame.shapes: rounded = rounded or shape.get("rounded",false)
		check(rounded,"レーザーの丸い先端と短い終了フェードを表示する")
		core.step_hazards(0.3)
		check(core.hazards_snapshot().is_empty(),"レーザーを自然寿命で終了する")
		check(bridge.restore(pending.value).ok and core.enemy_motion_snapshot()==pending_motion,"照準の48光線と溜めを値から復帰する")
		core.step(0.1)
		check(core.enemy_motion_snapshot()==next_motion,"復帰後に同じ照準へ進み保持元へ変更を漏らさない")
		bridge.restore(pending.value)
		bridge.command("dev_kill",{"entity_id":id,"cause":"bullet"})
		core.step(0.6)
		check(core.hazards_snapshot().is_empty(),"溜めの途中で倒した本体はレーザーを撃たない")
		core.remove_enemy(id)
		var replacement: int = core.spawn_enemy(&"telescope",position,{})
		var clean := false
		for item: Dictionary in core.enemy_motion_snapshot():
			if item.id==replacement: clean = item.sight_rays.is_empty() and item.charge==0.0 and item.mode==RunIds.EnemyModeId.Move
		check(replacement!=id and clean and not core.set_enemy_motion(id,{"held":true}),"行の再利用で古い照準・ID・光線を引き継がない")
		bridge.release_checkpoint(pending.value)
	session.free()
