## 単独ボス試遊だけの手動実行。技本体・命中判定は役者の本番経路を使う。
extends RefCounted

var actor
var active := false
var message := ""
var requested := ""
var _saved: Dictionary = {}
var _camera := preload("res://scripts/bosses/draco_cinematic_state.gd").new()
var _origin := Vector2.ZERO
## 手動実行に対応するボス
const BOSSES: Array[StringName] = [&"monoceros", &"draco", &"centaurus", &"canis_major"]

func bind(value: BossActor) -> bool:
	if not OS.is_debug_build() or value == null or not value.run_state.lab_mode or value.def.id not in BOSSES:
		return false
	actor = value
	_origin = actor.table.pos[actor.body]
	return true

func moves() -> Array:
	return actor.action_rules.techniques if is_instance_valid(actor) and actor.action_rules != null else []

func unavailable(id: String, phase: int) -> String:
	if not is_instance_valid(actor) or not actor.body_alive(): return "ボスが不在または撃破済みです。ボスを選び直してください。"
	if actor.action_rules == null: return "実行用の技リソースがありません。"
	if actor.mode in [&"final", &"finale", &"defeated"]: return "決着中は実行できません。ボスを選び直してください。"
	if actor.mode in [&"entrance", &"phase", &"transition", &"deep"]: return "登場・形態移行中です。完了後に実行してください。"
	var move: Resource
	for item in moves():
		if String(item.technique) == id: move = item; break
	if move == null: return "未登録の技: " + id
	var maximum := 3 if actor.def.id == &"draco" else 2
	if phase < 1 or phase > maximum: return "存在しない形態です。"
	if actor.def.id == &"draco":
		if move.make_runner() == null: return "技の実行スクリプトがありません。"
		if id == "picaro_wall":
			for type in move.values().get("wall_candidates", [&"telescope", &"lynx"]):
				if actor.ctx.enemies.def_of(StringName(type)) == null: return "必要な敵リソースがありません: " + String(type)
	return ""

func execute(id: String, phase: int) -> bool:
	message = unavailable(id, phase)
	if not message.is_empty(): return false
	if not active:
		_saved = {"selection": actor.selection_enabled, "phase": actor.phase,
			"steering_locked": actor.run_state.steering_locked, "guard": actor.table.guard[actor.body]}
		_camera.capture(actor)
		active = true
	_cleanup()
	actor.selection_enabled = false
	# 発動条件の形態から外れた形態を選んでいても、技が使える形態へ寄せて撃つ。
	var gate: Dictionary = actor.action_rules.conditions.get(id, {})
	var maximum := 3 if actor.def.id == &"draco" else 2
	_set_phase(clampi(phase, int(gate.get("min_phase", 1)), int(gate.get("max_phase", maximum))))
	actor.table.pos[actor.body] = _origin
	actor.table.facing[actor.body] = 0.0
	var distance := (float(gate.get("min", 0.0)) + minf(1400.0, float(gate.get("max", 600.0)))) * 0.5
	var point := _origin + Vector2.from_angle(deg_to_rad(float(gate.get("angle", 0.0)))) * distance
	actor.run_state.ship_pos = point
	actor.run_state.ship_vel = Vector2.ZERO
	actor.run_state.enemy_aim = point
	actor.run_state.view_center = point
	requested = id
	if not actor.start_attack(StringName(id)):
		message = "開始できませんでした: " + id
		return false
	message = "実行: " + id
	if id == "inhale": message += " / 吸引対象なし：吐出彗星0（噛み付き・光線を実行）"
	return true

func finish() -> void:
	if not active: return
	if is_instance_valid(actor) and actor.has_body():
		_cleanup()
		_camera.restore(actor)
		actor.run_state.steering_locked = _saved.steering_locked
		actor.table.guard[actor.body] = _saved.guard
		_set_phase(_saved.phase)
		actor.selection_enabled = _saved.selection
		actor.flow_runner.configure(actor.flow_runner.flow)
	active = false
	_saved.clear()
	requested = ""
	message = "手動実行終了・通常AI"

## 形態を切り替える。形態ごとに技の性能を持つボスは、性能も切り替える。
func _set_phase(phase: int) -> void:
	actor.phase = phase
	if actor.has_method("_apply_phase"): actor._apply_phase()

func _cleanup() -> void:
	# この画面が所有する単独ボスのセッション。次の試行へ残留弾を持ち越さない。
	if actor.flow_adapter != null: actor.flow_adapter.cancel()
	actor.cancel_attack()
	actor.flow_runner.active = false
	if actor.def.id == &"draco":
		actor.entrance.cancel()
		actor.cycle.cancel()
		actor.picaro.pause(true)
		actor.picaro.clear()
		for host: Node in actor.retained_fields:
			if is_instance_valid(host):
				host.attack_field.clear_effects()
				host.queue_free()
		actor.retained_fields.clear()
		for rock: FieldSystem.Rock in actor.placed_meteors:
			rock.destroyed = true
			if actor.ctx.enemies.is_same(rock.row, rock.row_id): actor.ctx.enemies.mark_dead(rock.row)
		actor.placed_meteors.clear()
		actor.closing_walls.clear()
		actor.attack_token = 0
		actor.reset_pose()
		actor._presentation.effects.clear()
	elif actor.def.id == &"monoceros":
		actor.phase_pending = false
		actor.reposition = 0.0
		actor.stuck_body = null
		actor.stuck_time = 0.0
		actor.locked = false
		actor._cooldown = 0.0
	else:
		actor.phase_pending = false
		actor._cooldown = 0.0
		if actor.mode in [&"retreat", &"turn"]: actor.mode = &"idle"
		if actor.def.id == &"canis_major": actor._end_ring()
	actor.technique = &""
	actor.table.vel[actor.body] = Vector2.ZERO
	actor.table.charge[actor.body] = 0.0
	actor.ctx.projectiles.clear_hostile()
	actor.ctx.enemies.cleanup()
	actor.ctx.projectiles.lab_context = 0
	var director = actor.ctx.projectiles.director
	for key in director.owners.keys():
		var group: Dictionary = director.groups[director.owners[key]]
		if int(group.id) == actor.body_id: director.cancel_attack(key, actor.body_id)
	director.advance(actor.run_state.world_time, actor.ctx.enemies)
	actor.run_state.steering_locked = _saved.get("steering_locked", false)

func status() -> String:
	if not is_instance_valid(actor) or not actor.has_body(): return "ボスなし"
	return "%s / 形態%d / %s / %s" % ["手動" if active else "AI", actor.phase, actor.mode,
		String(actor.technique) if actor.technique != &"" else "待機"]
