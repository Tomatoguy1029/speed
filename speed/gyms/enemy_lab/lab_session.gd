## 本番ランを固定更新で実行する実験セッション。共有セーブ・設定を編集しない。
extends Node

signal changed
signal event_recorded(event: Dictionary)
signal seek_progress(value: float)

const ARMOR_PAINT := preload("res://tools/content/visual_transforms.gd")
const FORMAT := preload("res://gyms/enemy_lab/lab_io.gd")
const DT := 1.0 / 120.0

var scene: RunSession
var run: RefCounted
var bridge: RefCounted
var last_error := {}
var _source: RuntimeStage
var _definitions := {}
var _boss_definitions := {}
## 制作画面だけの深いコピー。通常ランや保存用specには入れない。
var _boss_programs := {}
var _baseline_bosses := {}
var _config: GameConfig
var _output := ""
var _formation_sources: Array = []
var _baseline_config: GameConfig
var _baseline_stage: StageDef
var _baseline_definitions := {}
var _seek_view_mode := SubViewport.UPDATE_ALWAYS
const BUILDER := preload("res://tools/content/build_run_content.gd")
const LOADER := preload("res://scripts/runtime/run_content_loader.gd")
const PROJECTION := preload("res://scripts/runtime/run_read_model.gd")
var baseline: Dictionary = {}
var spec: Dictionary = {}
var history: Array[Dictionary] = []
var branches: Array[Dictionary] = []
var current_branch := ""
var branch_serial := 0
var events: Array[Dictionary] = []
var checkpoints: Array[Dictionary] = []
var edit_undo: Array[Dictionary] = []
var edit_redo: Array[Dictionary] = []
var revision := 0
var tick := 0
var furthest := 0
var playing := false
var seeking := false
var speed := 1.0
var _cursor := 0
var _epoch := 0
var _seek_serial := 0
var _state_key := ""
var _intent := Intent.new()
var _selected_row := -1
var _selected_id := -1
var selected: int:
	get:
		return row_for_id(_selected_id) if is_instance_valid(run) else -1
	set(value):
		_selected_row = value
		_selected_id = run.enemies.table.id[value] if is_instance_valid(run) and value >= 0 and value < run.enemies.table.id.size() else -1
var schedule: Array = []
var _accumulator := 0.0
## 本番のランを映す表示枠。入っていれば、本番の描画・HUD・カメラ・入力をそのまま使う（作業用のセッションは空で、描画しない）
var viewport: SubViewport
## 試遊中の本番の入力を返す（試遊していなければ null）。記録して再生すると同じ展開になる
var live_input: Callable
var _last_input := {}
## 描いたルートを本番の描画で描いている途中（点の列・描き終えるまでの回数・進んだ回数）。空なら描いていない
var _route_play := {}
## 機体を固定している位置（固定していなければ null）。固定中は機体を動かさず、敵だけが動く
var pinned: Variant = null
## 最後に再生を始めた時刻（リセットで戻る所）
var play_start := 0
var _was_playing := false

func reset(settings := {}) -> void:
	playing = false
	_seek_serial += 1
	seeking = false
	for checkpoint in checkpoints:
		_free_checkpoint(checkpoint)
	checkpoints.clear()
	history.clear()
	edit_undo.clear()
	edit_redo.clear()
	branches.clear()
	branch_serial = 0
	current_branch = tr("lab.initial_branch")
	spec = {"seed": 932, "empty": true, "stage": 1, "auto_spawn": false, "invincible": true}
	spec.merge(settings.duplicate(true), true)
	_boss_programs = preload("res://tools/content/build_boss_program.gd").snapshot(spec.get("boss_programs",{}))
	spec.erase("boss_programs")
	# 保存で本番の外観が変わっても、この実験の巻き戻しは開始時の値から再生する。
	if not spec.has("overrides"):
		spec["overrides"] = {}
	for type in ContentManager.enemies:
		var id := String(type)
		if not spec.overrides.has(id):
			spec.overrides[id] = {}
		if not spec.overrides[id].has("visual_settings"):
			spec.overrides[id]["visual_settings"] = ContentManager.enemies[type].visual_settings.duplicate(true)
		if not spec.overrides[id].has("armor_colors"):
			spec.overrides[id]["armor_colors"] = ContentManager.enemies[type].armor_colors.duplicate(true)
	_baseline_config = ContentManager.base.duplicate(true)
	_baseline_stage = ContentManager.stage(int(spec.get("stage",1))).duplicate(true)
	_baseline_definitions = ContentManager.enemies.duplicate(true)
	_baseline_bosses = ContentManager.bosses.duplicate(true)
	baseline = FORMAT.baseline()
	furthest = 0
	await _rebuild()
	_restore_seek_view()
	changed.emit()

