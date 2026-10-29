## 突進の値と動き。
@tool
extends BossTechnique

## 攻撃の継続時間
@export_range(0,100000,0.01) var active := 0.85:
	set(value):
		active = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 3.0:
	set(value):
		cd = value
		_values_dirty = true
## ダメージ
@export_range(0,100000,0.01) var damage := 25.0:
	set(value):
		damage = value
		_values_dirty = true
## 移動距離
@export_range(0,100000,0.01) var distance := 1250.0:
	set(value):
		distance = value
		_values_dirty = true
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 1.5:
	set(value):
		recover = value
		_values_dirty = true
## 予告（秒）
@export_range(0,100000,0.01) var warn := 1.05:
	set(value):
		warn = value
		_values_dirty = true

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/monoceros/technique_runner.gd":
	func _tick_strike(host: MonocerosBoss, dt: float, prior: PackedVector2Array) -> void:
		var step := host.direction * float(host.rule().distance) / float(host.rule().active) * dt
		var from := host.table.pos[host.body]
		var to := from + step
		var horn_from := from + host.direction * host.horn_length()
		var hit = host.ctx.field.first_body_hit(horn_from, horn_from + step, float(host.def.params.horn_width) * 0.5) if host.technique != &"lance" else null
		var body_hit = host.ctx.field.first_body_hit(from, to, host.table.r[host.body])
		if hit != null and hit.body != null and hit.body.is_planet and (body_hit == null or float(hit.t) <= float(body_hit.t)):
			host.table.pos[host.body] = from.lerp(to, hit.t)
			host._damage_shape(prior, host.horn_points())
			host.stuck_body = hit.body
			host.stuck_offset = host.table.pos[host.body] - host.stuck_body.pos
			host.stuck_time = float(host.def.params.stuck_time)
			host.combat_trace.finish("interrupted", "horn_stuck_in_planet")
			host.mode = &"stuck"
			host.combo_pending = false
			host.passes_left = 0
			host.table.vel[host.body] = Vector2.ZERO
			host.timeline.stop()
			host._cue(&"horn_stuck")
			return
		if body_hit != null:
			host.combat_trace.stage("interruption", {"reason": "body_obstacle"})
			host.table.pos[host.body] = from.lerp(to, body_hit.t)
			host._damage_shape(prior, host.horn_points())
			host.combo_pending = false
			host.passes_left = 0
			host.end_strike()
			return
		host.table.pos[host.body] = to
		host.table.vel[host.body] = step / dt
		host._damage_shape(prior, host.horn_points())

	func kind() -> StringName:
		return &"charge"
