## おおいぬ座を置いた試遊用の実験場。共有ステージ・セーブ・本番の強さを変更しない。
extends "res://gyms/enemy_lab/enemy_lab.gd"
const Phase := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS.Phase

@export var trial_ship_position := Vector2(700, 0)
@export_range(1.0, 20.0) var trial_attack_multiplier := 6.0
@export var trial_invincible := true
## ボスが連れて出る群れとは別に、ボスのまわりへ置く猟犬の群れの数（1群れは猟犬の pack_count 体）
@export_range(0, 10) var trial_extra_packs := 0
## normal は共通フローの選択。技のIDを選ぶと、その技だけを繰り返す
@export_enum("normal", "pounce", "command", "sirius", "howl", "stream", "bay", "hunt_pounce", "sirius_flame", "blaze", "relay", "hunt", "nova") var trial_technique := "normal"
## 有効なら、始めてすぐシリウスを強く輝かせて第2形態へ移る
@export var trial_phase_two := false

var capture_path := ""
var capture_at := 3.0
var _clock := 0.0
var _capturing := false
const MANUAL := preload("res://gyms/boss_technique_debug.gd")
var manual
var _repeat_started := false
var _phase_requested := false
var _repeat_id: StringName = &""

func _ready() -> void:
	await super._ready()
	if not OS.is_debug_build(): return
	await session.reset({"empty": true, "stage": 3, "ship_pos": [trial_ship_position.x, trial_ship_position.y],
		"invincible": trial_invincible, "config": {"base_attack": ContentManager.base.base_attack * trial_attack_multiplier}})
	session.perform("boss", {"type": "canis_major", "pos": [0, 0]})
	var boss_entity: int = session._selected_id
	for j in trial_extra_packs:
		var at := Vector2.from_angle(TAU * j / maxf(trial_extra_packs, 1)) * 350.0
		session.perform("spawn", {"type": "hound", "pos": [at.x, at.y]})
	if trial_technique != "normal": _only(StringName(trial_technique))
	if trial_phase_two: _phase_two()
	# 画面確認用。--canis-capture=<png> と --canis-capture-at=<秒> で一枚保存して終了する。
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--canis-capture="): capture_path = arg.trim_prefix("--canis-capture=")
		if arg.begins_with("--canis-capture-at="): capture_at = float(arg.trim_prefix("--canis-capture-at="))
		if arg.begins_with("--canis-tech="): _only(StringName(arg.trim_prefix("--canis-tech=")))
		if arg.begins_with("--canis-packs="):
			for j in int(arg.trim_prefix("--canis-packs=")):
				var at := Vector2.from_angle(TAU * j / 8.0) * 350.0
				session.perform("spawn", {"type": "hound", "pos": [at.x, at.y]})
		if arg == "--canis-pin": session.perform("pin",{"value":true,"pos":trial_ship_position})
		if arg == "--canis-phase2": _phase_two()
	session._selected_id = boss_entity
	manual = MANUAL.new()
	if not manual.bind(session,"canis_major"):
		push_error("おおいぬ座の試行を準備できません")
		return
	if _phase_requested: manual.action("phase_two")
	_set_mode(3)
	_refresh()

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
	print("[canis-visual] ", "PASS " if error == OK else "FAIL ", capture_path,
		" mode=",body.get("mode",-1)," tech=",manual.state().get("technique","") if manual!=null else "",
		" distance=",roundi(distance)," led=",body.get("led",[]).size(),
		" led_hound_max_hp=",body.led[0].max_hp if not body.get("led",[]).is_empty() else 0.0," ship_hp=",session.run.state.ship_hp)
	get_tree().quit(0 if error == OK else 1)

## 選択した技は制作コピーと本番C++の手動入口で繰り返す。
func _only(id: StringName) -> void:
	_repeat_id = id
	if id in [&"sirius_flame", &"sirius", &"blaze", &"relay", &"hunt", &"nova"]: _phase_two()

func _repeat_technique() -> void:
	if _repeat_id.is_empty() or manual == null or not session.playing: return
	if session.run.state.phase != Phase.Play or manual.attack_playing(): return
	if not _repeat_started:
		_repeat_started = manual.execute(String(_repeat_id),2 if _phase_requested else 1)
	else: manual.repeat()

## HPを変えず、本番の形態移行を依頼する。
func _phase_two() -> void:
	_phase_requested = true