func _rebuild() -> void:
	revision += 1
	_epoch += 1
	if is_instance_valid(scene):
		if scene.get_parent()!=null: scene.get_parent().remove_child(scene)
		scene.queue_free()
	_config = _baseline_config.duplicate(true)
	for key in spec.get("config",{}): _config.set(key,spec.config[key])
	_config.trait_slots = maxi(_config.trait_slots,spec.get("traits",{}).size())
	var flags: Dictionary = spec.get("field",{})
	var terrain: bool = flags.get("terrain",not spec.get("empty",true))
	if not terrain: _config.moon_count = 0
	if not flags.get("rocks",not spec.get("empty",true)):
		_config.meteor_count = 0
		_config.iron_count = 0
		_config.saw_count = 0
	if not flags.get("gimmicks",not spec.get("empty",true)):
		_config.comet_interval_min = 1e8
		_config.comet_interval_max = 1e8
		_config.gravity_interval_min = 1e8
		_config.gravity_interval_max = 1e8
	var stage: StageDef = _baseline_stage.duplicate(true)
	_source = load("res://tools/content/build_runtime_stage.gd").compile(stage)
	_source.resources = _source.resources.duplicate(true)
	_source.resources.enemy_ids = PackedStringArray()
	_definitions = {}
	for id in _baseline_definitions:
		var definition: EnemyDef = _baseline_definitions[id].duplicate(true)
		for key in spec.get("overrides",{}).get(String(id),{}):
			var value = spec.overrides[String(id)][key]
			if key=="params": definition.params.merge(value,true)
			else: definition.set(key,value)
		if not BUILDER.chase_package(definition,_config,_source).is_empty():
			_definitions[id] = definition
			_source.resources.enemy_ids.append(String(id))
	_boss_definitions = {}
	for id in _baseline_bosses:
		var boss: BossDef = _baseline_bosses[id].duplicate(true)
		for key in spec.get("boss_overrides",{}).get(String(id),{}):
			if key=="params":
				for param in spec.boss_overrides[String(id)].params: boss.params[param] = safe_parameter(param,spec.boss_overrides[String(id)].params[param])
			else: boss.set(key,spec.boss_overrides[String(id)][key])
		if not BUILDER.boss_package(boss,_config,_source,_boss_programs.get(String(id),{})).is_empty(): _boss_definitions[id] = boss
	for id in spec.get("boss_overrides",{}):
		if not _boss_definitions.has(StringName(id)):
			last_error = {"ok":false,"message":"このボスの編集はまだ移行していません: "+String(id)}
			run = null
			return
	# 未移行種類は配置時に失敗として返す。旧ランで補完しない。
	_formation_sources = []
	_output = "res://.content/dev/lab_%d_%d" % [OS.get_process_id(),get_instance_id()]
	var built: Error = BUILDER.build(_source,_config,_output,"実験場".sha256_text(),_definitions,[],_boss_definitions,null,_boss_programs)
	if built!=OK:
		last_error = {"ok":false,"message":"実験の定義を生成できません: "+error_string(built)}
		run = null
		return
	var index_path := _output.path_join("stage_%d.json" % _source.index)
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(index_path))
	scene = RunManager.create_session(viewport if viewport!=null else self,{"runtime":"cpp","cpp_index":index_path,"cpp_signature":index.input_sha256,"seed":int(spec.get("seed",932)),"hud":true,"cpp_start":{"lab_mode":true},"cpp_profile":ProfileManager.for_cpp(true,spec.get("meta",{})),"cpp_edit_source":{"stage":_source,"config":_config,"definitions":_definitions}},viewport!=null)
	scene.remove_from_group("recordable_runs")
	scene.auto_step = false
	while is_instance_valid(scene) and scene.bridge==null and scene.cpp_error==OK: await get_tree().process_frame
	if not is_instance_valid(scene): return
	if scene.bridge==null:
		last_error = {"ok":false,"message":"実験のC++ランを開始できません"}
		run = null
		return
	bridge = scene.bridge
	run = PROJECTION.new()
	run.cfg = _config
	run.enemies.data.definitions = _definitions
	run.bosses.definitions = _boss_definitions
	run.state.data.stage = stage
	run.input = scene.cpp_input_source.get_object()
	bridge.subscribe("実験の履歴",_consume_frame)
	var scenario := {"lab_mode":true,"auto_spawn":spec.get("auto_spawn",false),"auto_boss":spec.get("auto_boss",false),"invincible":spec.get("invincible",true),"time":float(spec.get("time",0.0)),"gauge":float(spec.get("gauge",1.0)),"level":int(spec.get("level",1)),"empty":not terrain}
	if not terrain or spec.has("ship_pos"): scenario.position = vector(spec.get("ship_pos",[0,0]))
	last_error = bridge.command("dev_set_scenario",{"kind":"lab","params":scenario})
	if not last_error.ok: return
	bridge.command("dev_remove_weapon",{"id":"W01"})
	for kind in ["weapon","trait"]:
		var owned: Dictionary = spec.get("weapons" if kind=="weapon" else "traits",{})
		var ids := owned.keys()
		ids.sort()
		for id in ids: bridge.command("dev_grant_equipment",{"id":String(id),"kind":kind,"levels":int(owned[id])})
	if spec.has("post_max"):
		last_error = bridge.command("dev_edit",{"kind":"post_max","payload":{"stacks":spec.post_max}})
		if not last_error.ok: return
	tick = 0
	selected = -1
	_cursor = 0
	_state_key = ""
	_intent = Intent.new()
	_last_input = {}
	_route_play = {}
	pinned = null
	_accumulator = 0
	events.clear()
	schedule = spec.get("schedule",[]).duplicate(true)
	if not String(spec.get("hero","")).is_empty(): _apply("hero",{"id":String(spec.hero)})
	if not spec.get("meta",{}).is_empty(): _apply_meta(spec.meta)
	_apply("schedule",{"entries":schedule})
	_apply_recorded()
	_refresh_projection()

