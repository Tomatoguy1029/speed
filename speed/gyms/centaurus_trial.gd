## ケンタウルス座を置いた試遊用の実験場。共有ステージ・セーブ・本番の強さを変更しない。
extends "res://gyms/enemy_lab/enemy_lab.gd"
const Phase := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS.Phase

@export var trial_ship_position := Vector2(900, 0)
@export_range(1.0, 20.0) var trial_attack_multiplier := 6.0
@export var trial_invincible := true
## 本体が連れて出て保つ守る雑魚の数。負数なら本体の設定を使う
@export_range(-1, 40) var trial_defenders := 8
## normal は共通フローの選択。技のIDを選ぶと、その技だけを繰り返す
@export_enum("normal", "volley", "power_shot", "rain", "rear_attack", "shower_chase", "shower_wall", "shower_path", "sail_run", "stomp", "fan_volley", "combo_shower_shot", "combo_rain_volley", "leap") var trial_technique := "normal"
## 有効なら、始めてすぐ帆を広げて第2形態へ移る
@export var trial_phase_two := false

func _ready() -> void:
	await super._ready()
	if not OS.is_debug_build(): return
	var boss_overrides := {"centaurus": {"params": {"guard_count": trial_defenders}}} if trial_defenders >= 0 else {}
	await session.reset({"empty": true, "stage": 2, "ship_pos": [trial_ship_position.x, trial_ship_position.y],
		"boss_overrides": boss_overrides, "invincible": trial_invincible, "config": {"base_attack": ContentManager.base.base_attack * trial_attack_multiplier}})
	session.perform("boss", {"type": "centaurus", "pos": [0, 0]})
	if trial_technique != "normal": _only(StringName(trial_technique))
	if trial_phase_two: _phase_two()
	# 画面確認用。--centaurus-capture=<png> と --centaurus-capture-at=<秒> で一枚保存して終了する。
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--centaurus-capture="): capture_path = arg.trim_prefix("--centaurus-capture=")
		if arg.begins_with("--centaurus-capture-at="): capture_at = float(arg.trim_prefix("--centaurus-capture-at="))
		if arg.begins_with("--centaurus-tech="): _only(StringName(arg.trim_prefix("--centaurus-tech=")))
		if arg == "--centaurus-pin": session.perform("pin",{"value":true,"pos":trial_ship_position})
		if arg == "--centaurus-rear": _place_behind()
		if arg == "--centaurus-phase2": _phase_two()
	manual = MANUAL.new()
	if not manual.bind(session,"centaurus"):
		push_error("ケンタウルス座の試行を準備できません")
		return
	if _rear_requested: _place_behind()
	if _phase_requested: manual.action("phase_two")
	_set_mode(3)
	_refresh()

const MANUAL := preload("res://gyms/boss_technique_debug.gd")
var manual
var _repeat_started := false
var _phase_requested := false
var _rear_requested := false
var _repeat_id: StringName = &""
var capture_path := ""
var capture_at := 3.0
var _clock := 0.0
var _capturing := false

func _process(delta: float) -> void:
	super._process(delta)
	_repeat_technique()
	if capture_path.is_empty() or _capturing: return
	session.playing = true
	if session.run.state.phase == Phase.Paused: session.bridge.command("resume",{})
	_clock += delta
	if _clock < capture_at: return
	_capturing = true
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(capture_path)
	var body: Dictionary = manual.body_snapshot() if manual != null else {}
	var distance: float = body.get("position",session.run.state.ship_pos).distance_to(session.run.state.ship_pos)
	print("[centaurus-visual] ", "PASS " if error == OK else "FAIL ",capture_path,
		" mode=",body.get("mode",-1)," tech=",manual.state().get("technique","") if manual!=null else "",
		" distance=",roundi(distance)," ship_hp=",session.run.state.ship_hp)
	get_tree().quit(0 if error == OK else 1)

## 背後攻撃の確認用。向き・開始位置はC++の制作命令で用意する。
func _place_behind() -> void:
	_rear_requested = true
	if manual == null: return
	var body: Dictionary = manual.state()
	if body.is_empty(): return
	var point: Vector2 = body.position - Vector2(220,0)
	manual.prepare(int(body.phase),point,true,float(body.guard),bool(body.steering_locked))
	session.perform("pin",{"value":true,"pos":point})

## HPを変えず、本番の形態移行を依頼する。
func _phase_two() -> void:
	_phase_requested = true

func _only(id: StringName) -> void:
	_repeat_id = id
	if id in [&"shower_path", &"sail_run"]: _phase_two()

func _repeat_technique() -> void:
	if _repeat_id.is_empty() or manual == null or not session.playing: return
	if session.run.state.phase != Phase.Play or manual.attack_playing(): return
	if not _repeat_started:
		if _repeat_id == &"leap":
			var body: Dictionary = manual.state()
			if body.is_empty(): return
			_repeat_started = manual.prepare(int(body.phase),body.position+Vector2(250,0),false,0.0,bool(body.steering_locked))
		else: _repeat_started = manual.execute(String(_repeat_id),2 if _phase_requested else 1)
		if not _repeat_started or _repeat_id != &"leap": return
	if _repeat_id in [&"leap",&"stomp"]:
		var body: Dictionary = manual.state()
		if body.is_empty(): return
		var point: Vector2 = body.position+Vector2.from_angle(float(body.facing))*(250.0 if _repeat_id==&"leap" else 200.0)
		session.perform("ship",{"pos":point})
		session.perform("pin",{"value":true,"pos":point})
	if _repeat_id == &"leap": manual.action("leap")
	else: manual.repeat()
