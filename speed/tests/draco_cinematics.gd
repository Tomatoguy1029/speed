extends Node
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _ready() -> void:
	var stage: RuntimeStage = ContentManager.runtime_stage(5).duplicate(true)
	stage.boss_enabled = false
	var session := RunManager.create_session(self, {"lab":true,"stage":stage,"stage_index":5,"seed":1605}, false)
	session.auto_step = false
	var sim: RunSimulation = session.sim
	sim.field.bodies.clear()
	sim.state.ship_pos = Vector2(180,260)
	sim.state.view_center = Vector2(60,180)
	sim.state.camera_zoom = 0.6
	sim.state.view_half = Vector2(800,450)
	sim.state.ship_heading = Vector2.LEFT
	sim.bosses.spawn(load("res://data/bosses/draco.tres"), Vector2(-500,-100))
	var actor = sim.bosses.actor
	actor.selection_enabled = false
	var initial_pos: Vector2 = actor.table.pos[actor.body]
	var camera: Vector2 = sim.state.view_center
	var view_half: Vector2 = sim.state.view_half
	for angle in [0.0, PI*0.5, PI, -PI*0.5]:
		actor.table.facing[actor.body] = angle
		actor.entrance.begin()
		for frame in 60: actor.entrance.tick(1.0/60.0)
		check(is_equal_approx(actor.table.facing[actor.body],PI*0.5),"登場方向に関係なく自機を背後から映す対面構図に揃える")
		actor.entrance.cancel()
		check(sim.state.view_center.is_equal_approx(camera) and is_equal_approx(sim.state.camera_zoom,0.6),"登場中断はカメラ中心と倍率を復元する")
		check(sim.state.view_half.is_equal_approx(view_half),"登場中断は入力に使う表示範囲も復元する")
		check(actor.table.pos[actor.body].is_equal_approx(initial_pos),"登場中断は戦闘前の本体位置を復元する")
		check(not sim.state.controls_locked and not sim.state.cinematic_camera and sim.state.cinematic_bars==0.0,"登場中断後に操作とHUDを返す")
	check(actor.entrance.has_method("skip"),"登場だけを明示的にスキップできる")
	if actor.entrance.has_method("skip"):
		actor.entrance.begin()
		actor.entrance.skip()
		check(actor.mode==&"idle" and actor.table.guard[actor.body]==0.0,"登場スキップは無敵を残さず戦闘へ渡す")
		actor.entrance.skip()
		check(not sim.state.controls_locked,"二重スキップで操作を再ロックしない")
	var original_ship: Vector2=sim.state.ship_pos
	for ship_at in [Vector2(0,-9900),Vector2(9000,2500),Vector2(1200,1200)]:
		sim.state.ship_pos=ship_at
		var solid:=FieldSystem.Body.new()
		solid.pos=ship_at+Vector2.UP*430.0;solid.r=300.0
		sim.field.bodies.append(solid)
		actor.entrance.begin()
		actor.entrance.skip()
		var head: Vector2=actor.table.pos[actor.body]
		var margin: float=actor.def.radius*actor.head_scale+40.0
		check(head.length()<=sim.cfg.field_radius-margin+0.1,"端の対面でも頭を世界境界内へ置く")
		check(head.distance_to(solid.pos)>=solid.r+margin-0.1,"対面の本体を天体の中へ置かない")
		check(sim.state.ship_pos==ship_at,"安全な対面構図のために自機を瞬間移動しない")
		sim.field.bodies.clear()
	sim.state.ship_pos=original_ship
	actor.entrance.begin()
	for frame in 600: actor.entrance.tick(1.0/60.0)
	check(not actor.entrance.active and actor.mode==&"idle","登場は通常終了できる")
	check(sim.state.ship_heading==Vector2.LEFT,"登場終了時に機体の元の向きを返す")
	actor.phase=2
	actor.cycle.begin_initial()
	for frame in 1000: actor.cycle.tick(1.0/60.0)
	check(actor.cycle.stage==&"" and actor.mode==&"idle","初回生成が全段階を終えて本体戦へ戻る")
	check(not sim.state.controls_locked and not sim.state.cinematic_camera and not sim.state.encounter_protected,"初回生成のロックと保護を全て解放する")
	actor.cycle.begin_deep()
	check(not sim.state.controls_locked and sim.state.cinematic_bars==0.0,"通常の採集では操作を止めない")
	for frame in 90: actor.cycle.tick(1.0/60.0)
	actor.cycle.cancel()
	check(actor._presentation.scale==Vector2.ONE,"採集中断は描画だけの縮小を残さない")
	actor.finale.begin()
	actor.finale.guide.append(Vector2.ONE)
	actor.finale.strokes.append(Vector2.ONE)
	actor.finale.began=true
	actor.finale.completed=true
	actor.finale.dispose()
	actor.finale.begin()
	check(actor.finale.guide.is_empty() and actor.finale.strokes.is_empty() and not actor.finale.began and not actor.finale.completed,"最終決着の再生は前回の描画と完了フラグを引き継がない")
	for frame in 420: actor.finale.advance(1.0/60.0,Intent.new())
	check(actor.finale.stage==&"input" and not sim.state.controls_locked,"最終姿勢から自由描画へ渡す")
	check(sim.state.world_scale==0.0,"最終描画の世界時計は止まる")
	var it := Intent.new()
	it.press=true;it.has_cursor=true;it.pen=Vector2(-100,0)
	actor.finale.advance(1.0/60.0,it)
	it=Intent.new();it.has_cursor=true;it.pen=Vector2(10000,0)
	actor.finale.advance(1.0/60.0,it)
	check(actor.finale.stage==&"input" and actor.finale.strokes[-1]==Vector2(10000,0),"長い自由描画を自動確定や切り詰めしない")
	actor.finale.dispose()
	check(not sim.state.cinematic_camera and not sim.state.controls_locked and sim.state.world_scale>0.0,"最終演出の中断はカメラと操作と世界の速さを返す")
	for target: StringName in [&"release",&"combine",&"pose",&"input",&"strikes",&"last",&"sight",&"split"]:
		var before_camera: Vector2=sim.state.view_center
		var before_zoom: float=sim.state.camera_zoom
		var before_ship: Vector2=sim.state.ship_pos
		sim.state.ship_vel=Vector2(40,-70)
		var before_velocity: Vector2=sim.state.ship_vel
		actor.finale.begin()
		for frame in 1200:
			if actor.finale.stage==target: break
			var action:=Intent.new()
			if actor.finale.stage==&"input":
				action.press=not actor.finale.began;action.has_cursor=true;action.pen=Vector2(200,100);action.pen_release=actor.finale.began
			actor.finale.advance(1.0/60.0,action)
		check(actor.finale.stage==target,"決着の中断地点へ到達する: "+target)
		if target in [&"strikes",&"last"]:
			actor.finale.advance(0.12,Intent.new())
			check(not sim.state.ship_pos.is_equal_approx(before_ship),"連撃の実移動を経てから中断を検証する: "+target)
		actor.finale.dispose()
		check(sim.state.ship_pos.is_equal_approx(before_ship) and sim.state.ship_vel.is_equal_approx(before_velocity),"決着の各段階中断で実際の自機位置と速度を返す: "+target)
		actor.finale.begin()
		actor.finale.dispose()
		check(sim.state.ship_pos.is_equal_approx(before_ship) and sim.state.ship_vel.is_equal_approx(before_velocity),"中断後の再生でも自機の基準位置をずらさない: "+target)
		check(sim.state.view_center.is_equal_approx(before_camera) and is_equal_approx(sim.state.camera_zoom,before_zoom),"決着の各段階中断でカメラを返す: "+target)
		check(not sim.state.controls_locked and not sim.state.cinematic_camera and sim.state.world_scale>0.0,"決着の各段階中断で操作と世界を返す: "+target)
	for aspect in [Vector2(1280,720),Vector2(900,900),Vector2(720,1280)]:
		for angle in [0.0,PI*0.5,PI,-PI*0.5]:
			sim.ctx.options["view_size"]=aspect
			sim.state.ship_pos=Vector2(-300,200)
			sim.state.view_center=sim.state.ship_pos
			sim.state.camera_zoom=minf(aspect.x,aspect.y)/1100.0
			actor.table.pos[actor.body]=Vector2(430,-220)
			actor.table.facing[actor.body]=angle
			actor._update_body()
			var ship_before: Vector2=sim.state.ship_pos
			actor.finale.begin()
			var all_visible:=true
			for frame in 240:
				actor.finale.advance(1.0/60.0,Intent.new())
				if not actor.finale.stage in [&"release",&"combine"]: continue
				var probes:=PackedVector2Array()
				for vertex in [Vector2(-118,-108),Vector2(-118,108),Vector2(110,0),Vector2(24,-91),Vector2(-8,87)]:
					probes.append(actor.table.pos[actor.body]+(vertex*actor.head_scale).rotated(actor.table.facing[actor.body]))
				for corner in [Vector2(-45,-45),Vector2(45,-45),Vector2(-45,45),Vector2(45,45)]: probes.append(sim.state.ship_pos+corner)
				for star in actor.finale.BEAR: probes.append(actor.finale.core+star)
				if actor.finale.stage==&"combine":
					for j in 4:
						var part: Vector2=(actor.finale.core+Vector2.from_angle(j*TAU/4.0)*250.0).lerp(sim.state.ship_pos,clampf(actor.finale.time/2.0,0.0,1.0))
						for corner in [Vector2(-28,-28),Vector2(28,-28),Vector2(-28,28),Vector2(28,28)]: probes.append(part+corner)
				for point in probes:
					var pixel: Vector2=aspect*0.5+(point-sim.state.view_center)*sim.state.camera_zoom
					if not Rect2(aspect*Vector2(0.04,0.12),aspect*Vector2(0.92,0.76)).has_point(pixel): all_visible=false
			check(all_visible,"核解放と合体は頭・自機・星座・部品を黒帯の内側へ映す: %s angle%s" % [aspect,angle])
			check(sim.state.ship_pos==ship_before,"合体の構図を合わせるために自機を移動しない")
			actor.finale.dispose()
	sim.ctx.options.erase("view_size")
	actor.cancel_attack();actor.cycle.cancel();sim.projectiles.clear_hostile()
	actor.phase=3;actor.mode=&"idle"
	actor.start_attack(&"rifts")
	var rifts_open := false
	for frame in 600:
		actor.sim_tick(1.0/60.0,1.0/60.0)
		if actor.technique == &"rifts" and actor._driver != null and actor._driver.walls.size() == 6:
			rifts_open = true
			break
	check(rifts_open,"引っ掻きの退場・再登場後に亀裂を開く")
	actor.finale.begin()
	check(sim.state.cinematic_hide_enemies,"最終演出では残った通常敵を画面から退ける")
	check(not actor.closing_walls.is_empty(),"亀裂を引き裂いた後の決着移行で修復を開始する")
	actor.finale.advance(0.5,Intent.new())
	check(actor.closing_walls.is_empty(),"止まった世界でも取り消した亀裂の修復を実時間で完了する")
	actor.finale.dispose()
	check(not sim.state.cinematic_hide_enemies,"決着を中断すると通常敵の表示方針を復元する")
	actor.finale.begin()
	var observed: Array[StringName]=[]
	var defeats_before: int=sim.state.events.filter(func(event):return event.type==&"boss_defeated").size()
	for frame in 1800:
		if actor.finale.completed: break
		if not actor.finale.stage in observed: observed.append(actor.finale.stage)
		if actor.finale.stage in [&"pose",&"input"]: check(sim.state.final_modules.size()==4,"機体合体の完了時点から四つの部品を武器欄へ渡す")
		var action:=Intent.new()
		if actor.finale.stage==&"input":
			action.press=not actor.finale.began;action.has_cursor=true;action.pen=Vector2(200,100);action.pen_release=actor.finale.began
		actor.finale.advance(1.0/60.0,action)
	check(observed==[&"release",&"combine",&"pose",&"input",&"strikes",&"last",&"sight",&"split",&"explode"],"核解放から爆発まで採用済みの順序を全て通る")
	check(actor.finale.completed and sim.state.draco_finish_done,"決着を完走して通常クリアへ接続する")
	actor.finale.advance(1.0,Intent.new())
	var defeats_after: int=sim.state.events.filter(func(event):return event.type==&"boss_defeated").size()
	check(defeats_after-defeats_before==1,"決着の完了通知は一度だけ出す")
	check(not sim.state.controls_locked and not sim.state.cinematic_camera and sim.state.world_scale>0.0,"完走後に演出のロックを残さない")
	session.free()
	print("[draco_cinematics] failures=",failures)
	get_tree().quit(1 if failures else 0)