func _refresh_projection() -> bool:
	if bridge==null or run==null: return false
	var read: Dictionary = bridge.read_lab()
	var frame: Dictionary = bridge.read_frame()
	if not read.ok or not frame.ok:
		last_error = read if not read.ok else frame
		return false
	run.refresh(read.value,frame.value.ui)
	return true

func _consume_frame(frame: Dictionary) -> bool:
	for item: Dictionary in frame.events:
		var event: Dictionary = item.payload.duplicate(true)
		event.merge({"type":item.type,"tick":item.tick,"t":item.t,"world_t":item.world_t},true)
		events.append(event)
		event_recorded.emit(event)
	return true

func vector(value) -> Vector2:
	if value is Vector2:
		return value
	return Vector2(float(value[0]), float(value[1])) if value is Array and value.size() == 2 else Vector2.ZERO

func _physics_process(delta: float) -> void:
	if playing and not _was_playing and not seeking:
		play_start = tick
	_was_playing = playing
	if not playing or seeking or not is_instance_valid(run):
		return
	_accumulator += delta * speed
	var budget := 0
	while _accumulator >= DT and budget < 20:
		_take_live_input()
		step()
		_accumulator -= DT
		budget += 1
	changed.emit()

## 試遊中は、本番の入力をその回の操作として記録してから進める。
## 記録済みの時刻を再生している間は記録どおりに進め、押す操作があったときだけ、そこから新しい分岐にする。
func _take_live_input() -> void:
	if not live_input.is_valid():
		return
	var it = live_input.call()
	if it == null:
		return
	var pressed: bool = it.press or it.alt_press or it.hero_press or it.pen_release
	if tick < furthest and not pressed:
		return
	var args := {"has_cursor": it.has_cursor, "cursor": [it.cursor.x, it.cursor.y], "pen": [it.pen.x, it.pen.y],
		"press": it.press, "alt_press": it.alt_press, "hero": it.hero_press, "release": it.pen_release, "touch": it.touch}
	if not pressed and args == _last_input:
		return
	_last_input = args
	perform("input", args)

## 描いたルートを、本番の描画と同じ処理で少しずつ描き、描き終えたら確定して駆け抜けさせる。
## 長さの上限・地形・角の補正は本番どおりにかかる。操作の履歴の "route" から始まるので、再生しても同じになる。
func _draw_route_step() -> void:
	if _route_play.is_empty(): return
	var path: PackedVector2Array = _route_play.points
	var frames: int = _route_play.frames
	var n: int = _route_play.n
	if n==0:
		var started: Dictionary = bridge.command("dev_edit",{"kind":"draw","payload":{"action":"start","position":path[0]}})
		if not started.ok:
			_route_play = {}
			return
	var index := clampf(float(n+1)/frames*(path.size()-1),0,path.size()-1)
	var previous := float(n)/frames*(path.size()-1)
	for k in range(ceili(previous),floori(index)+1):
		if k>0 and k<path.size(): bridge.command("dev_edit",{"kind":"draw","payload":{"action":"extend","position":path[k]}})
	var lo := mini(floori(index),path.size()-2)
	bridge.command("dev_edit",{"kind":"draw","payload":{"action":"extend","position":path[lo].lerp(path[lo+1],index-lo)}})
	_route_play.n = n+1
	if n+1>=frames:
		bridge.command("dev_edit",{"kind":"draw","payload":{"action":"commit"}})
		_route_play = {}

func _add_field(kind: String, at: Vector2, radius: float) -> Dictionary:
	if kind=="gem":
		for k in 12:
			var u := Vector2.from_angle(k*2.399963)*sqrt((k+0.5)/12.0)*radius
			var result: Dictionary = bridge.command("dev_drop_crystal",{"position":at+u,"kind":PickupSystem.GemKind.LOW})
			if not result.ok: return result
		return {"ok":true}
	if kind=="planet": return bridge.command("dev_edit",{"kind":"planet","payload":{"position":at,"radius":maxf(10.0,radius)}})
	if kind=="comet":
		var direction: Vector2 = (run.state.ship_pos-at).normalized()
		if direction==Vector2.ZERO: direction = Vector2.RIGHT
		return bridge.command("dev_add_rock",{"kind":preload("res://tools/content/generated/run_schema.gd").ENUMS.RockKind.Comet,"position":at,"velocity":direction*_config.comet_speed,"born":float(run.state.world_time),"gone":float(run.state.world_time)+(at.distance_to(run.state.ship_pos)+2500.0)/_config.comet_speed,"size":maxf(20.0,radius),"facing":direction.angle(),"manual":true})
	if kind=="warp": return bridge.command("dev_set_warp",{"position":at,"life":float(_config.warp_life)})
	if kind=="gravity": return bridge.command("dev_add_well",{"position":at,"life":float(_config.gravity_life),"radius":float(_config.gravity_radius),"pull":float(_config.gravity_pull)})
	return {"ok":false,"message":"このフィールドの手動配置はまだ移行していません"}

func step() -> void:
	if not is_instance_valid(run): return
	_draw_route_step()
	last_error = bridge.step(DT,bridge.pack_intent(_intent),{"logical_size":Vector2(1280,720)})
	if not last_error.ok:
		playing = false
		return
	_intent.press = false
	_intent.alt_press = false
	_intent.hero_press = false
	_intent.pen_release = false
	revision += 1
	tick += 1
	furthest = maxi(furthest,tick)
	_refresh_projection()
	_apply_recorded()

