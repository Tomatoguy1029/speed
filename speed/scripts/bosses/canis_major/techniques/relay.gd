## 光を継ぐ群れの公開値と動作。
@tool
extends BossTechnique

## 予告（秒）
@export_range(0,100000,0.01) var warn := 0.8:
	set(value):
		warn = value
		_values_dirty = true
## 必要な猟犬の数
@export_range(0,100000,1) var min_hounds := 6:
	set(value):
		min_hounds = value
		_values_dirty = true
## 猟犬を送り出す間隔（秒）
@export_range(0,100000,0.01) var interval := 0.25:
	set(value):
		interval = value
		_values_dirty = true
## 猟犬ごとの予告（秒）
@export_range(0,100000,0.01) var each_warn := 0.6:
	set(value):
		each_warn = value
		_values_dirty = true
## 猟犬のビームの長さ
@export_range(0,100000,0.01) var hound_beam_length := 900.0:
	set(value):
		hound_beam_length = value
		_values_dirty = true
## 猟犬のビームの太さ
@export_range(0,100000,0.01) var hound_beam_width := 12.0:
	set(value):
		hound_beam_width = value
		_values_dirty = true
## 猟犬のビームの時間（秒）
@export_range(0,100000,0.01) var hound_beam_time := 0.22:
	set(value):
		hound_beam_time = value
		_values_dirty = true
## 猟犬のビームのダメージ
@export_range(0,100000,0.01) var hound_damage := 10.0:
	set(value):
		hound_damage = value
		_values_dirty = true
## 締めの予告（秒）
@export_range(0,100000,0.01) var final_warn := 1.1:
	set(value):
		final_warn = value
		_values_dirty = true
## 締めの発射前の固定時間（秒）
@export_range(0,100000,0.01) var final_lock := 0.35:
	set(value):
		final_lock = value
		_values_dirty = true
## 締めの旋回（ラジアン毎秒）
@export_range(0,100000,0.01) var final_turn := 6.0:
	set(value):
		final_turn = value
		_values_dirty = true
## 締めのビームの長さ
@export_range(0,100000,0.01) var final_length := 1500.0:
	set(value):
		final_length = value
		_values_dirty = true
## 締めのビームの太さ
@export_range(0,100000,0.01) var final_width := 44.0:
	set(value):
		final_width = value
		_values_dirty = true
## 締めのビームの時間（秒）
@export_range(0,100000,0.01) var final_time := 0.7:
	set(value):
		final_time = value
		_values_dirty = true
## 締めのダメージ
@export_range(0,100000,0.01) var final_damage := 26.0:
	set(value):
		final_damage = value
		_values_dirty = true
## 硬直（秒）
@export_range(0,100000,0.01) var recover := 1.6:
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
	var values: Dictionary
	var started := 0.0
	var ordered := false
	var final_aim: BeamAim
	var items: Array = []
	var last_fire := 0.0
	func kind() -> StringName: return &"relay"
	func _begin_windup(host: CanisMajorBoss, r: Dictionary, _length: float) -> void:
		manual = true
		values = r
		started = host.clock
		host.mode = &"windup"
		host.table.vel[host.body] = Vector2.ZERO
		for i in host.led:
			if host._alive_hound(i) and not host.ring.has(i) and not host.lunging.has(i):
				items.append({"row": i, "id": host.table.id[i], "marked": false, "fired": false})
				host.sirius_effects.tint_hound(i, host.run_state.world_time + float(r.warn), host.SIRIUS_COLOR)
		host._cue(&"relay_windup")
	func manual_tick(host: CanisMajorBoss, dt: float) -> void:
		host.table.vel[host.body] = Vector2.ZERO
		if not ordered:
			if host._moves[kind()].track_during_warn: host._face(host.run_state.enemy_aim, host.def.turn, dt)
			if host.clock - started < float(values.warn): return
			ordered = true
			for k in range(items.size()-1,0,-1):
				var j := host.run_state.rng.randi_range(0,k)
				var old = items[k]
				items[k] = items[j]
				items[j] = old
			for k in items.size():
				items[k].at = host.clock + k * float(values.interval)
			last_fire = host.clock + maxf(0,items.size()-1) * float(values.interval) + float(values.each_warn)
		host.sirius_effects.warnings.clear()
		for item in items:
			var i := int(item.row)
			if not valid_hound(host,i,item.id): continue
			if not item.marked and host.clock >= float(item.at):
				item.marked = true
				item.from = host.table.pos[i]
				item.angle = (host.run_state.ship_pos - host.table.pos[i]).angle()
				host.lunging.append(i)
				host._hounds().release_order(i)
				host._hounds().quiet(i, host.run_state.world_time + float(values.each_warn), Vector2.ZERO)
				host.table.vel[i] = Vector2.ZERO
				host.table.facing[i] = item.angle
				host._hounds().mark(i, host.run_state.world_time + float(values.each_warn))
				host._cue(&"relay_mark", host.table.pos[i])
			if not item.marked or item.fired: continue
			if host.clock < float(item.at) + float(values.each_warn):
				host.sirius_effects.warnings.append({"from": item.from, "angle": item.angle, "length": values.hound_beam_length, "width": 2.0, "progress": clampf((host.clock-float(item.at))/maxf(float(values.each_warn),0.001),0,1), "locked": false})
			else:
				item.fired = true
				host.sirius_effects.fire_beam(item.from, float(item.angle), float(values.hound_beam_length), float(values.hound_beam_width), float(values.hound_beam_time), float(values.hound_damage))
				host._hounds().release_order(i)
				host.lunging.erase(i)
				host._cue(&"relay_fire", host.table.pos[i])
		if final_aim == null and host.clock >= last_fire + float(values.interval) + 0.3:
			final_aim = BeamAim.new()
			final_aim.begin(host,{"warn": values.final_warn, "lock": values.final_lock, "turn": values.final_turn, "remaining_lead": true, "length": values.final_length, "width": values.final_width, "time": values.final_time, "damage": values.final_damage})
		if final_aim != null and final_aim.step(host,dt):
			cancel(host)
			finish(host,float(values.recover))
	func cancel(host: CanisMajorBoss) -> void:
		for item in items:
			host.sirius_effects.clear_tint(item.row,item.id)
			if valid_hound(host,item.row,item.id): host._hounds().release_order(item.row)
			host.lunging.erase(item.row)
		host.sirius_effects.warnings.clear()
	func windup_progress(host: CanisMajorBoss) -> float:
		return final_aim.progress() if final_aim != null else clampf((host.clock-started)/maxf(float(values.warn),0.001),0,1)
	func body_pose(host: CanisMajorBoss) -> Dictionary:
		return {"shout": not ordered, "glow": windup_progress(host) if host.mode == &"windup" else 0.0}
