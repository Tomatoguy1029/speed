## 地形のない固定条件で、追跡の出現・LOD移動・個体再利用を本番処理と照合する。
extends Node
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	check(check_tracking_policy(),"追跡・噛みつきの操舵を最後まで確認する")
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