func _apply_recorded() -> void:
	var old_cursor := _cursor
	while _cursor < history.size() and int(history[_cursor].tick) <= tick:
		_apply(String(history[_cursor].kind), history[_cursor].args)
		_cursor += 1
	if _state_key.is_empty() or old_cursor != _cursor:
		_state_key = _checkpoint_key(tick)

func perform(kind: String, args := {}) -> bool:
	if seeking or not is_instance_valid(run): return false
	var inverse := _inverse_edit(kind,args) if kind!="input" else []
	if not _apply(kind,args): return false
	if kind!="input":
		edit_undo.append({"history":history.duplicate(true),"end":furthest,"tick":tick,"commands":inverse,"opposite":[{"kind":kind,"args":args.duplicate(true)}]})
		if edit_undo.size()>20: edit_undo.pop_front()
		edit_redo.clear()
	if tick<furthest:
		branches.append({"name":current_branch,"history":history.duplicate(true),"end":furthest})
		branch_serial += 1
		current_branch = tr("lab.message_549e9c3c03") % branch_serial
		history = history.filter(func(e): return int(e.tick)<=tick)
		furthest = tick
	revision += 1
	history.append({"tick":tick,"kind":kind,"args":args.duplicate(true)})
	_cursor = history.size()
	_state_key = _checkpoint_key(tick)
	changed.emit()
	return true

func _apply(kind: String, args: Dictionary) -> bool:
	last_error = _apply_command(kind,args)
	if last_error.get("ok",false): _refresh_projection()
	else: push_warning(last_error.get("message","実験の編集に失敗しました"))
	return last_error.get("ok",false)

