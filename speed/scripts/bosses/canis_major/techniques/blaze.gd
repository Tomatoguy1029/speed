## 燃える猟犬の公開値と動作。
@tool
extends BossTechnique

## 予告（秒）
@export_range(0,100000,0.01) var warn := 0.5:
	set(value):
		warn = value
		_values_dirty = true
## 使う猟犬の数
@export_range(0,100000,1) var count := 3:
	set(value):
		count = value
		_values_dirty = true
## 必要な猟犬の数
@export_range(0,100000,1) var min_hounds := 3:
	set(value):
		min_hounds = value
		_values_dirty = true
## 最初の点火時刻（秒）
@export_range(0,100000,0.01) var ignite_at := 0.5:
	set(value):
		ignite_at = value
		_values_dirty = true
## 点火の間隔（秒）
@export_range(0,100000,0.01) var ignite_step := 0.15:
	set(value):
		ignite_step = value
		_values_dirty = true
## 燃える猟犬の最高速
@export_range(0,100000,0.01) var run_speed := 430.0:
	set(value):
		run_speed = value
		_values_dirty = true
## 明滅へ移る距離
@export_range(0,100000,0.01) var stop_dist := 90.0:
	set(value):
		stop_dist = value
		_values_dirty = true
## 走る時間の上限（秒）
@export_range(0,100000,0.01) var max_run := 4.5:
	set(value):
		max_run = value
		_values_dirty = true
## 爆発前の明滅時間（秒）
@export_range(0,100000,0.01) var blink := 0.6:
	set(value):
		blink = value
		_values_dirty = true
## 爆発の半径
@export_range(0,100000,0.01) var explode_radius := 100.0:
	set(value):
		explode_radius = value
		_values_dirty = true
## ダメージ
@export_range(0,100000,0.01) var damage := 20.0:
	set(value):
		damage = value
		_values_dirty = true
## 硬直（秒）
@export_range(0,100000,0.01) var recover := 0.5:
	set(value):
		recover = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 12.0:
	set(value):
		cd = value
		_values_dirty = true

## 爆発のピクセル炎表示
@export var explosion_visual: PackedScene = preload("res://scenes/attacks/canis_fire_explosion.tscn"):
	set(value):
		explosion_visual = value
		_values_dirty = true

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/canis_major/technique_runner.gd":
	var values: Dictionary
	var age := 0.0
	var chosen: Array = []
	func kind() -> StringName: return &"blaze"
	func _begin_windup(host: CanisMajorBoss, r: Dictionary, _length: float) -> void:
		manual = true
		values = r
		host.mode = &"windup"
		host.table.vel[host.body] = Vector2.ZERO
		var rows: Array = []
		for i in host.led:
			if host._alive_hound(i) and not host.ring.has(i) and not host.lunging.has(i): rows.append(i)
		rows.sort_custom(func(a,b): return host.table.pos[a].distance_squared_to(host.run_state.ship_pos) < host.table.pos[b].distance_squared_to(host.run_state.ship_pos))
		for k in mini(int(r.count), rows.size()):
			var i := int(rows[k])
			chosen.append({"row": i, "id": host.table.id[i], "at": float(r.ignite_at) + k * float(r.ignite_step), "sent": false, "lit": false})
		host._cue(&"blaze_windup")
	func manual_tick(host: CanisMajorBoss, dt: float) -> void:
		age += dt
		host.table.vel[host.body] = Vector2.ZERO
		if age < float(values.warn) and host._moves[kind()].track_during_warn: host._face(host.run_state.enemy_aim, host.def.turn, dt)
		for item in chosen:
			if not valid_hound(host, item.row, item.id): continue
			if not item.sent and age >= float(item.at) - float(values.ignite_step):
				item.sent = true
				host.sirius_effects.transfers.append({"from": host.mouth(), "row": item.row, "id": item.id, "age": 0.0, "life": values.ignite_step})
			if not item.lit and age >= float(item.at):
				item.lit = true
				host.sirius_effects.ignite(item.row, values)
		if age >= maxf(float(values.warn), float(values.ignite_at) + maxf(0, chosen.size()-1) * float(values.ignite_step)):
			finish(host, float(values.recover))
	func windup_progress(_host: CanisMajorBoss) -> float: return clampf(age / maxf(float(values.warn),0.001),0,1)
	func body_pose(host: CanisMajorBoss) -> Dictionary:
		return {"glow": windup_progress(host) if host.mode == &"windup" else 0.0}
