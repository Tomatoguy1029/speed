## profile_runのC++用経路。代表場面を明示生成し、通常のBridgeと表示を計測する。
extends Node
const ENTRY := preload("res://tools/profiling/profile_run.gd")
const BUILDER := preload("res://tools/content/build_run_content.gd")
var options: Dictionary
var session: RunSession
var bridge: RefCounted
var presentation: RunPresentation
var view: Node2D
var config: GameConfig
var mix: Array[StringName] = []
var cursor := 0
var position_rng := RandomNumberGenerator.new()
var drive_center := Vector2.ZERO
var stroke: Array[Vector2] = []
var stroke_index := -1
var next_draw_us := 0
var configured := false
var measuring := false
var started_us := 0
var previous_us := 0
var startup_us := 0
var ready_us := 0
var physics_steps := 0
var next_refill_tick := 0
var strokes := 0
var samples: Array[Dictionary] = []
var events := {}
var bridge_rec: Dictionary
var view_rec: Dictionary
var last_totals := {}
var maintenance_us := 0
var metadata := {}

func fail(message: String) -> void:
	push_error(message)
	configured = false
	get_tree().quit(1)

func _ready() -> void:
	startup_us = Time.get_ticks_usec()
	process_priority = 100000
	position_rng.seed = 1029
	var types := String(options.get("mix","biter:1,hound:1,shield:1,beamer:1,gunner:1"))
	for item in types.split(",",false):
		var pair := item.split(":")
		if pair.size()!=2 or pair[0] not in ["biter","hound","shield","beamer","gunner"] or not pair[1].is_valid_int() or int(pair[1])<=0 or int(pair[1])>100:
			fail("C++代表計測の敵IDと比率が不正です")
			return
		for n in int(pair[1]): mix.append(StringName(pair[0]))
	if mix.is_empty() or int(options.get("enemies","1300"))<=0:
		fail("混成と敵数を指定してください")
		return
	var fixed := {"stage":"5","drive":"circle","weapons":"W01:5","keep":"on","levels":"off","hitstop":"off","fps":"0","size":"1280x720"}
	for key in fixed:
		if options.has(key) and str(options[key])!=fixed[key]:
			fail("C++代表計測は固定条件です: --%s=%s" % [key,fixed[key]])
			return
	if DisplayServer.get_name()=="headless" or RenderingServer.get_current_rendering_method()!="forward_plus":
		fail("C++代表計測は描画付きのForward Plusで起動してください")
		return
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	config = ContentManager.base.duplicate(true)
	var source: RuntimeStage = ContentManager.runtime_stage(5)
	if source==null:
		fail("ステージ5の生成済み定義がありません")
		return
	var stage: RuntimeStage = source.duplicate(true)
	stage.resources = source.resources.duplicate(true)
	stage.resources.enemy_ids = PackedStringArray()
	for id in mix:
		if not String(id) in stage.resources.enemy_ids: stage.resources.enemy_ids.append(String(id))
	stage.boss_enabled = false
	stage.clips.clear()
	# 通常ステージ全編の移行を代用せず、この時刻の攻撃予算だけを抽出する。
	var at := float(options.get("time","320"))
	var selected: PhaseDef
	for phase: PhaseDef in source.phases:
		if phase.start<=at: selected=phase
	if selected!=null:
		selected = selected.duplicate(true)
		selected.start = 0.0
		stage.phases.assign([selected])
	else: stage.phases.clear()
	var output := "res://.content/dev/profile_cpp"
	var input_signature := (FileAccess.get_sha256("res://.content/stage_5.tres")+types+str(at)+String(options.get("revision",""))).sha256_text()
	var error: Error = BUILDER.build(stage,config,output,input_signature)
	if error!=OK:
		fail("代表場面の生成に失敗しました: %s" % error_string(error))
		return
	var path := output.path_join("stage_5.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	session = RunManager.create_session(self,{"runtime":"cpp","cpp_index":path,"cpp_signature":index.input_sha256,"seed":1029},true)
	session.auto_step = false
	while session.bridge==null and session.cpp_error==OK: await get_tree().process_frame
	if session.bridge==null:
		fail("C++代表場面の準備に失敗しました")
		return
	bridge = session.bridge
	presentation = session.view.get_node("RunPresentation")
	view = presentation.frame_view
	if not bridge.command("dev_grant_equipment",{"kind":"weapon","id":"W01","levels":4}).ok or not bridge.command("dev_benchmark",{"leveling":false}).ok:
		fail("W01 Lv5と成長を止める計測条件を設定できません")
		return
	bridge._core.set_run_guards({"invincible":true,"hitstop_enabled":false})
	bridge.command("set_settings",{"hitstop":false})
	# 初回の通常更新でカメラと可視範囲を確定してから配置する。
	bridge.step(1.0/120.0,bridge.pack_intent(Intent.new()),{"logical_size":get_viewport().get_visible_rect().size})
	drive_center = bridge._core.ship_snapshot().ship_pos
	_refill()
	bridge.subscribe("profile_cpp",_receive)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	ready_us = Time.get_ticks_usec()
	configured = true
	var initial_camera: Dictionary = bridge.latest_frame().value.camera
	var initial_render: Dictionary = bridge.read_render(Rect2(initial_camera.center-initial_camera.half,initial_camera.half*2.0)).value
	var initial_visible := 0
	for batch: Dictionary in initial_render.batches:
		if session.cpp_resources.visuals.any(func(entry): return entry.id==batch.visual_id and entry.role in [0,6]): initial_visible+=batch.ids.size()
	metadata = {"initial_visible_enemies":initial_visible,"initial_spawn_view":str(Rect2(initial_camera.center-initial_camera.half,initial_camera.half*2.0)),"runtime":"cpp","scope":"ステージ5の地形・外観と移行済み5種類の代表場面。ステージ5全編の合格ではない",
		"options":options,"seed":1029,"position_seed":1029,"mix":types,"time_budget_from":at,
		"equipment":{"W01":5},"physics_hz":Engine.physics_ticks_per_second,"world_tick_div":config.world_tick_div,
		"engine":Engine.get_version_info(),"revision":options.get("revision",""),"bundle":index,
		"library_sha256":FileAccess.get_sha256("res://extensions/run/bin/libspeed_runtime.macos.template_release.arm64.dylib"),
		"window":str(DisplayServer.window_get_size()),"logical_size":str(get_viewport().get_visible_rect().size),
		"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),
		"processor":OS.get_processor_name(),"max_fps":Engine.max_fps,"vsync":DisplayServer.window_get_vsync_mode(),
		"ready_ms":(ready_us-startup_us)/1000.0,"generation_before_measurement":true,"drive_input":"カーソル（描線の入力中だけtouch）","draw_min_charge_unit":"gauge × capacity。W01のみでcapacity=1",
		"copy_bytes_scope":"RenderFrameのPacked配列の内容量。参照カウントだけの受渡しを実コピー量としない",
		"timing_scope":"sim/output_buildはGDExtension呼出しを囲み、ABI通過を含む。bridge_copyは明示的な辞書の複製・UI合成。表示内訳はCPUで、種類ごとのGPU時間は未分離"}
	await get_tree().create_timer(float(options.get("warmup","10"))).timeout
	await _capture("start")
	bridge_rec = bridge.perf.open(&"bench")
	view_rec = view.perf.open(&"bench")
	started_us = Time.get_ticks_usec()
	previous_us = started_us
	metadata.start = bridge._core.inspect()
	metadata.warmup_ship_position = str(bridge._core.ship_snapshot().ship_pos)
	metadata.drive_center = str(drive_center)
	physics_steps = 0
	strokes = 0
	events.clear()
	maintenance_us = 0
	measuring = true
	print("PROFILE_BEGIN ",JSON.stringify(metadata))

func _receive(frame: Dictionary) -> bool:
	if measuring:
		for event: Dictionary in frame.events: events[event.type]=int(events.get(event.type,0))+1
	return true

func _refill() -> void:
	var before := Time.get_ticks_usec()
	var target := int(options.get("enemies","1300"))
	var count: int = int(bridge.read_metrics().value.enemies)
	var camera: Dictionary = bridge.latest_frame().value.camera
	var area := Rect2(camera.center-camera.half,camera.half*2.0)
	while count<target:
		var id: StringName = mix[cursor%mix.size()]
		cursor+=1
		var pos := Vector2(position_rng.randf_range(area.position.x,area.end.x),position_rng.randf_range(area.position.y,area.end.y))
		var created: Dictionary = bridge.command("dev_spawn",{"definition_id":String(id),"position":pos})
		if not created.ok:
			fail("混成の敵を生成できません: "+String(id))
			return
		# 猟犬は群れで増えるので、最後の1群だけは指定数を少し超えうる。
		count = int(bridge.read_metrics().value.enemies)
	if measuring: maintenance_us+=Time.get_ticks_usec()-before

func _physics_process(_dt: float) -> void:
	if not configured: return
	var state: Dictionary = bridge._core.ship_snapshot()
	var draw: Dictionary = bridge._core.draw_snapshot()
	var input := Intent.new()
	input.touch = false
	input.has_cursor = true
	var relative: Vector2 = state.ship_pos-drive_center
	var ahead: Vector2 = relative.normalized().rotated(0.5) if relative.length()>1.0 else Vector2.RIGHT
	input.cursor = drive_center+ahead*ENTRY.DRIVE_RADIUS
	if stroke_index<0 and Time.get_ticks_usec()>=next_draw_us and not draw.drawing and not draw.tracing and draw.gauge>=config.draw_min_charge:
		stroke.clear()
		var heading: Vector2 = state.ship_heading
		var side := heading.orthogonal()
		stroke.append(state.ship_pos+heading*60.0)
		for k in range(1,7): stroke.append(state.ship_pos+heading*(60.0+220.0*k)+side*(160.0 if k%2 else -160.0))
		stroke_index = 0
		next_draw_us = Time.get_ticks_usec()+int(float(options.get("draw","2"))*1000000.0)
		if measuring: strokes+=1
	if stroke_index>=0:
		input.touch = true
		if stroke_index<stroke.size():
			input.pen = stroke[stroke_index]
			input.press = stroke_index==0
		else: input.pen_release=true
		stroke_index+=1
		if stroke_index>stroke.size(): stroke_index=-1
	var result: Dictionary = bridge.step(1.0/120.0,bridge.pack_intent(input),{"logical_size":get_viewport().get_visible_rect().size})
	if not result.ok:
		fail("代表場面の固定更新に失敗しました: "+str(result))
		return
	if measuring: physics_steps+=1

func _delta_records(records: Dictionary,prefix: String) -> Dictionary:
	var result := {}
	for key in records:
		var total: Array = records[key]
		var previous: Array = last_totals.get(prefix+String(key),[0,0,0])
		result[String(key)] = (float(total[0])-float(previous[0]))/1000.0
		last_totals[prefix+String(key)] = total.duplicate()
	return result

func _process(_dt: float) -> void:
	if not configured: return
	if physics_steps>=next_refill_tick:
		_refill()
		next_refill_tick=physics_steps+ENTRY.REFILL_TICKS
	if not measuring: return
	var before := Time.get_ticks_usec()
	var metrics: Dictionary = bridge.read_metrics().value
	var packet: Dictionary = bridge.latest_frame().value
	var b := _delta_records(bridge_rec,"bridge:")
	var v := _delta_records(view_rec,"view:")
	var observation_ms := (Time.get_ticks_usec()-before)/1000.0
	var now := Time.get_ticks_usec()
	var frame_ms := (now-previous_us)/1000.0
	previous_us = now
	var viewport := get_viewport().get_viewport_rid()
	var geometry_ms := float(v.get("view_geometry.attacks",0.0))
	var draw_ms := geometry_ms+float(v.get("view_draw.attacks",0.0))+float(v.get("view_draw.enemy_decorations",0.0))
	var update_ms := maxf(0.0,float(v.get("view_submit",0.0))+float(v.get("view_effects",0.0))+float(v.get("view_tail",0.0))-geometry_ms)
	# callbacksの分はview_submitに含まれない。差し引くのはその中の形状構築だけ。
	var sample := {"elapsed_ms":(now-started_us)/1000.0,"frame_ms":frame_ms,"enemies":metrics.enemies,"types":metrics.enemy_types,"attacks":metrics.attack_pools,
		"sim":b.get("sim",0.0),"output_build":b.get("output_build",0.0),"bridge_copy":b.get("bridge_copy",0.0),
		"view_update":update_ms,"view_draw":draw_ms,"detail":v,"profiler_observation":observation_ms,
		"ship_x":packet.ui.ship.ship_pos.x,"ship_y":packet.ui.ship.ship_pos.y,"circle_radius":packet.ui.ship.ship_pos.distance_to(drive_center),
		"keep_refill":maintenance_us/1000.0,"resource_wait":frame_ms if packet.ui.cards.get("preparing",false) else 0.0,
		"viewport_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(viewport),
		"viewport_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(viewport),
		"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
	sample.engine_gpu_wait = maxf(0.0,frame_ms-float(sample.sim)-float(sample.output_build)-float(sample.bridge_copy)-update_ms-draw_ms-float(sample.keep_refill))
	maintenance_us = 0
	samples.append(sample)
	if now-started_us>=int(float(options.get("seconds","60"))*1000000.0):
		measuring = false
		configured = false
		await _finish()

func _stats(values: Array) -> Dictionary:
	if values.is_empty(): return {}
	values.sort()
	var total := 0.0
	for value in values: total+=float(value)
	return {"mean":total/values.size(),"min":values[0],"p95":values[int((values.size()-1)*0.95)],"p99":values[int((values.size()-1)*0.99)],"max":values[-1]}

func _capture(suffix: String) -> void:
	if not options.has("capture"): return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(String(options.capture)+"_"+suffix+".png")

func _finish() -> void:
	var seconds := float(Time.get_ticks_usec()-started_us)/1000000.0
	var summary := {}
	for key in ["frame_ms","enemies","sim","output_build","bridge_copy","view_update","view_draw","resource_wait","engine_gpu_wait","profiler_observation","keep_refill","viewport_cpu_ms","viewport_gpu_ms","draw_calls"]:
		summary[key] = _stats(samples.map(func(row): return row[key]))
	var details := {}
	for key in view_rec:
		if key==&"render_packed_bytes": continue
		details[String(key)] = {"ms_frame":float(view_rec[key][0])/1000.0/samples.size(),"calls":view_rec[key][1],"max_call_ms":float(view_rec[key][2])/1000.0}
	if float(summary.viewport_gpu_ms.get("max",0.0))<=0.0: summary.viewport_gpu_ms={"available":false,"reason":"この環境ではGPU計時が返らない"}
	var result := {"metadata":metadata,"seconds":seconds,"frames":samples.size(),"fps":samples.size()/seconds,
		"physics_steps":physics_steps,"stroke_starts":strokes,"summary":summary,"display_detail":details,
		"condition_valid":summary.enemies.mean>=1250.0 and summary.enemies.mean<=1350.0 and metadata.initial_visible_enemies>=1200,
		"events":events,"end":bridge._core.inspect(),"render_packed_bytes_per_frame":float(view_rec.get(&"render_packed_bytes",[0])[0])/samples.size(),"samples":samples,"per_kind_gpu":"未分離","detail_render_packed_bytes_unit":"samples.detailのrender_packed_bytesは1000byte単位。render_packed_bytes_per_frameはbyte単位","observation_scope":"profiler_observationは観測用コピーを含む参考値。bridge_copyとの重複があるため独立区間として足さず、残差からも差し引かない",
		"copy_bytes":"未分離。Packed配列の内容量と実メモリコピー量を混同しない"}
	var out := String(options.get("out","/tmp/speed-cpp-early-result.json"))
	var file := FileAccess.open(out,FileAccess.WRITE)
	if file==null:
		fail("計測結果の保存先を開けません: "+out)
		return
	file.store_string(JSON.stringify(result))
	file.close()
	print("PROFILE_RESULT ",JSON.stringify({"path":out,"fps":result.fps,"summary":summary,"condition_valid":result.condition_valid}))
	await _capture("end")
	bridge.perf.close(&"bench")
	view.perf.close(&"bench")
	session.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()
