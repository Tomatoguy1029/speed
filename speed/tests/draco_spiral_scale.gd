extends Node
const FORM = preload("res://scripts/bosses/draco_form.gd")
var failures := 0
func check(ok: bool,label: String) -> void:
	if not ok: failures+=1;push_error(label)
func reset_visible(actor) -> void:
	actor.table.pos[actor.body]=Vector2.ZERO
	actor.table.facing[actor.body]=-PI*0.5
	actor.body_override.clear();actor.body_pose.clear();actor.body_trail.clear()
	actor.reset_pose()
func _ready() -> void:
	var stage: RuntimeStage=ContentManager.runtime_stage(5).duplicate(true)
	stage.boss_enabled=false
	var session:=RunManager.create_session(self,{"lab":true,"stage":stage,"stage_index":5,"seed":405},false)
	session.auto_step=false
	var sim: RunSimulation=session.sim
	sim.bosses.spawn(load("res://data/bosses/draco.tres"),Vector2.ZERO)
	var actor=sim.bosses.actor
	sim.state.enemy_aim=Vector2.ZERO
	var baseline_radius: float=actor.table.r[actor.body]
	for half in [Vector2(980,550),Vector2(550,550),Vector2(550,980)]:
		actor.cancel_attack();actor.cycle.cancel()
		reset_visible(actor)
		sim.state.view_half=half
		actor.start_attack(&"spiral")
		var spiral=actor._driver
		var short_side := minf(half.x,half.y)*2.0
		check(minf(spiral.extent,spiral.horizontal_extent)>=minf(half.x,half.y),"渦の短辺半径を画面の短辺より小さくしない")
		check(maxf(spiral.extent,spiral.horizontal_extent)>=maxf(half.x,half.y)*0.75,"円寄りでも外周を画面全体へ広げる")
		check(maxf(spiral.extent,spiral.horizontal_extent)/minf(spiral.extent,spiral.horizontal_extent)<=1.31,"渦を画面の縦横比でつぶさず円に近づける")
		if is_equal_approx(half.x,half.y): check(is_equal_approx(spiral.extent,spiral.horizontal_extent),"正方形画面の渦は円にする")
		check(minf(spiral.extent,spiral.horizontal_extent)*spiral.pitch_ratio>=actor.body_width*1.5,"隣の周回との間隔を胴幅より広く取る")
		check(spiral.spiral_length>=PI*(spiral.extent+spiral.horizontal_extent)*1.39,"広げた渦を巻ける有効胴体長を用意する")
		check(actor.get("body_width")!=null,"螺旋の胴体の太さを表示と判定で共有する")
		if actor.get("body_width")!=null:
			check(actor.body_width>=short_side*0.13,"胴体を画面に対して十分太くする")
			check(actor.head_scale<=1.5,"螺旋でも頭部を過大にしない")
			for frame in 540: actor.sim_tick(1.0/120.0,1.0/120.0)
			var fractions: PackedFloat32Array=FORM.fractions(spiral.points)
			for index in spiral.walls.size():
				var fraction := (fractions[index]+fractions[index+1])*0.5
				check(is_equal_approx(sim.projectiles.hazard_width[spiral.walls[index]],actor.body_width*FORM.taper(fraction)),"青紫の壁と胴体の先細りが一致する")
		actor.cancel_attack()
	actor.cancel_attack();actor.cycle.cancel()
	sim.state.view_half=Vector2(980,550)
	sim.state.ship_pos=Vector2.ZERO;sim.state.enemy_aim=Vector2.ZERO
	sim.state.ship_invuln=0.0;sim.ship.invincible=false
	reset_visible(actor)
	var hp:=sim.state.ship_hp
	actor.start_attack(&"spiral")
	var damage_frames:=0
	var early_damage:=false
	while not actor._driver.trapped_hit and damage_frames<1000:
		sim.state.ship_invuln=maxf(0.0,sim.state.ship_invuln-1.0/120.0)
		actor.sim_tick(1.0/120.0,1.0/120.0)
		if actor.mode==&"windup" or (actor.mode==&"active" and actor.elapsed<actor._driver.coil_time+actor._driver.pause_time):
			if sim.state.ship_hp<hp: early_damage=true
		damage_frames+=1
	check(not early_damage,"構築と溜めで中心の機体へ接触ダメージを出さない")
	check(sim.state.ship_hp<hp,"胴体が実際に閉じたところで挟まれた被弾を出す")
	actor.cancel_attack()
	check(is_equal_approx(actor.table.r[actor.body],baseline_radius),"技の終了時に頭の判定を元へ戻す")
	sim.state.ship_pos=Vector2.ZERO
	reset_visible(actor)
	var original_zoom: float=sim.state.camera_zoom
	actor.start_attack(&"spiral")
	for frame in 540: actor.sim_tick(1.0/120.0,1.0/120.0)
	check(sim.state.camera_zoom<original_zoom,"構築中は操作を残してカメラを少し引く")
	check(not sim.state.controls_locked,"巻き終わりには操作を戻す")
	var wait_release:=0
	while actor._driver.holding_player and wait_release<300:
		actor.sim_tick(1.0/120.0,1.0/120.0)
		wait_release+=1
	var center_before: Vector2=actor._driver.center
	sim.state.ship_pos=Vector2(350,0)
	for frame in 8: actor.sim_tick(1.0/120.0,1.0/120.0)
	check(actor._driver.center==center_before,"溜めの予告後は逃走しても渦の中心を追従させない")
	var lock_frames:=0
	while not actor._driver.locked and lock_frames<180:
		actor.sim_tick(1.0/120.0,1.0/120.0)
		lock_frames+=1
	check(actor._driver.locked,"発進時に照準を固定する")
	var locked_center: Vector2=actor._driver.center
	sim.state.ship_pos=Vector2(900,0)
	for frame in 30: actor.sim_tick(1.0/120.0,1.0/240.0)
	check(actor._driver.center==locked_center,"スロー中も発進後の軌道を追尾しない")
	actor.cancel_attack()
	check(not sim.state.cinematic_camera,"中断で通常カメラへ戻す")
	sim.state.view_center=Vector2.ZERO
	sim.state.view_half=Vector2(980,550)
	sim.state.camera_zoom=1.0
	sim.state.ship_pos=Vector2(300,0)
	actor.table.pos[actor.body]=Vector2.ZERO
	actor.table.facing[actor.body]=0.0
	actor.body_override.clear();actor.body_pose.clear();actor.body_trail.clear()
	actor.reset_pose()
	var visible_pose: PackedVector2Array=actor.body_points()
	actor.start_attack(&"spiral")
	var spiral_exit=actor._driver
	check(spiral_exit.departing and spiral_exit.points[0].distance_to(visible_pose[0])<0.01,"開始時に画面内の頭を飛ばさない")
	check(not sim.state.controls_locked and not sim.state.encounter_protected,"退場中は機体の操作を止めない")
	var exit_frames:=0
	while spiral_exit.departing and exit_frames<600:
		if exit_frames==50: sim.state.ship_pos+=Vector2(0,-220)
		actor.sim_tick(1.0/120.0,1.0/120.0)
		check(spiral_exit.walls.is_empty(),"全身退場中に渦の攻撃壁を出さない")
		exit_frames+=1
	check(not spiral_exit.departing and exit_frames<600,"移動中のカメラでも全身退場が終わる")
	check(spiral_exit._entire_body_offscreen(actor),"渦の姿勢へ切り替える時は頭と胴体が全て画面外")
	check(actor.mode==&"windup" and actor.elapsed<float(actor.rule().warn),"全身退場後も画面外から入る予告を続ける")
	var entry_frames:=0
	while actor.mode==&"windup" and entry_frames<180:
		actor.sim_tick(1.0/120.0,1.0/120.0)
		entry_frames+=1
	check(actor.mode==&"active" and entry_frames<180,"画面外から入った後に渦構築を始める")
	actor.sim_tick(1.0/120.0,1.0/120.0)
	check(spiral_exit.holding_player and sim.state.controls_locked and sim.state.encounter_protected,"渦構築中だけ機体の操作と被害を止める")
	var held_pos: Vector2=sim.state.ship_pos
	var held_center: Vector2=spiral_exit.center
	var held_hp: float=sim.state.ship_hp
	sim.state.ship_pos+=Vector2(120,80)
	actor.sim_tick(1.0/120.0,1.0/120.0)
	check(sim.state.ship_pos==held_pos,"渦構築中は機体と竜の相対位置を固定する")
	check(spiral_exit.center==held_center,"渦構築中は機体に対する渦の中心も動かさない")
	check(not sim.ship.damage(20.0,0.0,&"spiral_build") and sim.state.ship_hp==held_hp,"構築中は他敵からも被害を受けない")
	var build_frames:=0
	while spiral_exit.holding_player and build_frames<300:
		actor.sim_tick(1.0/120.0,1.0/120.0)
		build_frames+=1
	check(build_frames<300 and not sim.state.controls_locked and not sim.state.encounter_protected,"巻き終わりに操作と通常の被害を復帰する")
	check(actor.elapsed<spiral_exit.coil_time+spiral_exit.pause_time,"解放後に逃走できる溜め時間を残す")
	check(spiral_exit.points[0].distance_to(held_pos+Vector2.UP*spiral_exit.head_offset)<12.0,"巻き終わりの頭を機体から安全な距離の上に置く")
	check(sim.state.ship_invuln>=0.35,"操作復帰直後に接触猶予を渡す")
	actor.cancel_attack()
	check(not sim.state.cinematic_camera and not sim.state.controls_locked and actor.body_override.is_empty(),"再入場中断でカメラ・入力・通常胴体へ戻す")
	reset_visible(actor)
	actor.start_attack(&"spiral")
	actor.sim_tick(1.0/120.0,1.0/120.0)
	actor.cancel_attack()
	check(not sim.state.cinematic_camera and not sim.state.controls_locked and actor.body_override.is_empty(),"全身退場の途中でも元の姿勢と入力へ戻す")
	reset_visible(actor)
	actor.start_attack(&"spiral")
	spiral_exit=actor._driver
	var transition_frames:=0
	while spiral_exit.departing and transition_frames<600:
		actor.sim_tick(1.0/120.0,1.0/120.0)
		transition_frames+=1
	actor.sim_tick(1.0/120.0,1.0/120.0)
	actor.cancel_attack()
	check(not sim.state.cinematic_camera and not sim.state.controls_locked and actor.body_override.is_empty(),"再登場の途中でも元の姿勢と入力へ戻す")
	var original_move: Resource=actor._moves[&"spiral"]
	var tuned_move: Resource=original_move.duplicate(true)
	var tuned: Dictionary=tuned_move.parameters.duplicate(true)
	tuned.radius_factor=1.05;tuned.aspect_ratio=1.25;tuned.pitch_ratio=0.30
	tuned.coil_time=0.8;tuned.pause=0.9;tuned.head_offset=370.0;tuned.exit_duration=1.2
	tuned_move.parameters=tuned
	actor._moves[&"spiral"]=tuned_move
	sim.state.view_center=Vector2.ZERO;sim.state.view_half=Vector2(980,550);sim.state.camera_zoom=1.0
	reset_visible(actor)
	actor.start_attack(&"spiral")
	var tuned_spiral=actor._driver
	check(absf(tuned_spiral.horizontal_extent-980.0/0.82*1.05)<1.0,"調整した外周半径を実動作で読む")
	check(absf(tuned_spiral.horizontal_extent/tuned_spiral.extent-1.25)<0.01,"調整した縦横比を実動作で読む")
	check(is_equal_approx(tuned_spiral.pitch_ratio,0.30) and is_equal_approx(tuned_spiral.coil_time,0.8),"周間隔と構築速度の変更を実動作で読む")
	check(is_equal_approx(tuned_spiral.head_offset,370.0),"頭終点の変更を実動作で読む")
	actor.cancel_attack()
	tuned.radius_factor=0.1;tuned.aspect_ratio=9.0;tuned.pitch_ratio=0.0
	tuned.coil_time=99.0;tuned.pause=0.0;tuned.head_offset=0.0;tuned.exit_duration=100.0
	tuned_move.parameters=tuned
	reset_visible(actor)
	actor.start_attack(&"spiral")
	var safe_spiral=actor._driver
	check(minf(safe_spiral.extent,safe_spiral.horizontal_extent)>=actor.body_width*4.0,"小さすぎる半径でも渦の逃げ道を維持する")
	check(maxf(safe_spiral.extent,safe_spiral.horizontal_extent)/minf(safe_spiral.extent,safe_spiral.horizontal_extent)<=1.51,"極端な縦横比は補正する")
	check(safe_spiral.pitch_ratio*minf(safe_spiral.extent,safe_spiral.horizontal_extent)>=actor.body_width*1.5,"狭すぎる周間隔を補正する")
	check(safe_spiral.coil_time<=3.0 and safe_spiral.pause_time>=0.8,"構築と逃走の時間を安全範囲へ補正する")
	check(safe_spiral.head_offset>=actor.table.r[actor.body]+sim.cfg.ship_radius+60.0,"頭終点に接触余白を確保する")
	actor.cancel_attack()
	actor._moves[&"spiral"]=original_move
	sim.state.ship_pos=Vector2(300,0)
	sim.state.ship_vel=Vector2.UP*2200.0
	reset_visible(actor)
	actor.start_attack(&"spiral")
	var chasing_exit=actor._driver
	var chasing_frames:=0
	while chasing_exit.departing and chasing_frames<600:
		sim.state.ship_pos+=sim.state.ship_vel/120.0
		actor.sim_tick(1.0/120.0,1.0/120.0)
		chasing_frames+=1
	check(not chasing_exit.departing and chasing_frames<600,"自機が上へ高速移動しても全身退場で待ち続けない")
	actor.cancel_attack()
	sim.state.ship_vel=Vector2.ZERO
	sim.state.ship_pos=Vector2(300,0)
	reset_visible(actor)
	actor.start_attack(&"spiral")
	var lock_start_frames:=0
	while actor.mode==&"windup" and lock_start_frames<600:
		actor.sim_tick(1.0/120.0,1.0/120.0)
		lock_start_frames+=1
	actor.sim_tick(1.0/120.0,1.0/120.0)
	check(sim.state.controls_locked,"シーン終了の検査前には構築中の操作固定が有効")
	session.free()
	check(not sim.state.controls_locked and not sim.state.cinematic_camera,"シーン終了時に入力とカメラを復帰する")
	print("[draco_spiral_scale] failures=",failures)
	get_tree().quit(1 if failures else 0)
