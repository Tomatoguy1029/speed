## 追い立てと狙撃の公開値と動作。
@tool
extends BossTechnique

## 最後の猟犬の発進から構えまで（秒）
@export_range(0,100000,0.01) var gap := 0.1:
	set(value):
		gap = value
		_values_dirty = true
## 狙撃の予告（秒）
@export_range(0,100000,0.01) var aim_warn := 1.1:
	set(value):
		aim_warn = value
		_values_dirty = true
## 狙撃の発射前の固定時間（秒）
@export_range(0,100000,0.01) var aim_lock := 0.55:
	set(value):
		aim_lock = value
		_values_dirty = true
## 狙撃の先読み（秒）
@export_range(0,100000,0.01) var aim_lead := 0.35:
	set(value):
		aim_lead = value
		_values_dirty = true
## 照準中の旋回（ラジアン毎秒）
@export_range(0,100000,0.01) var aim_turn := 2.6:
	set(value):
		aim_turn = value
		_values_dirty = true
## ビームの長さ
@export_range(0,100000,0.01) var beam_length := 1500.0:
	set(value):
		beam_length = value
		_values_dirty = true
## ビームの太さ
@export_range(0,100000,0.01) var beam_width := 44.0:
	set(value):
		beam_width = value
		_values_dirty = true
## ビームの時間（秒）
@export_range(0,100000,0.01) var beam_time := 0.7:
	set(value):
		beam_time = value
		_values_dirty = true
## ダメージ
@export_range(0,100000,0.01) var damage := 26.0:
	set(value):
		damage = value
		_values_dirty = true
## 硬直（秒）
@export_range(0,100000,0.01) var recover := 1.6:
	set(value):
		recover = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 10.0:
	set(value):
		cd = value
		_values_dirty = true

## 炎のビームの見た目
@export var beam_visual: PackedScene = preload("res://scenes/attacks/canis_flame_beam.tscn"):
	set(value):
		beam_visual = value
		_values_dirty = true

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/canis_major/technique_runner.gd":
	var stream: RefCounted
	var aim: BeamAim
	var values: Dictionary
	func kind() -> StringName: return &"hunt"
	func _begin_windup(host: CanisMajorBoss, r: Dictionary, _length: float) -> void:
		manual = true
		values = r
		host.combo_pending = true
		host.used_at[&"stream"] = host.clock
		stream = host._moves[&"stream"].make_runner()
		stream._begin_windup(host,host._rules[&"stream"],0.0)
	func manual_tick(host: CanisMajorBoss, dt: float) -> void:
		stream.step(host,dt)
		if host.combo_pending and stream.sent and host.clock >= stream.last_launch + float(values.gap):
			host.combo_pending = false
			aim = BeamAim.new()
			aim.begin(host,{"warn": values.aim_warn, "lock": values.aim_lock, "lead": values.aim_lead, "turn": values.aim_turn, "length": values.beam_length, "width": values.beam_width, "time": values.beam_time, "damage": values.damage})
		if aim != null and aim.step(host,dt): finish(host,float(values.recover))
	func cancel(host: CanisMajorBoss) -> void:
		if stream != null: stream.cancel(host)
		host.sirius_effects.warnings.clear()
		host.combo_pending = false
	func windup_progress(host: CanisMajorBoss) -> float:
		return aim.progress() if aim != null else stream.windup_progress(host)
	func body_pose(host: CanisMajorBoss) -> Dictionary:
		return {"shout": aim == null and host.mode == &"windup", "glow": aim.progress() if aim != null else 0.0}
