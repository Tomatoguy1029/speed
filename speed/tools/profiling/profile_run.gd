## 通常の出撃・入力・Bridge・表示を使う最終計測。条件と結果はローカル専用へ保存する。
extends Node
const Phase := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS.Phase
const DRIVE_RADIUS := 900.0
const REFILL_FRAMES := 15
const FLAGS := ["gpu", "hitstop", "levels", "bonus", "keep", "normal-drops", "rewards"]
const NUMBERS := ["stage", "time", "seconds", "warmup", "seed", "hz", "fps", "draw", "stroke", "mixed_target", "boss_hp"]
const TEXT := ["size", "drive", "weapons", "meta", "mix", "revision", "out", "vsync", "condition", "require", "mode"]
const EVENT_ACTIVATIONS := {"space_quake":"W04","barrier_hit":"W05","barrier_restore":"W05","escort_deploy":"W26","escort_slash":"W26","sonic_push":"W08","sonic_impact":"W08","bolt":"W17","contact_bolt":"W17","critical_lance":"T06","chain_shock":"T05","end_hole":"T03","flash_slash":"W28","anchor_fire":"W21","bipolar_charge":"W22"}
const CAUSE_ACTIVATIONS := {"mine":"W07","endBlast":"W29","afterimage":"W27","barrier":"W05","contactWave":"W04","sonic":"W08","contactArc":"W17","dashRangeDrone":"W26","killSonic":"T05","critBeam":"T06","vortex":"T03","interceptor":"W25"}
var options := {}
var session: RunSession
var bridge: RefCounted
var view: Node2D
var configured := false
var measuring := false
var finished := false
var start_us := 0
var previous_us := 0
var ready_us := 0
var startup_us := 0
var start_metrics := {}
var start_recording := {}
var last_metrics := {}
var last_view := {}
var last_packed_bytes := 0
var view_record := {}
var samples: Array[Dictionary] = []
var notifications: Array[Dictionary] = []
var event_counts := {}
var activated := {}
var boss_actions := {}
var expected_equipment := {}
var mix: Array[String] = []
var mix_cursor := 0
var position_rng := RandomNumberGenerator.new()
var drive_center := Vector2.ZERO
var stroke: Array[Vector2] = []
var stroke_time := -1.0
var next_draw := 0.0
var input_ticks := 0
var stroke_starts := 0
var traced_ticks := 0
var drawing_ticks := 0
var maintenance_us := 0
var metadata := {}
var measurement_seconds := 60.0
var last_run_clock := 0.0
var run_result := {}
var timed_out := false
var bonus_entries := 0
var bonus_exits := 0
var invalid_reasons: Array[String] = []

func _fail(message: String) -> void:
	if finished: return
	finished = true
	configured = false
	push_error(message)
	var result := {"condition_valid":false,"failure":message,"options":options,"metadata":metadata}
	_save(result)
	get_tree().quit(1)

