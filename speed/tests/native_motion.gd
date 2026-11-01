## 地形のない固定条件で、追跡の出現・LOD移動・個体再利用を本番処理と照合する。
extends Node
const COMPARE := preload("res://tools/compare_runtime.gd")
const DATA := preload("res://tools/content/build_native_data.gd")
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	if "--policy-only" in OS.get_cmdline_user_args():
		check(check_tracking_policy(),"追跡・噛みつきの操舵を最後まで確認する")
		print("[run_motion] failed=%d" % failed)
		get_tree().quit(1 if failed else 0)
		return
	var comparison = COMPARE.new()
	var core = comparison.create_native()
	if core == null or not core.has_method("enemy_order_snapshot"):
		check(false, "ネイティブ側が敵の出現と移動を所有する")
	else:
		var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
		add_child(lab)
		await lab.reset({"seed": 932, "empty": true})
		var run: RunSimulation = lab.run
		var definition := run.enemies.def_of(&"drifter")
		var data := DATA.compile_enemy(definition, run.cfg)
		var shield: EnemyDef = run.enemies.def_of(&"shield")
		data.enemies.append_array(DATA.compile_enemy(shield, run.cfg).enemies)
		check(core.configure(data), "追跡敵と盾を生成データから準備する")
		check(core.configure_enemy_order(PackedStringArray(["chase"])), "初期化済みの行動の並びを渡す")
		check(not core.configure_enemy_order(PackedStringArray(["shield", "shield"])), "重複した登録順で準備を上書きしない")
		run.state.rng.seed = 932
		check(core.start(932, run.enemies._next_id), "同じ乱数と開始IDを使う")
		check(core.set_motion_context(run.state.ship_pos, run.state.view_center, run.state.view_half), "追跡先と表示範囲を渡す")
		var early_shield := run.enemies.spawn(shield, Vector2(500,300))
		var early_shield_id: int = core.spawn_enemy(shield.id, Vector2(500,300))
		var early_chase := run.enemies.spawn(definition, Vector2(600,300))
		var early_chase_id: int = core.spawn_enemy(definition.id, Vector2(600,300))
		check(core.enemy_order_snapshot() == PackedInt64Array([run.enemies.table.id[early_chase],run.enemies.table.id[early_shield]]), "初期登録済みの空の行動を、最初に出た行動より前に保つ")
		run.enemies.mark_dead(early_shield)
		run.enemies.mark_dead(early_chase)
		run.enemies.cleanup()
		core.remove_enemy(early_shield_id)
		core.remove_enemy(early_chase_id)
		for pos in [Vector2(500, 0), Vector2(-500, 100), Vector2(3000, 0), Vector2.ZERO]:
			var row := run.enemies.spawn(definition, pos)
			check(core.spawn_enemy(&"drifter", pos) == run.enemies.table.id[row], "出現したIDが一致する")
		var before: Dictionary = core.inspect()
		check(core.spawn_enemy(&"未対応", Vector2.ZERO) == -1 and core.inspect() == before, "不明な敵でIDや乱数を消費しない")
		for tick in 60:
			if tick in [20, 40]:
				run.state.ship_pos = Vector2(100, -50) if tick == 20 else Vector2(-70, 80)
				core.set_motion_context(run.state.ship_pos, run.state.view_center, run.state.view_half)
			var dt := 1.0 / 60.0
			run.state.world_time += dt
			run.enemies.tick(dt, dt)
			core.step(dt)
			var expected: Dictionary = comparison.snapshot(run, [], tick)
			var difference: String = comparison.difference(expected.enemies, core.enemies_snapshot())
			check(difference.is_empty(), "追跡と画面外の移動が一致する: " + difference)
			check(str(run.state.rng.state) == core.inspect().rng_state, "乱数の消費が一致する")
		if not core.has_method("enemy_buffer"):
			check(false, "ネイティブ状態から表示用の一括データを作れる")
		else:
			var reference := InstanceBatch.new()
			reference.begin()
			var table := run.enemies.table
			var scale := 1.0 / definition.visual_value("collision_scale", 1.0)
			for i in table.alive.size():
				if table.alive[i] != 0:
					reference.add(table.pos[i], table.facing[i] + PI / 2.0, table.r[i] * scale, Color(0, 0, 0, 1))
			var buffer: PackedFloat32Array = core.enemy_buffer(&"drifter", scale, PI / 2.0)
			check(buffer == reference._buf.slice(0, run.enemies.count() * InstanceBatch.STRIDE), "表示用の位置・回転・大きさ・色が本番の一括描画と一致する")
			reference.free()
		var old_id: int = run.enemies.table.id[0]
		run.enemies.mark_dead(0)
		run.enemies.cleanup()
		check(core.remove_enemy(old_id), "個体IDで削除する")
		check(not core.remove_enemy(old_id), "削除済みのIDを拒否する")
		var row := run.enemies.spawn(definition, Vector2(100, 200))
		var new_id: int = core.spawn_enemy(&"drifter", Vector2(100, 200))
		check(new_id != old_id and new_id == run.enemies.table.id[row], "再利用後のIDを一致させる")
		check(comparison.difference(comparison.snapshot(run, [], 61).enemies, core.enemies_snapshot()).is_empty(), "再利用した個体に古い位置やHPを残さない")
		# 行動の登録順と、削除時の末尾入替を含む並びを比較する。
		for tick in 30:
			var def: EnemyDef = shield if tick % 3 == 0 else definition
			var at := Vector2(1000 + tick * 50, 300)
			row = run.enemies.spawn(def, at)
			core.spawn_enemy(def.id, at)
			if tick % 2 == 1:
				var target: int = run.enemies.beh_rows[0][0]
				var id: int = run.enemies.table.id[target]
				run.enemies.mark_dead(target)
				run.enemies.cleanup()
				check(core.remove_enemy(id), "途中の個体を解放する")
			var expected_order := PackedInt64Array()
			for rows in run.enemies.beh_rows:
				for index in rows: expected_order.append(run.enemies.table.id[index])
			check(core.enemy_order_snapshot() == expected_order, "行動の順と削除・再利用後の走査順を保つ")
		core.close()
		check(core.enemies_snapshot().is_empty(), "終了時に個体を解放する")
		lab.free()
	print("[native_motion] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)

func motion_step(bridge, intent: Intent = null) -> void:
	check(bridge.step(1.0/120.0,bridge.pack_intent(intent if intent!=null else Intent.new()),{"logical_size":Vector2(640,480)}).ok,"通常の固定更新で敵を進める")

func motion_row(bridge, id: int) -> Dictionary:
	for row: Dictionary in bridge._core.enemies_snapshot():
		if row.id==id: return row
	return {}

func motion_flags(bridge, id: int) -> Dictionary:
	for row: Dictionary in bridge._core.enemy_motion_snapshot():
		if row.id==id: return row
	return {}

func check_tracking_policy() -> bool:
	var builder = load("res://tools/content/build_run_content.gd")
	for kind in [&"drifter",&"biter"]:
		var config: GameConfig = ContentManager.base.duplicate(true)
		config.world_tick_div = 1
		config.kill_hitstop = 0.0
		var definition: EnemyDef = ContentManager.enemies[kind].duplicate(true)
		definition.stage_hp = 1000000.0
		definition.speed = 100.0
		definition.turn = 1.0
		config.start_radius = 0.0
		var stage := RuntimeStage.new()
		stage.index = 75
		stage.resources = StageResources.new()
		stage.resources.enemy_ids = PackedStringArray([String(kind)])
		stage.resources.look_paths = ContentManager.visual_index.look_paths.duplicate()
		stage.attack_managed_by_type = {String(kind):false}
		var output := "res://.content/dev/m03_motion/"+String(kind)
		var error: Error = builder.build(stage,config,output,"操舵の固定入力".sha256_text(),{kind:definition})
		check(error==OK,"追跡・噛みつきの編集値を生成する")
		if error!=OK: return false
		var path := output.path_join("stage_75.json")
		var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var session: RunSession = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":42},true)
		session.auto_step = false
		var bridge = session.bridge
		if bridge==null: return false
		var id: int = bridge.command("dev_spawn",{"definition_id":String(kind),"position":Vector2(200,100)}).value
		motion_step(bridge)
		var first := motion_row(bridge,id)
		check(absf(first.facing)<=1.0/120.0+1e-6 and first.pos[0]>200.0,"機体へ瞬時に向けず、旋回上限と鼻先への移動を保つ")
		check(bridge._core.set_enemy_motion(id,{"slash_hold":true}),"閃光斬の保持を設定する")
		var age: float = motion_flags(bridge,id).age
		var held_position: Array = first.pos
		motion_step(bridge)
		check(motion_row(bridge,id).pos==held_position and motion_flags(bridge,id).age>age,"閃光斬では年齢を進めて移動を止める")
		bridge._core.set_enemy_motion(id,{"held":true})
		age = motion_flags(bridge,id).age
		motion_step(bridge)
		check(motion_flags(bridge,id).age==age,"捕捉中はタイマーも進めない")
		bridge._core.set_enemy_motion(id,{"held":false,"slash_hold":false,"stone":0.1})
		motion_step(bridge)
		check(motion_flags(bridge,id).age==age and motion_flags(bridge,id).stone<0.1,"石化は石化時間だけ進める")
		bridge._core.set_enemy_motion(id,{"stone":0.0,"shove_time":0.1,"shove_vel":Vector2(0,100)})
		var pushed := motion_row(bridge,id)
		motion_step(bridge)
		var after_push := motion_row(bridge,id)
		check(absf(float(after_push.pos[1])-float(pushed.pos[1])-100.0/120.0)<1e-4,"外力の移動を自律操舵で上書きしない")
		bridge._core.set_enemy_motion(id,{"shove_time":0.0,"vel":Vector2.ZERO})
		# 実際の描線入力でなぞりを開始する。
		var pen: Vector2 = bridge.read_frame().value.ui.ship.ship_pos
		var input := Intent.new()
		input.has_cursor = true
		input.press = true
		input.touch = true
		input.pen = pen
		motion_step(bridge,input)
		input.press = false
		input.pen = pen+Vector2(100,0)
		motion_step(bridge,input)
		input.pen_release = true
		motion_step(bridge,input)
		check(bridge.read_frame().value.ui.tracing,"描線からなぞりへ入る")
		var facing: float = motion_row(bridge,id).facing
		motion_step(bridge)
		check(motion_row(bridge,id).facing==facing and motion_flags(bridge,id).turn_locked,"なぞり中は追跡と噛みつきの自律旋回を止める")
		# heldとポンプの所有は抑制対象から外す。所有は世代付き参照にする。
		bridge._core.set_enemy_motion(id,{"held":true})
		check(not motion_flags(bridge,id).turn_locked,"heldは操舵抑制の対象外")
		bridge._core.set_enemy_motion(id,{"held":false,"pump_owner":id})
		check(not motion_flags(bridge,id).turn_locked,"ポンプ所有中は操舵抑制の対象外")
		bridge._core.set_enemy_motion(id,{"pump_owner":0})
		for tick in range(240):
			if not bridge.read_frame().value.ui.tracing: break
			motion_step(bridge)
		check(not bridge.read_frame().value.ui.tracing and bridge.read_frame().value.ui.glide and not motion_flags(bridge,id).turn_locked,"なぞり終了で操舵抑制を解除する")
		var before_turn: float = motion_row(bridge,id).facing
		motion_step(bridge)
		check(motion_row(bridge,id).facing!=before_turn,"なぞり終了後は旋回を再開する")
		# 遠方では2回の移動を保ち、3回目の判断は3回分の旋回時間を使う。
		var far: int = bridge.command("dev_spawn",{"definition_id":String(kind),"position":Vector2(3000,3000)}).value
		var turned := false
		for tick in range(3):
			var old_facing: float = motion_row(bridge,far).facing
			motion_step(bridge)
			var angle: float = absf(float(motion_row(bridge,far).facing)-old_facing)
			if angle>0.0:
				check(absf(angle-3.0/120.0)<1e-5,"遠方の旋回に蓄積した世界dtを使う")
				turned = true
		check(turned,"遠方でも3回以内に判断する")
		var presentation: RunPresentation = session.view.get_node("RunPresentation")
		presentation._present_cpp(0.0)
		check(presentation.frame_view.visible,"通常画面がC++の敵表示を受け取る")
		if kind==&"biter":
			check(presentation.frame_view.enemy_frames.has(6) and presentation.frame_view.enemy_frames[6]._parts.size()==3,"噛みつく敵の本体・装甲・顎を表示する")
		session.free()
	return true