func _apply_command(kind: String, args: Dictionary) -> Dictionary:
	match kind:
		"spawn":
			var id := String(args.get("type","drifter"))
			if not _definitions.has(StringName(id)): return {"ok":false,"message":"この敵はまだ移行していません: "+id}
			var origin := vector(args.get("pos",[0,0]))
			for k in clampi(int(args.get("count",1)),1,10000):
				var offset := Vector2.from_angle(k*2.399963)*sqrt(float(k))*float(args.get("spacing",60))
				var result: Dictionary = bridge.command("dev_spawn",{"definition_id":id,"position":origin+offset,"facing":float(args.get("angle",0)),"elite":bool(args.get("elite",false))})
				if not result.ok: return result
				_selected_id = result.value
			_refresh_projection()
			_selected_row = row_for_id(_selected_id)
			return {"ok":true}
		"boss":
			var id := StringName(args.get("type","hydra"))
			if not _boss_definitions.has(id): return {"ok":false,"message":"このボスはまだ移行していません: "+String(id)}
			var ids := _boss_definitions.keys()
			ids.sort()
			for k in clampi(int(args.get("count",1)),1,32):
				var result: Dictionary = bridge.command("dev_spawn_boss",{"definition":ids.find(id)+1,"position":vector(args.get("pos",[0,0]))+Vector2(k*400,0),"entrance":false})
				if not result.ok: return result
				_selected_id = result.value
			return {"ok":true}
		"delete": return bridge.command("dev_remove",{"entity_id":int(args.get("id",-1))})
		"clear":
			for id in run.enemies.table.id:
				var result: Dictionary = bridge.command("dev_remove",{"entity_id":int(id)})
				if not result.ok: return result
			return bridge.command("dev_clear_hostile",{})
		"formation":
			var path := String(args.get("path",""))
			if not ResourceLoader.exists(path): return {"ok":false,"message":"配置の定義がありません"}
			var source: Dictionary = load("res://tools/content/build_runtime_stage.gd").formation(load(path))
			if source.is_empty(): return {"ok":false,"message":"配置の形式が不正です"}
			var next_sources := _formation_sources.duplicate(true)
			next_sources.append(source)
			var built: Error = BUILDER.build(_source,_config,_output,"実験場".sha256_text(),_definitions,next_sources,_boss_definitions,null,_boss_programs)
			if built!=OK: return {"ok":false,"message":"配置の定義を生成できません"}
			var bundle := _read_generated()
			if bundle.is_empty(): return {"ok":false,"message":"配置の生成物を読み込めません"}
			var result: Dictionary = bridge.replace_scenario("formation",{"layout":int(args.get("layout",0)),"entry":int(args.get("entry",0))},bundle.bytes)
			if result.ok: _formation_sources = next_sources
			return result
		"meta":
			var levels: Dictionary = run.state.meta_override.duplicate(true)
			levels[String(args.get("id",""))] = clampi(int(args.get("level",0)),0,100)
			return _apply_meta(levels)
		"hero": return bridge.command("dev_set_hero",{"id":String(args.get("id",""))})
		"individual":
			var payload := {"entity_id":int(args.get("id",-1))}
			for key in ["elite","size"]:
				if args.has(key): payload[key] = args[key]
			return bridge.command("dev_edit",{"kind":"individual","payload":payload})
		"edit_range":
			var row := row_for_id(int(args.get("id",-1)))
			if row<0: return {"ok":false}
			var edited := _edit_definition({"type":String(run.enemies.table.type[row]),"key":"params."+String(args.get("key","")),"value":maxf(0.01,float(args.get("length",1)))})
			if not edited.ok: return edited
			return _apply_command("move",{"id":int(args.id),"pos":run.enemies.table.pos[row],"angle":float(args.get("angle",run.enemies.table.facing[row]))})
		"director":
			var payload := {}
			for key in ["enabled","budget","jitter"]:
				if args.has(key): payload[key] = args[key]
			return bridge.command("dev_edit",{"kind":"director","payload":payload})
		"guard": return bridge.command("dev_edit",{"kind":"guard","payload":{"until":float(args.get("until",run.state.world_time))}})
		"move": return bridge.command("dev_edit",{"kind":"move","payload":{"entity_id":int(args.get("id",-1)),"position":vector(args.get("pos",[0,0])),"angle":float(args.get("angle",0))}})
		"input":
			var previous := _intent
			_intent = Intent.new()
			_intent.has_cursor = args.get("has_cursor",true)
			_intent.cursor = vector(args.get("cursor",[0,0]))
			_intent.pen = vector(args.get("pen",args.get("cursor",[0,0])))
			_intent.press = previous.press or args.get("press",false)
			_intent.alt_press = previous.alt_press or args.get("alt_press",false)
			_intent.hero_press = previous.hero_press or args.get("hero",false)
			_intent.pen_release = args.get("release",false)
			_intent.touch = args.get("touch",false)
			return {"ok":true}
		"route":
			var points := PackedVector2Array()
			for point in args.get("points",[]): points.append(vector(point))
			if points.size()<2: return {"ok":false,"message":"ルートには2点以上必要です"}
			_route_play = {"points":points,"n":0,"frames":clampi(ceili(maxf(float(args.get("draw_seconds",0.5)),run.cfg.draw_confirm_delay)/DT),1,3600)}
			return {"ok":true}
		"pin":
			var position := vector(args.get("pos",[0,0]))
			var result: Dictionary = bridge.command("dev_edit",{"kind":"pin","payload":{"value":bool(args.get("value",false)),"position":position}})
			if result.ok: pinned = position if args.get("value",false) else null
			return result
		"ship": return bridge.command("dev_edit",{"kind":"ship","payload":{"position":vector(args.get("pos",[0,0])),"gauge":float(args.get("gauge",run.state.gauge))}})
		"invincible","time","level": return bridge.command("dev_edit",{"kind":kind,"payload":{"value":args.get("value")}})
		"schedule":
			var entries: Array = args.get("entries",[]).duplicate(true)
			for entry: Dictionary in entries:
				entry.position = vector(entry.get("pos",[0,0]))
				entry.erase("pos")
			var result: Dictionary = bridge.command("dev_edit",{"kind":"schedule","payload":{"entries":entries}})
			if result.ok: schedule = args.get("entries",[]).duplicate(true)
			return result
		"parameter","armor_paint","config","boss_parameter","boss_appearance": return _edit_definition(args,kind)
		"post_max": return bridge.command("dev_edit",{"kind":"post_max","payload":{"stacks":args.get("stacks",{})}})
		"loadout":
			if args.get("reset",false):
				for item in [["weapon",run.state.weapons],["trait",run.state.traits]]:
					for id in item[1]: bridge.command("dev_remove_"+item[0],{"id":String(id)})
				return {"ok":true}
			return bridge.command("dev_grant_equipment",{"id":String(args.get("id","")),"kind":String(args.get("kind","weapon")),"levels":clampi(int(args.get("level",1)),1,100)})
		"command": return bridge.command(String(args.get("name","")),args.get("args",{}))
		"field": return _add_field(String(args.get("kind","")),vector(args.get("pos",[0,0])),float(args.get("radius",0)))
		"phase_set":
			if args.get("ids",[]).is_empty(): return {"ok":true}
			var next := _source.duplicate(true) as RuntimeStage
			next.phases.clear()
			for id in args.ids:
				if not ContentManager.phases.has(StringName(id)): return {"ok":false,"message":"時間帯の定義がありません"}
				next.phases.append(ContentManager.phases[StringName(id)].duplicate(true))
			var built: Error = BUILDER.build(next,_config,_output,"実験場".sha256_text(),_definitions,_formation_sources,_boss_definitions,null,_boss_programs)
			if built!=OK: return {"ok":false,"message":"時間帯の定義を生成できません"}
			var bundle := _read_generated()
			if bundle.is_empty(): return {"ok":false,"message":"時間帯の生成物を読み込めません"}
			var result: Dictionary = bridge.replace_scenario("phase_set",{},bundle.bytes)
			if result.ok:
				_source = next
				run.state.data.stage = next
			return result
	return {"ok":false,"message":"この実験命令はまだ移行していません: "+kind}

func _apply_meta(levels: Dictionary) -> Dictionary:
	for id in levels:
		if String(id) not in PROJECTION.META_IDS: return {"ok":false,"message":"永続強化の種類が不正です"}
	var packed := PackedInt32Array()
	for id in PROJECTION.META_IDS: packed.append(clampi(int(levels.get(id,0)),0,100))
	return bridge.command("dev_edit",{"kind":"meta","payload":{"levels":packed,"profile":ProfileManager.for_cpp(true,levels)}})

func _read_generated() -> Dictionary:
	var path := _output.path_join("stage_%d.json" % _source.index)
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	return LOADER.read_bundle(path,index.input_sha256)

## 次の技再生にだけ使う値を、本番と同じ変換・版検査で取り替える。
func set_boss_program(id: String, program: Dictionary) -> Dictionary:
	var previous: Dictionary = _boss_programs
	_boss_programs = _boss_programs.duplicate()
	_boss_programs[id] = preload("res://tools/content/build_boss_program.gd").snapshot(program)
	var result := _edit_definition({"type":id},"boss_program")
	if not result.get("ok",false): _boss_programs = previous
	return result