func _parse() -> bool:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=",true,1)
		if not arg.begins_with("--") or parts.size()!=2 or parts[1].is_empty() or options.has(parts[0]):
			_fail("計測の引数は重複のない --名前=値 で指定してください: "+arg)
			return false
		var key: String = parts[0]
		if key in ["stage","seed","hz","fps","mixed_target"] and not parts[1].is_valid_int():
			_fail("整数で指定してください: "+arg)
			return false
		if key not in FLAGS and key not in NUMBERS and key not in TEXT:
			_fail("未知の計測オプションです: "+key)
			return false
		if key in FLAGS and parts[1] not in ["on","off"] or key in NUMBERS and not parts[1].is_valid_float():
			_fail("計測オプションの値が不正です: "+arg)
			return false
		options[key] = parts[1]
	var defaults := {"stage":"1","time":"0","seconds":"60","warmup":"6","seed":"1029","hz":"120","fps":"0","draw":"2","stroke":"0","size":"1920x1080","drive":"circle","weapons":"W01:1","gpu":"on","levels":"off","hitstop":"off","vsync":"off","mode":"condition"}
	for key in defaults:
		if not options.has(key): options[key]=defaults[key]
	var size := String(options.size).split("x")
	if int(options.stage)<1 or int(options.stage)>5 or float(options.time)<0 or float(options.seconds)<60 or float(options.warmup)<0 or int(options.hz)!=120 or float(options.draw)<=0 or float(options.stroke)<0 or options.drive!="circle" or options.vsync not in ["on","off"] or options.mode not in ["condition","natural"] or int(options.fps)!=(60 if options.vsync=="on" else 0) or size.size()!=2 or not size[0].is_valid_int() or not size[1].is_valid_int() or int(size[0])<=0 or int(size[1])<=0:
		_fail("時刻・区間・120Hz・表示・入力の計測条件が不正です")
		return false
	if options.mode=="natural" and (options.levels!="on" or float(options.time)!=0 or options.has("boss_hp") or options.has("mixed_target")):
		_fail("通常進行は成長有効・開始時刻0・HP保持と混成補充なしで指定してください")
		return false
	if options.get("gpu","on")!="on" or options.get("normal-drops","on")!="on" or not options.has("revision") or not options.has("out"):
		_fail("最終計測ではGPU計時・通常ドロップ・revision・outを指定してください")
		return false
	if options.has("boss_hp") and (float(options.boss_hp)<=0 or float(options.boss_hp)>1) or options.has("mixed_target") and (int(options.mixed_target)<=0 or not options.has("mix") or options.get("keep","")!="on"):
		_fail("ボスHPまたは混成条件が不正です")
		return false
	for item in String(options.weapons).split(",",false):
		var pair := item.split(":")
		if pair.size()!=2 or not pair[1].is_valid_int() or int(pair[1])<=0 or expected_equipment.has(pair[0]):
			_fail("装備IDとLvを確認してください: "+item)
			return false
		var category := &"traits" if pair[0].begins_with("T") else &"weapons"
		if ContentManager.catalog.find(category,StringName(pair[0]))==null:
			_fail("現在の一覧にない装備IDです: "+pair[0])
			return false
		expected_equipment[pair[0]]=int(pair[1])
	if options.has("mix"):
		for item in String(options.mix).split(",",false):
			var pair := item.split(":")
			if pair.size()!=2 or not pair[1].is_valid_int() or int(pair[1])<=0 or int(pair[1])>100 or ContentManager.catalog.find(&"enemies",StringName(pair[0]))==null:
				_fail("混成のIDと比率を確認してください: "+item)
				return false
			for n in int(pair[1]): mix.append(pair[0])
	return true

