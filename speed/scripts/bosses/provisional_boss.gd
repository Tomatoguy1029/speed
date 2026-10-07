## 仮のボス戦艦（仕様書 10）。機体を直接追い、予告のあと扇状に弾を撃つ。
extends BossActor

var _fire_t := 0.0

func _on_bound() -> void:
	_fire_t = float(def.params.fire_interval) * 0.5

func sim_tick(_real_dt: float, dt: float) -> void:
	if dt <= 0.0:
		return
	var s := run_state
	var aim := s.enemy_aim
	var d := aim - body.pos
	var dist := maxf(d.length(), 1.0)
	body.vel += (d / dist * body.speed - body.vel) * minf(1.0, def.accel * dt)
	body.facing += clampf(Geom.angle_diff(d.angle(), body.facing), -def.turn * dt, def.turn * dt)
	var from := body.pos
	body.pos += body.vel * dt
	manager.field.collide_enemy(body, from)
	if body.hit_cd > 0.0:
		body.hit_cd -= dt
	if body.flash > 0.0:
		body.flash -= dt
	_fire_t -= dt
	var tele: float = def.params.telegraph
	body.charge = 1.0 - maxf(0.0, _fire_t) / tele if _fire_t < tele else 0.0
	if _fire_t <= 0.0:
		_fire_t = def.params.fire_interval
		var n: int = def.params.volley
		var spread: float = def.params.spread
		var base := (aim - body.pos).angle()
		for i in n:
			manager.fire(base + (float(i) / (n - 1) - 0.5) * spread, def.params.bullet_speed, def.params)