func _edit_definition(args: Dictionary, kind := "parameter") -> Dictionary:
	var next := _definitions.duplicate(true)
	var bosses := _boss_definitions.duplicate(true)
	var config := _config.duplicate(true) as GameConfig
	var type := StringName(args.get("type",""))
	var key := String(args.get("key",""))
	if kind=="config":
		if key not in ["base_attack","base_max_speed","draw_length","draw_confirm_delay","draw_time_scale","trace_radius","boss_hp","boss_armor"]: return {"ok":false}
		config.set(key,maxf(0.001,float(args.get("value",0.0))))
	elif kind in ["boss_parameter","boss_appearance","boss_program"]:
		if kind=="boss_parameter" and (not args.has("value") or typeof(args.value) not in [TYPE_INT,TYPE_FLOAT,TYPE_BOOL]): return {"ok":false}
		if not bosses.has(type): return {"ok":false,"message":"このボスの編集はまだ移行していません"}
		var definition: BossDef = bosses[type]
		if kind=="boss_program": pass
		elif kind=="boss_appearance":
			if not BossDef.valid_part_appearance(args.get("parts")): return {"ok":false}
			definition.part_appearance = args.parts.duplicate(true)
		elif key.begins_with("params.") and definition.params.has(key.trim_prefix("params.")):
			definition.params[key.trim_prefix("params.")] = safe_parameter(key.trim_prefix("params."),args.get("value",0))
		elif key in ["speed","radius","accel","turn","xp","weak_arc","hitstop_multiplier"]:
			definition.set(key,maxf(0.0 if key=="hitstop_multiplier" else 0.01,float(args.get("value",0))))
		else: return {"ok":false}

	else:
		if not next.has(type): return {"ok":false}
		var definition: EnemyDef = next[type]
		if kind=="armor_paint":
			if not ARMOR_PAINT.valid_palettes(args.get("colors")): return {"ok":false}
			definition.armor_colors = args.colors.duplicate(true)
		elif key.begins_with("visual."):
			var field := key.trim_prefix("visual.")
			if not EnemyDef.VISUAL_LIMITS.has(field): return {"ok":false}
			if args.get("inherit",false): definition.visual_settings.erase(field)
			else: definition.visual_settings[field] = clampf(float(args.value),EnemyDef.VISUAL_LIMITS[field].x,EnemyDef.VISUAL_LIMITS[field].y)
		elif key.begins_with("params."):
			if not definition.params.has(key.trim_prefix("params.")): return {"ok":false}
			definition.params[key.trim_prefix("params.")] = safe_parameter(key.trim_prefix("params."),args.value)
		elif key in ["hp","toughness","armor","speed","radius","accel","turn","xp","weak_arc","attack_weight","hitstop_multiplier"]:
			definition.set(key,clampi(int(args.value),-1,1) if key=="toughness" else maxf(0.01 if key in ["hp","radius"] else 0.0,float(args.value)))
		else: return {"ok":false}
	var built: Error = BUILDER.build(_source,config,_output,"実験場".sha256_text(),next,_formation_sources,bosses,scene.cpp_resources,_boss_programs)
	if built!=OK: return {"ok":false,"message":"編集の定義を生成できません"}
	var path := _output.path_join("stage_%d.json" % _source.index)
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var bundle: Dictionary = LOADER.read_bundle(path,index.input_sha256)
	if bundle.is_empty(): return {"ok":false,"message":"編集の定義を読み込めません"}
	var result: Dictionary = bridge.replace_definition("config" if kind=="config" else String(type),bundle.bytes,"config" if kind=="config" else "boss_parameter" if kind in ["boss_parameter","boss_appearance","boss_program"] else "parameter")
	if result.ok:
		_definitions = next
		_boss_definitions = bosses
		run.bosses.definitions = bosses
		_config = config
		run.cfg = config
		run.enemies.data.definitions = next
		# 外観は表示側だけが所有し、当たりに効く値は上の定義置換で適用する。
		scene.cpp_resources = bundle.resources
		if scene.view!=null:
			var presentation: RunPresentation = scene.view.get_node("RunPresentation")
			var scope := ContentResourceScope.new()
			scope.resources = presentation.cpp_scope.resources.duplicate()
			scope.warmup_complete = true
			var palettes := {}
			for entry: Dictionary in bundle.resources.visuals:
				if entry.role!=6: continue
				var enemy_index: int = entry.id-6
				if enemy_index<0 or enemy_index>=_source.resources.enemy_ids.size(): continue
				var id := StringName(_source.resources.enemy_ids[enemy_index])
				if not next.has(id): continue
				if not palettes.has(entry.path): palettes[entry.path] = []
				palettes[entry.path].append(next[id].armor_colors)
			for visual_path in palettes:
				var look: EnemyLook = scope.resources[visual_path]
				var colors: Array[Dictionary] = []
				colors.assign(palettes[visual_path])
				scope.provide(visual_path,ARMOR_PAINT.prepare_look(load(look.source_path),colors))
			presentation.cpp_resources = bundle.resources
			presentation.cpp_scope = scope
			presentation.frame_view.replace_lab_visuals(scope,bundle.resources.visuals)
	return result

func row_for_id(id: int) -> int:
	var t = run.enemies.table
	for i in t.alive.size():
		if t.alive[i] and not t.dead[i] and t.id[i] == id:
			return i
	return -1

