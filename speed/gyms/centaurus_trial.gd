## ケンタウルス座を置いた試遊用の実験場。共有ステージ・セーブ・本番の強さを変更しない。
extends "res://gyms/enemy_lab/enemy_lab.gd"

@export var trial_ship_position := Vector2(900, 0)
@export_range(1.0, 20.0) var trial_attack_multiplier := 6.0
@export var trial_invincible := true
## 本体が連れて出て保つ守る雑魚の数。負数なら本体の設定を使う
@export_range(-1, 40) var trial_defenders := 8
## normal は共通フローの選択。技のIDを選ぶと、その技だけを繰り返す
@export_enum("normal", "volley", "power_shot", "rain", "rear_attack", "shower_chase", "shower_wall", "stomp", "fan_volley", "combo_shower_shot", "combo_rain_volley", "leap") var trial_technique := "normal"
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
		if arg == "--centaurus-pin": session.pinned = trial_ship_position
		if arg == "--centaurus-rear": _place_behind()
		if arg == "--centaurus-phase2": _phase_two()
	_set_mode(3)
	_refresh()

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
	if session.run.state.phase == RunState.Phase.PAUSED: session.run.command(&"resume")
	_clock += delta
	if _clock < capture_at: return
	_capturing = true
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(capture_path)
	var actor = session.run.bosses.actor
	var distance: float = actor.table.pos[actor.body].distance_to(session.run.state.ship_pos) if actor != null and actor.has_body() else -1.0
	print("[centaurus-visual] ", "PASS " if error == OK else "FAIL ", capture_path, " mode=", actor.mode if actor != null else &"", " tech=", actor.technique if actor != null else &"", " distance=", roundi(distance), " ship_hp=", session.run.state.ship_hp)
	get_tree().quit(0 if error == OK else 1)

## 背後攻撃の確認用。ボスを機体と反対へ向け、背中の後ろに機体を固定して、最初の待ちをなくす。
func _place_behind() -> void:
	var actor: BossActor = session.run.bosses.actor
	if actor == null: return
	var at: Vector2 = actor.table.pos[actor.body]
	actor.table.facing[actor.body] = 0.0
	actor._cooldown = 0.0
	session.pinned = at - Vector2(220, 0)
	session.run.state.ship_pos = session.pinned
	session.run.state.enemy_aim = session.pinned

## HPを変えずに、次の待機で第2形態へ移らせる。
func _phase_two() -> void:
	var actor: BossActor = session.run.bosses.actor
	if actor != null: actor.phase_pending = true

## 単独再生は条件・区間にかかわらず繰り返す。試遊中の役者だけを変更する。
func _only(id: StringName) -> void:
	var actor := session.run.bosses.actor as CentaurusBoss
	if actor == null: return
	_repeat_id = id
	actor.selection_enabled = false
	actor.retreat_ready_at = INF
	actor.leap_ready_at = INF
	actor.cooldowns[&"stomp"] = INF

func _repeat_technique() -> void:
	if _repeat_id.is_empty() or not session.playing or session.run == null: return
	var actor := session.run.bosses.actor as CentaurusBoss
	if actor == null or not actor.body_alive() or actor.mode != &"idle" or actor.phase_pending: return
	if session.run.state.phase != RunState.Phase.PLAY: return
	if _repeat_id in [&"leap", &"stomp"]:
		var distance := 250.0 if _repeat_id == &"leap" else 200.0
		session.pinned = actor.table.pos[actor.body] + Vector2.from_angle(actor.table.facing[actor.body]) * distance
		session.run.state.ship_pos = session.pinned
		session.run.state.enemy_aim = session.pinned
	if _repeat_id == &"leap": actor._begin_leap()
	else: actor.start_attack(_repeat_id)