func _ready() -> void:
	startup_us = Time.get_ticks_usec()
	process_priority = 100000
	if not _parse(): return
	if not OS.is_debug_build() or DisplayServer.get_name()=="headless" or RenderingServer.get_current_rendering_method()!="forward_plus":
		_fail("最終計測は開発版・描画付きForward Plusで起動してください")
		return
	if not str(SaveManager.SAVE_PATH).begins_with("/tmp/") or not str(SaveManager.SETTINGS_PATH).begins_with("/tmp/"):
		_fail("独立コピーのSAVE_PATHとSETTINGS_PATHを両方/tmpへ隔離してください")
		return
	Engine.physics_ticks_per_second = 120
	Engine.max_fps = int(options.fps)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if options.vsync=="on" else DisplayServer.VSYNC_DISABLED)
	var size := String(options.size).split("x")
	DisplayServer.window_set_size(Vector2i(int(size[0]),int(size[1])))
	SaveManager.data = SaveManager.default_data()
	SaveManager.dev_meta_override.clear()
	for item in String(options.get("meta","")).split(",",false):
		var pair := item.split(":")
		if pair.size()!=2 or not pair[1].is_valid_int() or int(pair[1])<0 or ContentManager.catalog.find(&"meta_upgrades",StringName(pair[0]))==null:
			_fail("永続強化のIDと段を確認してください: "+item)
			return
		SaveManager.dev_meta_override[pair[0]]=int(pair[1])
	ProfileManager.refresh()
	GameManager.run_stage = int(options.stage)
	GameManager.run_endless = false
	GameManager.run_start_time = 0.0
	GameManager.run_start_source = "stage_start"
	session = RunManager.create_run({"seed":int(options.seed)})
	session.auto_step = false
	add_child(session)
	while session.bridge==null and session.cpp_error==OK:
		if Time.get_ticks_usec()-startup_us>120000000:
			_fail("通常出撃の準備が完了しません")
			return
		await get_tree().process_frame
	if session.bridge==null:
		_fail("通常出撃がC++ランを開始できません")
		return
	bridge = session.bridge
	session.cpp_finished.connect(func(result: Dictionary): run_result=result.duplicate(true))
	view = session.view.get_node("RunPresentation").frame_view
	bridge.subscribe("final_profile",_receive)
	if not _command("dev_debug",{"action":"reset_loadout","args":{}}): return
	for id: String in expected_equipment:
		if not _command("dev_grant_equipment",{"kind":"trait" if id.begins_with("T") else "weapon","id":id,"levels":expected_equipment[id]}): return
	if not _command("dev_benchmark",{"leveling":options.levels=="on"}): return
	if not _command("set_settings",{"hitstop":options.hitstop=="on"}): return
	if options.mode=="condition" and not _command("dev_benchmark",{"survive":true}): return
	if options.mode=="condition" and not _command("dev_debug",{"action":"time","args":{"seconds":float(options.time)}}): return
	if options.has("boss_hp") and not _command("dev_benchmark",{"boss_hp":float(options.boss_hp)}): return
	position_rng.seed = int(options.seed)
	drive_center = bridge.latest_frame().value.ui.ship.ship_pos
	session.cpp_input_source = _input
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	ready_us = Time.get_ticks_usec()
	configured = true
	session.auto_step = true
	await get_tree().create_timer(float(options.warmup)).timeout
	if finished: return
	if options.has("mixed_target"):
		if not _command("dev_debug",{"action":"clear_enemies","args":{}}): return
		await get_tree().physics_frame
		await get_tree().physics_frame
		_refill()
	if options.get("bonus","off")=="on" and not _command("dev_benchmark",{"bonus":true}): return
	measurement_seconds=float(options.seconds)
	if options.get("bonus","off")=="on": measurement_seconds+=float(bridge.latest_frame().value.ui.bonus_remaining)
	if not _command("set_recording",{"active":true}): return
	start_recording = bridge.read_recording(true).value
	start_metrics = bridge.read_metrics().value
	view_record = view.perf.open(&"final_profile")
	last_metrics = start_metrics.duplicate(true)
	last_packed_bytes = int(start_metrics.packed_bytes)
	last_run_clock = float(start_recording.t)
	var bundle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(session.cpp_index_path))
	metadata = {"runtime":"cpp","entry":"RunManager.create_run → RunSession → RunBridge","options":options,"actual_equipment":_equipment(start_recording),"process_id":OS.get_process_id(),"profile":ProfileManager.for_cpp(false),"bundle":bundle,"recording_identity":bridge.recording_origin,"engine":Engine.get_version_info(),"revision":options.revision,"library_sha256":FileAccess.get_sha256("res://extensions/run/bin/libspeed_runtime.macos.template_release.arm64.dylib"),"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"processor":OS.get_processor_name(),"window":str(DisplayServer.window_get_size()),"logical_size":str(get_viewport().get_visible_rect().size),"texture_size":str(get_viewport().get_texture().get_size()),"measurement_seconds":measurement_seconds,"physics_hz":Engine.physics_ticks_per_second,"max_fps":Engine.max_fps,"vsync":DisplayServer.window_get_vsync_mode(),"gpu_measurement":true,"loading_timings":session.loading_timings,"ready_ms":(ready_us-startup_us)/1000.0,"copy_bytes_scope":"Packed配列の論理転送量。物理メモリコピー量ではない","timing_scope":"sim/output_buildはC++内部区間、bridge_copyはGodotの明示複製、engine_gpu_waitは未分離残差。観測費用を重ねて合算しない","source_generation_during_measurement":false,"ship_survival":"条件計測だけ致死を防ぐ。接触・バリア・ダメージは通常経路" if options.mode=="condition" else "通常進行では致死を防がない","boss_hp_hold":options.get("boss_hp","無効"),"normal_drops":true,"input_clock":"120Hz固定tick。描線時刻はsim_timeに対応する入力tick"}
	metadata["actual_start"]={"run_clock":start_recording.t,"world_clock":start_recording.world_t,"tick":start_metrics.tick,"enemy_types":start_metrics.enemy_types,"enemies":start_metrics.enemies,"bonus_remaining":bridge.latest_frame().value.ui.bonus_remaining,"boss_bodies":bridge.latest_frame().value.ui.boss_bodies}
	var effective: Dictionary = bridge.read_lab().value
	metadata["effective"]={"attack_power":effective.attack_power,"max_speed":effective.max_speed,"capacity":effective.capacity,"length_mult":effective.length_mult,"xp_profile_factor":effective.xp_profile_factor}
	metadata["clocks"]=start_metrics.clocks
	metadata["source_sha256"]={"profile":FileAccess.get_sha256("res://tools/profiling/profile_run.gd"),"bridge":FileAccess.get_sha256("res://scripts/runtime/run_bridge.gd"),"manager":FileAccess.get_sha256("res://scripts/managers/run_manager.gd")}
	if options.mode=="condition" and _equipment(start_recording)!=expected_equipment:
		_fail("指定Lvと実際の装備が一致しません")
		return
	input_ticks=0
	stroke_starts=0
	traced_ticks=0
	drawing_ticks=0
	notifications.clear()
	event_counts.clear()
	activated.clear()
	boss_actions.clear()
	maintenance_us=0
	last_metrics=bridge.read_metrics().value
	last_packed_bytes=int(last_metrics.packed_bytes)
	start_us=Time.get_ticks_usec()
	previous_us=start_us
	measuring=true
	print("PROFILE_BEGIN ",JSON.stringify(metadata))

func _equipment(record: Dictionary) -> Dictionary:
	var result: Dictionary = record.weapons.duplicate()
	result.merge(record.traits)
	return result

func _command(kind: String, payload: Dictionary) -> bool:
	var reply: Dictionary = bridge.command(kind,payload)
	if not reply.ok: _fail("条件を設定できません: "+kind+" "+str(reply))
	return reply.ok

func _input() -> Intent:
	var packet: Dictionary = bridge.latest_frame().value
	var ship: Dictionary = packet.ui.ship
	var draw: Dictionary = packet.ui.draw
	var input := Intent.new()
	input.has_cursor = true
	var relative: Vector2 = ship.ship_pos-drive_center
	var ahead: Vector2 = relative.normalized().rotated(0.5) if relative.length()>1.0 else Vector2.RIGHT
	input.cursor = drive_center+ahead*DRIVE_RADIUS
	var warp: Dictionary = view.get("_warp")
	var seek_warp: bool = options.mode=="natural" and float(warp.get("gone",-1.0))>=0.0
	if seek_warp: input.cursor=warp.position
	var clock := float(packet.tick)/120.0
	if measuring:
		input_ticks+=1
		if draw.drawing: drawing_ticks+=1
		if draw.tracing: traced_ticks+=1
	# 満タンの通常入力でギアアップも発動させる。充填時間や容量は変更しない。
	var charge_ready: bool = draw.gauge>=1.0 if expected_equipment.has("T04") or packet.ui.get("full_burst",false) else draw.gauge*packet.ui.capacity>=packet.ui.min_charge
	if not seek_warp and stroke_time<0 and clock>=next_draw and not draw.drawing and not draw.tracing and charge_ready:
		stroke.clear()
		var heading: Vector2 = ship.ship_heading
		var side := heading.orthogonal()
		for k in 7: stroke.append(ship.ship_pos+heading*(60.0+220.0*k)+side*(160.0 if k%2 else -160.0))
		stroke_time=clock
		next_draw=clock+float(options.draw)+float(options.stroke)
		if measuring: stroke_starts+=1
	if stroke_time>=0:
		input.touch=true
		var elapsed := clock-stroke_time
		var duration := float(options.stroke)
		var point := mini(6,int(elapsed/duration*6)) if duration>0 else mini(6,int(elapsed*120))
		input.pen=stroke[point]
		input.press=elapsed<0.5/120.0
		if (duration>0 and elapsed>=duration) or (duration==0 and elapsed>=7.0/120.0):
			input.pen_release=true
			stroke_time=-1.0
	return input

func _receive(frame: Dictionary) -> bool:
	if not measuring: return true
	for event: Dictionary in frame.events:
		var type: String = event.type
		var payload: Dictionary = event.payload
		event_counts[type]=int(event_counts.get(type,0))+1
		if type=="weapon_fire": activated[str(payload.id)]=int(activated.get(str(payload.id),0))+1
		if EVENT_ACTIVATIONS.has(type): activated[EVENT_ACTIVATIONS[type]]=int(activated.get(EVENT_ACTIVATIONS[type],0))+1
		if type=="combat_damage":
			var cause: String = str(payload.get("cause",""))
			if CAUSE_ACTIVATIONS.has(cause): activated[CAUSE_ACTIVATIONS[cause]]=int(activated.get(CAUSE_ACTIVATIONS[cause],0))+1
		if type=="boss_action" and payload.get("step","")=="execute": boss_actions[str(payload.action)]=int(boss_actions.get(str(payload.action),0))+1
		if type=="bonus":
			if payload.get("enter",false): bonus_entries+=1
			else: bonus_exits+=1
		if type in ["boss_action","boss_phase","boss_spawn","bonus","finished","time_limit_reached"]:
			notifications.append({"tick":frame.tick,"type":type,"payload":payload})
	return true

func _refill() -> void:
	var before := Time.get_ticks_usec()
	var count := int(bridge.read_metrics().value.enemies)
	var camera: Dictionary = bridge.latest_frame().value.camera
	var area := Rect2(camera.center-camera.half,camera.half*2.0)
	while count<int(options.mixed_target):
		var id: String = mix[mix_cursor%mix.size()]
		mix_cursor+=1
		var pos := Vector2(position_rng.randf_range(area.position.x,area.end.x),position_rng.randf_range(area.position.y,area.end.y))
		if not _command("dev_spawn",{"definition_id":id,"position":pos}): return
		var after := int(bridge.read_metrics().value.enemies)
		if after<=count:
			_fail("混成の補充で個体数が増えません: "+id)
			return
		count=after
	if measuring: maintenance_us+=Time.get_ticks_usec()-before

func _process(_delta: float) -> void:
	if not configured or finished: return
	if not bridge.delivery_error.is_empty() and not bridge.delivery_error.ok:
		_fail("通知の配信に失敗しました: "+str(bridge.delivery_error))
		return
	var packet: Dictionary = bridge.latest_frame().value
	if packet.ui.phase==Phase.Paused:
		if not _command("pause",{"paused":false}): return
	if options.get("rewards","off")=="off" and session.view.get_node("Hud/HudRoot")._rewards.is_active():
		session.view.get_node("Hud/HudRoot")._rewards.cancel()
	if options.levels=="on" and packet.ui.phase==Phase.Levelup:
		var cards: Dictionary = packet.ui.cards
		if int(cards.selected_id)==0 and not cards.candidates.is_empty():
			var chosen: Dictionary = cards.candidates[0]
			if cards.swap_pick!="" and not cards.comet_direct:
				for candidate: Dictionary in cards.candidates:
					if candidate.kind=="keep": chosen=candidate
			if not _command("choose_card",{"offer_id":int(cards.offer_id),"candidate_id":int(chosen.candidate_id)}): return
	if measuring and options.has("mixed_target") and Engine.get_process_frames()%REFILL_FRAMES==0: _refill()
	if not measuring or finished: return
	var before := Time.get_ticks_usec()
	var metrics: Dictionary = bridge.read_metrics().value
	for item in [["mines","items","W07"],["afterimage","echoes","W27"],["end_blast","visuals","W29"],["barrier","waves","W05"],["knockback","visuals","W03"]]:
		if not packet.ui.get(item[0],{}).get(item[1],[]).is_empty(): activated[item[2]]=int(activated.get(item[2],0))+1
	for drone: Dictionary in packet.ui.get("interceptor",{}).get("drones",[]):
		if float(drone.get("flash",0.0))>0: activated["W25"]=int(activated.get("W25",0))+1
	if packet.ui.get("full_burst_active",false): activated["T36"]=int(activated.get("T36",0))+1
	if packet.ui.draw.tracing and float(packet.ui.get("full_charge",{}).get("burst_power",1.0))>1.0:
		activated["T04"]=int(activated.get("T04",0))+1
	var timings := {}
	for key in ["sim","output_build","bridge_copy","resource_wait"]:
		var current: Array = metrics.timings.get(key,[0,0,0])
		var previous: Array = last_metrics.timings.get(key,[0,0,0])
		timings[key]=(float(current[0])-float(previous[0]))/1000.0
	var display := {}
	for key in view_record:
		var total: Array = view_record[key]
		display[str(key)]=(float(total[0])-float(last_view.get(key,0)))/1000.0
		last_view[key]=total[0]
	var now := Time.get_ticks_usec()
	var frame_ms := (now-previous_us)/1000.0
	previous_us=now
	var geometry := float(display.get("view_geometry.attacks",0.0))
	var update := maxf(0.0,float(display.get("view_submit",0.0))+float(display.get("view_effects",0.0))+float(display.get("view_tail",0.0))-geometry)
	var draw := geometry+float(display.get("view_draw.attacks",0.0))+float(display.get("view_draw.enemy_decorations",0.0))
	var viewport := get_viewport().get_viewport_rid()
	var bonus := float(packet.ui.get("bonus_remaining",0.0))>0
	var ui_paused: bool = packet.ui.phase in [Phase.Paused,Phase.Levelup] or session.view.get_node("Hud/HudRoot")._rewards.is_active()
	var scene := "ui" if ui_paused else "bonus" if bonus else "boss" if not packet.ui.get("boss_bodies",[]).is_empty() else "normal"
	var row := {"elapsed_ms":(now-start_us)/1000.0,"frame_ms":frame_ms,"tick":metrics.tick,"fixed_steps":metrics.fixed_steps,"enemies":metrics.enemies,"enemy_types":metrics.enemy_types,"attack_pools":metrics.attack_pools,"friendly":metrics.friendly_shots,"run_clock":packet.ui.run_time,"run_delta":float(packet.ui.run_time)-last_run_clock,"world_clock":packet.ui.world_time,"phase":packet.ui.phase,"scene":scene,"bonus_remaining":packet.ui.get("bonus_remaining",0.0),"hitstop":packet.ui.get("hitstop",0.0),"drawing":packet.ui.draw.drawing,"tracing":packet.ui.draw.tracing,"ship_position":str(packet.ui.ship.ship_pos),"boss_bodies":packet.ui.get("boss_bodies",[]),"sim":timings.sim,"output_build":timings.output_build,"bridge_copy":timings.bridge_copy,"resource_wait":timings.resource_wait,"bridge_bytes":int(metrics.packed_bytes)-last_packed_bytes,"view_update":update,"view_draw":draw,"view_detail":display,"observation_ms":(now-before)/1000.0,"keep_refill":maintenance_us/1000.0,"viewport_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(viewport),"viewport_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(viewport),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"scope_resources":session.resources.resources.size(),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"static_mb":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0}
	row["sim_clock"]=metrics.clocks.sim_time
	row["world_updates"]=metrics.clocks.world_updates
	row["world_real_accum"]=metrics.clocks.world_real_accum
	row["world_dt_accum"]=metrics.clocks.world_dt_accum
	row["ship_x"]=packet.ui.ship.ship_pos.x
	row["ship_y"]=packet.ui.ship.ship_pos.y
	row.engine_gpu_wait=maxf(0.0,frame_ms-timings.sim-timings.output_build-timings.bridge_copy-timings.resource_wait-update-draw-row.keep_refill)
	last_run_clock=float(packet.ui.run_time)
	last_metrics=metrics
	last_packed_bytes=int(metrics.packed_bytes)
	maintenance_us=0
	samples.append(row)
	if now-start_us>=int(measurement_seconds*1000000.0) or options.mode=="natural" and not run_result.is_empty():
		timed_out=run_result.is_empty() and options.mode=="natural"
		measuring=false
		configured=false
		session.auto_step=false
		await _finish()

func _stats(values: Array) -> Dictionary:
	if values.is_empty(): return {"available":false}
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	var stalls := 0
	for v in sorted:
		total+=float(v)
		if float(v)>1000.0/30.0: stalls+=1
	return {"available":true,"mean":total/sorted.size(),"min":sorted[0],"p95":sorted[int((sorted.size()-1)*0.95)],"p99":sorted[int((sorted.size()-1)*0.99)],"max":sorted[-1],"over_33_33ms":stalls}

func _judge(rows: Array) -> Dictionary:
	if rows.is_empty(): return {"observed":false,"performance_pass":false}
	var frames := _stats(rows.map(func(row): return row.frame_ms))
	var fps: float = 1000.0/frames.mean
	var run_elapsed := 0.0
	var real_elapsed := 0.0
	var eligible_elapsed := 0.0
	for row: Dictionary in rows:
		real_elapsed+=float(row.frame_ms)/1000.0
		if row.scene not in ["ui","bonus"] and float(row.hitstop)<=0:
			run_elapsed+=float(row.run_delta)
			eligible_elapsed+=float(row.frame_ms)/1000.0
	var clock_ratio := run_elapsed/eligible_elapsed if eligible_elapsed>0 else 0.0
	var bonus: bool = rows[0].scene=="bonus"
	var clock_required: bool = eligible_elapsed>0 and not bonus and options.hitstop=="off"
	var displayed: bool = options.vsync=="on"
	var fps_ok: bool = fps>=59.5 and fps<=60.5 if displayed else fps>=60.0
	var counts := _stats(rows.map(func(row): return float(row.enemies)))
	var count_ok: bool = not options.has("mixed_target") or counts.mean>=1250 and counts.mean<=1350
	var duration_ok: bool = options.mode=="natural" or bonus or rows[0].scene=="ui" or real_elapsed>=60.0-0.02
	return {"observed":true,"seconds":real_elapsed,"fps":fps,"frame_ms":frames,"enemy_count":counts,"run_clock_ratio":clock_ratio,"clock_required":clock_required,"physics_hz":float(rows[-1].fixed_steps-rows[0].fixed_steps)/maxf(real_elapsed,0.000001),"duration_valid":duration_ok,"performance_pass":duration_ok and fps_ok and frames.p95<=(18.0 if displayed else 16.67) and frames.p99<=20.0 and frames.over_33_33ms==0 and (not clock_required or clock_ratio>=0.99 and clock_ratio<=1.01) and count_ok}

func _finish() -> void:
	var actual := _equipment(bridge.read_recording().value)
	if options.mode=="condition" and actual!=expected_equipment: invalid_reasons.append("計測中に装備が変わった")
	if options.mode=="natural" and run_result.is_empty(): invalid_reasons.append("時間上限までに通常進行の終了を観測できない")
	if options.mode=="natural" and (bonus_entries==0 or bonus_exits==0): invalid_reasons.append("通常進行でボーナス開始と終了後を観測できない")
	if input_ticks==0 or traced_ticks==0: invalid_reasons.append("通常入力からの描線・突進が未発動")
	for id: String in (actual if options.mode=="natural" else expected_equipment):
		if (id.begins_with("W") or id in ["T03","T04","T05","T06","T36"]) and int(activated.get(id,0))==0: invalid_reasons.append(id+"の発動を確認できない")
	if options.has("stroke") and float(options.stroke)>0 and drawing_ticks==0: invalid_reasons.append("指定された描線期間が未発動")
	if options.has("boss_hp") and boss_actions.is_empty(): invalid_reasons.append("対象ボス技が未発動")
	if options.get("bonus","")=="on" and not event_counts.has("bonus"): invalid_reasons.append("ボーナス終了を観測できない")
	for id in String(options.get("require","")).split(",",false):
		if int(activated.get(id,0))==0 and int(boss_actions.get(id,0))==0: invalid_reasons.append("必須発動なし: "+id)
	var segments: Array[Dictionary] = []
	var begin := 0
	for i in range(1,samples.size()+1):
		if i==samples.size() or samples[i].scene!=samples[begin].scene:
			var segment := _judge(samples.slice(begin,i))
			segment.scene=samples[begin].scene
			segment.begin_frame=begin
			segment.end_frame=i-1
			segments.append(segment)
			begin=i
	var minute_windows: Array[Dictionary] = []
	var window_start := 0
	for i in range(1,samples.size()+1):
		if i==samples.size() or int(samples[i].elapsed_ms/60000.0)!=int(samples[window_start].elapsed_ms/60000.0):
			var window := _judge(samples.slice(window_start,i))
			window.minute=int(samples[window_start].elapsed_ms/60000.0)
			minute_windows.append(window)
			window_start=i
	var summary := {}
	for key in ["frame_ms","enemies","sim","output_build","bridge_copy","bridge_bytes","view_update","view_draw","resource_wait","engine_gpu_wait","observation_ms","keep_refill","viewport_cpu_ms","viewport_gpu_ms","draw_calls","static_mb","scope_resources"]:
		summary[key]=_stats(samples.map(func(row): return row[key]))
	if summary.viewport_gpu_ms.max<=0:
		summary.viewport_gpu_ms={"available":false,"reason":"この環境ではGPU時間が返らない"}
	if options.mode=="natural" and samples[-1].run_clock<300: invalid_reasons.append("5分以降の通常進行を観測できない")
	var condition_valid := invalid_reasons.is_empty()
	var result := {"metadata":metadata,"condition_valid":condition_valid,"invalid_reasons":invalid_reasons,"observed":true,"performance_pass":condition_valid and segments.all(func(segment): return segment.performance_pass),"segments":segments,"summary":summary,"physics_steps":int(last_metrics.fixed_steps)-int(start_metrics.fixed_steps),"input_ticks":input_ticks,"stroke_starts":stroke_starts,"drawing_ticks":drawing_ticks,"tracing_ticks":traced_ticks,"equipment_end":actual,"weapon_activations":activated,"boss_actions":boss_actions,"event_counts":event_counts,"notifications":notifications,"samples":samples,"gpu_by_kind":"未分離","physical_copy_bytes":"未分離"}
	result["minute_windows"]=minute_windows
	result["run_result"]=run_result
	result["timed_out"]=timed_out
	result["bonus_entries"]=bonus_entries
	result["bonus_exits"]=bonus_exits
	if options.mode=="natural":
		bridge.command("set_recording",{"active":false})
		view.perf.close(&"final_profile")
		session.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
		var reentry_start := Time.get_ticks_usec()
		var again: RunSession = RunManager.create_run({"seed":int(options.seed)+1})
		again.auto_step=false
		add_child(again)
		while again.bridge==null and again.cpp_error==OK and Time.get_ticks_usec()-reentry_start<120000000: await get_tree().process_frame
		result["reentry"]={"ready":again.bridge!=null,"loading_timings":again.loading_timings,"ready_ms":(Time.get_ticks_usec()-reentry_start)/1000.0,"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"static_mb":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0}
		if again.bridge==null:
			result.condition_valid=false
			result.performance_pass=false
			result.invalid_reasons.append("連続再出撃の準備に失敗")
		again.queue_free()
	_save(result)
	print("PROFILE_RESULT ",JSON.stringify({"path":options.out,"condition_valid":result.condition_valid,"performance_pass":result.performance_pass,"summary":summary,"invalid_reasons":invalid_reasons}))
	if options.mode!="natural":
		bridge.command("set_recording",{"active":false})
		view.perf.close(&"final_profile")
		session.queue_free()
	finished=true
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0 if result.condition_valid else 1)

func _save(result: Dictionary) -> void:
	if not options.has("out"): return
	var file := FileAccess.open(str(options.out),FileAccess.WRITE)
	if file==null:
		push_error("結果の保存先を開けません: "+str(options.out))
		return
	file.store_string(JSON.stringify(result))
	file.close()