func seek(target: int, instant := false) -> void:
	if not seeking and viewport!=null:
		_seek_view_mode = viewport.render_target_update_mode
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_seek_serial += 1
	var request := _seek_serial
	playing = false
	seeking = true
	var end := furthest
	target = clampi(target, 0, end)
	_cache_current()
	var nearest := -1
	for n in checkpoints.size():
		var item: Dictionary = checkpoints[n]
		if int(item.tick) <= target and item.key == _checkpoint_key(int(item.tick)) and (nearest < 0 or int(item.tick) > int(checkpoints[nearest].tick)):
			nearest = n
	if nearest >= 0:
		var item: Dictionary = checkpoints[nearest]
		checkpoints.remove_at(nearest)
		scene = item.scene
		run = item.run
		bridge = scene.bridge
		var restored: Dictionary = bridge.restore(int(item.checkpoint))
		bridge.release_checkpoint(int(item.checkpoint))
		if not restored.ok:
			last_error = restored
			_free_checkpoint(item)
			scene = null
			run = null
			await _rebuild()
			if request!=_seek_serial: return
			seeking = false
			_restore_seek_view()
			return
		_definitions = run.enemies.data.definitions
		_boss_definitions = run.bosses.definitions
		_config = run.cfg
		_source = item.source
		_formation_sources = item.get("formation_sources",[]).duplicate(true)
		scene.process_mode = Node.PROCESS_MODE_INHERIT
		if viewport != null and scene.get_parent() == null:
			viewport.add_child(scene)
		tick = int(item.tick)
		selected = int(item.get("selected", -1))
		_cursor = int(item.cursor)
		_state_key = item.key
		_intent = item.intent
		_route_play = item.get("route_play", {}).duplicate(true)
		pinned = item.get("pinned")
		schedule = item.schedule.duplicate(true)
		events.assign(item.events.duplicate(true))
		revision += 1
	else:
		await _rebuild()
	if request != _seek_serial:
		return
	var epoch := _epoch
	while tick < target:
		for n in mini(120,target-tick):
			var previous_tick := tick
			step()
			if tick==previous_tick:
				seeking = false
				_restore_seek_view()
				return
		# Reset と編集の復元は、完成した状態だけを次の描画へ渡す。
		if not instant:
			seek_progress.emit(float(tick) / maxf(1, target))
			await get_tree().process_frame
		if epoch != _epoch or request != _seek_serial:
			return
	furthest = end
	seeking = false
	_refresh_projection()
	bridge.collect_frame()
	_restore_seek_view()
	changed.emit()

## 最後に再生を始めた時刻の状態に戻す（配置は残す）。それ以降の記録は分岐として残し、そこから新しく遊べるようにする。
## 再生を始めた時刻に記録した入力とルートの再生も取り除く（始める前の状態に戻すため）。
func back_to_play_start() -> void:
	if seeking or not is_instance_valid(run):
		return
	playing = false
	_was_playing = false
	var at := mini(play_start, furthest)
	if furthest > at or history.any(func(e): return int(e.tick) == at and String(e.kind) in ["input", "route"]):
		branches.append({"name": current_branch, "history": history.duplicate(true), "end": furthest})
		branch_serial += 1
		current_branch = TranslationServer.translate("lab.message_549e9c3c03") % branch_serial
		history = history.filter(func(e): return int(e.tick) < at or (int(e.tick) == at and String(e.kind) not in ["input", "route"]))
		furthest = at
		_cursor = 0
		# 今の場面は消した記録を含むので、保存せずに作り直す
		if is_instance_valid(scene):
			if scene.get_parent() != null:
				scene.get_parent().remove_child(scene)
			scene.queue_free()
		scene = null
		run = null
	await seek(at, true)
	edit_undo.clear()
	edit_redo.clear()

func cancel_seek() -> void:
	_seek_serial += 1
	seeking = false
	playing = false
	_restore_seek_view()

func _restore_seek_view() -> void:
	if is_instance_valid(viewport): viewport.render_target_update_mode = _seek_view_mode

func _free_checkpoint(item: Dictionary) -> void:
	if not is_instance_valid(item.scene): return
	if item.scene.bridge!=null and item.has("checkpoint"): item.scene.bridge.release_checkpoint(int(item.checkpoint))
	item.scene.free()

func digest() -> String:
	var record: Dictionary = bridge.read_recording(false)
	var snapshot: Dictionary = bridge.read_lab()
	return str(hash(var_to_bytes([tick,record.value if record.ok else {},snapshot.value if snapshot.ok else {}])))

func _checkpoint_key(at: int) -> String:
	return str(hash(var_to_bytes([spec, history.filter(func(e): return int(e.tick) <= at)])))

## 状態をコピーせず、停止したシーン全体を保持する。HSM とタイムラインも同じ実体で復元する。
func _cache_current() -> void:
	if not is_instance_valid(scene) or not is_instance_valid(run): return
	var held: Dictionary = bridge.checkpoint()
	if not held.ok:
		last_error = held
		return
	checkpoints.append({"checkpoint":held.value,"formation_sources":_formation_sources.duplicate(true),"source":_source,"scene": scene, "run": run, "tick": tick, "cursor": _cursor, "intent": _intent, "route_play": _route_play.duplicate(true), "pinned": pinned,
		"schedule": schedule.duplicate(true), "events": events.duplicate(true), "selected": selected, "key": _state_key})
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	# 表示枠に残すと、保存した過去の場面も重なって描かれる
	if viewport != null and scene.get_parent() == viewport:
		viewport.remove_child(scene)
	scene = null
	run = null
	while checkpoints.size() > 3:
		var old: Dictionary = checkpoints.pop_front()
		_free_checkpoint(old)

