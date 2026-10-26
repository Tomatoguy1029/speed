## ケンタウルス座を置いた試遊用の実験場。共有ステージ・セーブ・本番の強さを変更しない。
extends "res://gyms/enemy_lab/enemy_lab.gd"

@export var trial_ship_position := Vector2(900, 0)
@export_range(1.0, 20.0) var trial_attack_multiplier := 6.0
@export var trial_invincible := true
## ボスと機体の間に置く守る雑魚の数
@export_range(0, 40) var trial_defenders := 8
## normal は共通フローの選択。技のIDを選ぶと、その技だけを繰り返す
@export_enum("normal", "volley", "power_shot", "rain") var trial_technique := "normal"

func _ready() -> void:
	await super._ready()
	if not OS.is_debug_build(): return
	await session.reset({"empty": true, "stage": 2, "ship_pos": [trial_ship_position.x, trial_ship_position.y],
		"invincible": trial_invincible, "config": {"base_attack": ContentManager.base.base_attack * trial_attack_multiplier}})
	session.perform("boss", {"type": "centaurus", "pos": [0, 0]})
	var toward := trial_ship_position.normalized() if trial_ship_position.length() > 1.0 else Vector2.RIGHT
	for j in trial_defenders:
		var spread := (j - (trial_defenders - 1) * 0.5) * 48.0
		var at := toward * 320.0 + toward.orthogonal() * spread
		session.perform("spawn", {"type": "defender", "pos": [at.x, at.y]})
	if trial_technique != "normal": _only(StringName(trial_technique))
	# 画面確認用。--centaurus-capture=<png> と --centaurus-capture-at=<秒> で一枚保存して終了する。
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--centaurus-capture="): capture_path = arg.trim_prefix("--centaurus-capture=")
		if arg.begins_with("--centaurus-capture-at="): capture_at = float(arg.trim_prefix("--centaurus-capture-at="))
		if arg.begins_with("--centaurus-tech="): _only(StringName(arg.trim_prefix("--centaurus-tech=")))
		if arg == "--centaurus-pin": session.pinned = trial_ship_position
	_set_mode(3)
	_refresh()

var capture_path := ""
var capture_at := 3.0
var _clock := 0.0
var _capturing := false

func _process(delta: float) -> void:
	super._process(delta)
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

## 編集元を変更せず、選んだ技だけが候補になる試遊用のフローにする。
func _only(id: StringName) -> void:
	var actor: BossActor = session.run.bosses.actor
	if actor == null: return
	var program: Resource = ResourceLoader.load("res://.content/boss_centaurus.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	var rules: Resource = program.data.rules
	for node in rules.node_ids():
		var binding: Dictionary = rules.graph_nodes.get(node, {}).duplicate()
		binding.source = rules.source_for(node)
		binding.connected = binding.source == String(id)
		rules.graph_nodes[node] = binding
	actor.configure_flow(program)
