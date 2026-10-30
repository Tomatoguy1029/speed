## 焼き焦がす光の公開値と動作。
@tool
extends BossTechnique

## ビームを撃つ回数
@export_range(0,100000,1) var shots := 3:
	set(value):
		shots = value
		_values_dirty = true
## 次の射撃までの間（秒）
@export_range(0,100000,0.01) var shot_gap := 0.25:
	set(value):
		shot_gap = value
		_values_dirty = true
## 予告（秒）
@export_range(0,100000,0.01) var warn := 0.7:
	set(value):
		warn = value
		_values_dirty = true
## 発射前に向きを固定する時間（秒）
@export_range(0,100000,0.01) var lock := 0.3:
	set(value):
		lock = value
		_values_dirty = true
## 先読みする時間（秒）
@export_range(0,100000,0.01) var lead := 0.3:
	set(value):
		lead = value
		_values_dirty = true
## 照準中の旋回（ラジアン毎秒）
@export_range(0,100000,0.01) var aim_turn := 3.0:
	set(value):
		aim_turn = value
		_values_dirty = true
## ビームの長さ
@export_range(0,100000,0.01) var beam_length := 1300.0:
	set(value):
		beam_length = value
		_values_dirty = true
## ビームの太さ
@export_range(0,100000,0.01) var beam_width := 40.0:
	set(value):
		beam_width = value
		_values_dirty = true
## ビームの時間（秒）
@export_range(0,100000,0.01) var beam_time := 0.35:
	set(value):
		beam_time = value
		_values_dirty = true
## 焼け跡の判定開始（秒）
@export_range(0,100000,0.01) var trail_delay := 0.35:
	set(value):
		trail_delay = value
		_values_dirty = true
## 焼け跡が消える時刻（発射からの秒）
@export_range(0,100000,0.01) var trail_time := 3.2:
	set(value):
		trail_time = value
		_values_dirty = true
## 焼け跡の判定の太さ
@export_range(0,100000,0.01) var trail_width := 18.0:
	set(value):
		trail_width = value
		_values_dirty = true
## 焼け跡のダメージ
@export_range(0,100000,0.01) var trail_damage := 10.0:
	set(value):
		trail_damage = value
		_values_dirty = true
## ダメージ
@export_range(0,100000,0.01) var damage := 20.0:
	set(value):
		damage = value
		_values_dirty = true
## 硬直（秒）
@export_range(0,100000,0.01) var recover := 1.0:
	set(value):
		recover = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 12.0:
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
	var aim: BeamAim
	var values: Dictionary
	var shot := 0
	var gap_left := 0.0
	var trailed := false
	func kind() -> StringName: return &"sirius"
	func _begin_windup(host: CanisMajorBoss, r: Dictionary, _length: float) -> void:
		manual = true
		values = r
		start_shot(host)
	func start_shot(host: CanisMajorBoss) -> void:
		aim = BeamAim.new()
		trailed = false
		aim.begin(host, {"warn": values.warn, "lock": values.lock, "lead": values.lead, "turn": values.aim_turn, "length": values.beam_length, "width": values.beam_width, "time": values.beam_time, "damage": values.damage})
	func manual_tick(host: CanisMajorBoss, dt: float) -> void:
		host.table.vel[host.body] = Vector2.ZERO
		if gap_left > 0.0:
			gap_left -= dt
			if gap_left <= 0.0: start_shot(host)
			return
		var done := aim.step(host, dt)
		if aim.fired and not trailed:
			trailed = true
			host.sirius_effects.add_trail(aim.result, values)
		if not done: return
		shot += 1
		if shot >= int(values.shots): finish(host, float(values.recover))
		else: gap_left = maxf(0.001, float(values.shot_gap))
	func windup_progress(_host: CanisMajorBoss) -> float: return aim.progress() if aim != null else 0.0
	func body_pose(host: CanisMajorBoss) -> Dictionary:
		return {"glow": windup_progress(host), "gather": host.mode == &"windup"}