func definition_for_row(row: int) -> Resource:
	var t = run.enemies.table
	return run.bosses.definitions.get(t.type[row]) if t.is_boss[row] else t.def[row]

static func safe_parameter(key: String, value):
	if value is bool: return value
	var number := float(value)
	if not is_finite(number): return 0.01
	if key in ["telegraph", "windup", "life", "recover"] or key.ends_with("_interval") or key.ends_with("_time") or key.ends_with("_delay") or key.ends_with("_cd"):
		number = clampf(number, 0.01, 100000)
	if key in ["volley", "layers", "strikes", "stars", "rubble_count", "shards", "lump_max", "throw_min", "death_split"]:
		number = clampf(number, 1, 512)
	return int(number) if value is int else number

func undo_edit() -> void:
	await _restore_edit(edit_undo, edit_redo)

func redo_edit() -> void:
	await _restore_edit(edit_redo, edit_undo)

## 値の編集は現在のランに逆操作を適用する。移動や攻撃の時計は進め直さない。
## 逆操作も現在時刻の命令として残し、記録の再生でも同じ結果にする。
func _inverse_edit(kind: String, args: Dictionary) -> Array:
	var previous := args.duplicate(true)
	match kind:
		"armor_paint":
			var def = run.enemies.def_of(StringName(args.get("type", "")))
			if def == null: return []
			previous.colors = def.armor_colors.duplicate(true)
		"boss_appearance":
			var def: BossDef = run.bosses.definitions.get(StringName(args.get("type", "")))
			if def == null: return []
			previous.parts = def.part_appearance.duplicate(true)
		"parameter", "boss_parameter":
			var type := StringName(args.get("type", ""))
			var def: Resource = run.bosses.definitions.get(type) if kind == "boss_parameter" else run.enemies.def_of(type)
			if def == null: return []
			var key := String(args.get("key", ""))
			if key.begins_with("visual.") and def is EnemyDef:
				var field := key.trim_prefix("visual.")
				previous.value = def.visual_value(field, 1.0)
				previous.inherit = not def.visual_settings.has(field)
			elif key.begins_with("params."):
				previous.value = def.params.get(key.trim_prefix("params."), 0)
			else:
				previous.value = def.get(key)
		"move":
			var row := row_for_id(int(args.get("id", -1)))
			if row < 0: return []
			previous.pos = FORMAT.plain(run.enemies.table.pos[row])
			previous.angle = run.enemies.table.facing[row]
		"config": previous.value = run.cfg.get(String(args.get("key", "")))
		"invincible": previous.value = run.ship.invincible
		"time": previous.value = run.state.time
		"hero": previous.id = String(run.state.hero_power)
		"meta": previous.level = int(run.state.meta_override.get(String(args.get("id","")),0))
		"level": previous.value = run.state.level
		"schedule": previous.entries = schedule.duplicate(true)
		_: return []
	return [{"kind": kind, "args": previous}]

func _restore_edit(source: Array[Dictionary], target: Array[Dictionary]) -> void:
	if source.is_empty() or seeking or not is_instance_valid(run): return
	var item: Dictionary = source.back()
	var commands: Array = item.get("commands",[])
	if not commands.is_empty():
		# 逆命令が拒否されたときは履歴・分岐・undo列もそのまま残す。
		for command: Dictionary in commands:
			if not _apply(command.kind,command.args): return
		source.pop_back()
		target.append({"history":history.duplicate(true),"end":furthest,"tick":tick,"commands":item.get("opposite",[]),"opposite":commands})
		if tick<furthest:
			branches.append({"name":current_branch,"history":history.duplicate(true),"end":furthest})
			branch_serial += 1
			current_branch = tr("lab.message_549e9c3c03") % branch_serial
			history = history.filter(func(e): return int(e.tick)<=tick)
			furthest = tick
		for command: Dictionary in commands:
			history.append({"tick":tick,"kind":command.kind,"args":command.args.duplicate(true)})
		_cursor = history.size()
		_state_key = _checkpoint_key(tick)
		revision += 1
		changed.emit()
		return
	source.pop_back()
	target.append({"history":history.duplicate(true),"end":furthest,"tick":tick,"commands":[],"opposite":[]})
	# 配置・削除などは同じ時刻まで非表示で復元し、編集時刻には戻さない。
	var at := tick
	var end := furthest
	var inputs := history.slice(item.history.size()).filter(func(e): return String(e.kind) == "input" and int(e.tick) <= at)
	history.assign(item.history)
	for input: Dictionary in inputs:
		var index := 0
		while index < history.size() and int(history[index].tick) <= int(input.tick): index += 1
		history.insert(index, input)
	furthest = maxi(at, int(item.end))
	await seek(at, true)
	furthest = maxi(end, furthest)

func _exit_tree() -> void:
	_seek_serial += 1
	for checkpoint in checkpoints:
		_free_checkpoint(checkpoint)
	checkpoints.clear()
	if is_instance_valid(scene) and scene.get_parent()!=self: scene.free()
	bridge = null
	run = null
