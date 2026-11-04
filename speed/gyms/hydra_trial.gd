## Hydra を置いた試遊用の実験場。共有ステージ・セーブ・本番の強さを変更しない。
extends "res://gyms/enemy_lab/enemy_lab.gd"
const Phase := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS.Phase

@export var trial_ship_position := Vector2(400, 0)
@export_range(1.0, 20.0) var trial_attack_multiplier := 6.0
@export var trial_invincible := true
const MANUAL := preload("res://gyms/boss_technique_debug.gd")
var manual
var inspect_tech: StringName = &""
var inspect_attack: StringName = &""
var capture_path := ""
var capture_at := 1.0
var capturing := false
var inspect_clock := 0.0
var reviewing := false
var review_next := 0.3
var review_counts := {}

func _ready() -> void:
	await super._ready()
	if not OS.is_debug_build(): return
	var args := OS.get_cmdline_user_args()
	reviewing = args.has("--hydra-review")
	var multiplier := trial_attack_multiplier * (1000.0 if reviewing else 1.0)
	await session.reset({"empty":true,"stage":4,"ship_pos":[trial_ship_position.x,trial_ship_position.y],
		"invincible":trial_invincible,"hero":"hercules","config":{"base_attack":ContentManager.base.base_attack*multiplier}})
	session.perform("boss",{"type":"hydra","pos":[0,0]})
	manual = MANUAL.new()
	if not manual.bind(session,"hydra"):
		push_error("うみへび座の試行を準備できません")
		return
	if args.has("--hydra-inspect"):
		session.perform("loadout",{"reset":true})
		session.perform("pin",{"value":true,"pos":trial_ship_position})
		for arg in args:
			if arg.begins_with("--hydra-capture="): capture_path=arg.trim_prefix("--hydra-capture=")
			if arg.begins_with("--hydra-capture-at="): capture_at=float(arg.trim_prefix("--hydra-capture-at="))
			if arg.begins_with("--hydra-tech="): inspect_tech=StringName(arg.trim_prefix("--hydra-tech="))
			if arg.begins_with("--hydra-attack="): inspect_attack=StringName(arg.trim_prefix("--hydra-attack="))
		var id := String(inspect_attack if not inspect_attack.is_empty() else inspect_tech)
		if not id.is_empty():
			if not manual.execute(id,4 if id in ["swarm","grid"] else 3,true): push_error(manual.message)
			session.perform("pin",{"value":true,"pos":session.run.state.ship_pos})
	if args.has("--hydra-split") and not manual.active:
		manual.prepare(3,trial_ship_position,true,0.0,false)
		manual.action("separate")
	if args.has("--hydra-arena-edge"):
		var body: Dictionary = manual.body_snapshot()
		if body.has("arena"):
			var point: Vector2 = body.arena.end-Vector2(220,220)
			session.perform("ship",{"pos":point})
			session.perform("pin",{"value":true,"pos":point})
	_set_mode(3)
	if reviewing:
		session.perform("pin",{"value":false,"pos":Vector2.ZERO})
		session.live_input=Callable()
	_refresh()

func _notification(what: int) -> void:
	if OS.get_cmdline_user_args().has("--hydra-inspect") and what==NOTIFICATION_APPLICATION_FOCUS_OUT: return
	super._notification(what)

func _process(delta: float) -> void:
	super._process(delta)
	if manual == null or session.run == null: return
	manual.advance()
	if not capture_path.is_empty() or reviewing:
		session.playing=true
		if session.run.state.phase==Phase.Paused: session.bridge.command("resume",{})
		inspect_clock+=delta
	var body: Dictionary = manual.body_snapshot()
	if reviewing:
		if body.is_empty() or body.get("mode",0)>=4:
			var complete: bool = review_counts.has(3) and review_counts.has(5) and review_counts.has(8) and review_counts.has("separated")
			print("[hydra-review] ","PASS " if complete else "FAIL ","描線による首の増加・分離・不死の首の撃破; phases=",review_counts)
			get_tree().quit(0 if complete else 1)
			return
		if inspect_clock>40.0:
			print("[hydra-review] FAIL 時間内に終了しない; hp=",body.get("hp",0)," count=",body.get("count",0)," split=",body.get("separated",false)," phase=",session.run.state.phase)
			get_tree().quit(1)
			return
		review_counts[body.get("count",0)]=true
		if body.get("separated",false): review_counts["separated"]=true
		if inspect_clock>=review_next and body.get("growth_left",0.0)<=0 and body.get("separation_left",0.0)<=0 and not session.run.state.tracing and not session.run.state.drawing:
			var at: Vector2 = body.get("bearer",{}).get("position",body.position) if body.get("separated",false) else body.position
			var start := at-Vector2(180,0)
			session.perform("ship",{"pos":start,"gauge":1.0})
			session.perform("route",{"points":[start,at+Vector2(180,0)],"draw_seconds":0.2})
			review_next=inspect_clock+2.0
	if not capture_path.is_empty() and not capturing and not body.is_empty() and inspect_clock>=capture_at:
		capturing=true
		await RenderingServer.frame_post_draw
		var error := get_viewport().get_texture().get_image().save_png(capture_path)
		print("[hydra-visual] ","PASS " if error==OK else "FAIL ",capture_path," tech=",manual.state().get("technique","")," effects=",body.get("effects",[]).size()," world=",session.run.state.world_time," phase=",session.run.state.phase)
		get_tree().quit(0 if error==OK else 1)
