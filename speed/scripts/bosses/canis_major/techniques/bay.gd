## 通常入口を切り替えるまで使う互換Runner。
@tool
extends "res://scripts/data_types/boss_techniques/canis_major/bay.gd"

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/canis_major/technique_runner.gd":
	var members: Dictionary = {}
	var values: Dictionary = {}
	var started := 0.0
	var jump: RefCounted
	var heading := 0.0

	func kind() -> StringName: return &"bay"

	func _begin_windup(host: CanisMajorBoss, r: Dictionary, _length: float) -> void:
		manual = true
		values = r
		started = host.clock
		host.mode = &"windup"
		host.table.vel[host.body] = Vector2.ZERO
		heading = host.run_state.ship_vel.angle() if host.run_state.ship_vel.length_squared() > 1.0 else host.run_state.ship_heading.angle()
		var rows: Array = []
		for i in host.led:
			if host._alive_hound(i) and not host.ring.has(i): rows.append(i)
		rows.sort_custom(func(a, b): return host.table.pos[a].distance_squared_to(host.run_state.ship_pos) < host.table.pos[b].distance_squared_to(host.run_state.ship_pos))
		rows = rows.slice(0, int(r.count))
		var rng := host.run_state.rng
		for k in rows.size():
			var i := int(rows[k])
			members[i] = {"id": host.table.id[i], "angle": TAU * k / maxf(rows.size(), 1) + rng.randf_range(-0.15, 0.15), "phase": rng.randf() * TAU, "cool": rng.randf_range(0.6, 1.4), "bark": rng.randf(), "warn": -1.0, "nipping": false}
			if not host.lunging.has(i): host.lunging.append(i)
		host._cue(&"bay_windup")

	func manual_tick(host: CanisMajorBoss, dt: float) -> void:
		var r := values
		if host.clock - started < float(r.warn):
			host._face(host.run_state.enemy_aim, host.def.turn, dt)
			return
		if jump == null:
			host.mode = &"bay"
			if host.clock - started - float(r.warn) >= float(r.pounce_at):
				jump = host._moves[&"pounce"].make_runner()
				host.used_at[&"pounce"] = host.clock
				jump.start_jump(host, host._rules[&"pounce"], 1)
			elif host.table.pos[host.body].distance_to(host.run_state.ship_pos) > float(r.approach_stop):
				host._chase_tick(dt)
			else:
				host.table.vel[host.body] = Vector2.ZERO
		update_pack(host, dt)
		if jump != null and jump.step(host, dt):
			cancel(host)
			finish(host, float(host._rules[&"pounce"].recover))

	func update_pack(host: CanisMajorBoss, dt: float) -> void:
		var hounds = host._hounds()
		if hounds == null: return
		var r := values
		if host.run_state.ship_vel.length_squared() > 1.0: heading = host.run_state.ship_vel.angle()
		var active := 0
		for entry in members.values():
			if float(entry.warn) >= 0.0 or entry.nipping: active += 1
		tick_lunges(host)
		for i: int in members.keys():
			var item: Dictionary = members[i]
			if not valid_hound(host, i, item.id):
				members.erase(i)
				host.lunging.erase(i)
				continue
			# 走り終えた猟犬も、この技が終わるまでは隊形へ戻さない。
			if not host.lunging.has(i): host.lunging.append(i)
			if item.nipping:
				if shots.has(i): continue
				item.nipping = false
				item.cool = float(r.nip_cd)
				host.table.vel[i] = Vector2.from_angle(host.table.facing[i]) * float(r.nip_after_speed)
				active -= 1
			item.angle = float(item.angle) + float(r.orbit) * dt
			item.cool = float(item.cool) - dt
			item.bark = float(item.bark) - dt
			var rel := absf(Geom.angle_diff(float(item.angle), heading))
			var front := rel < deg_to_rad(float(r.front_angle))
			var back := rel > deg_to_rad(float(r.back_angle))
			if float(item.warn) >= 0.0:
				if host.clock >= float(item.warn):
					item.warn = -1.0
					item.nipping = true
					launch_hound(host, i, float(r.nip_speed), float(r.nip_time), float(r.nip_damage))
					host._cue(&"bay_nip", host.table.pos[i])
				else:
					hounds.steer_follow(i, host.table.pos[i], host.run_state.ship_pos, host.run_state.world_time + host.FOLLOW_HOLD, r)
				continue
			if back and float(item.cool) <= 0.0 and active < int(r.nip_max):
				item.warn = host.clock + float(r.nip_warn)
				hounds.mark(i, host.run_state.world_time + float(r.nip_warn))
				host._cue(&"bay_nip_mark", host.table.pos[i])
				active += 1
				hounds.steer_follow(i, host.table.pos[i], host.run_state.ship_pos, host.run_state.world_time + host.FOLLOW_HOLD, r)
				continue
			if front and float(item.bark) <= 0.0:
				item.bark = host.run_state.rng.randf_range(float(r.bark_min), float(r.bark_max))
				host._cue(&"bay_bark", host.table.pos[i])
			var radius := float(r.r_front) if front else float(r.r_back) if back else float(r.r_side)
			var wobble := Vector2(sin(host.clock * 2.0 + float(item.phase)), cos(host.clock * 1.7 + float(item.phase))) * float(r.wobble)
			var goal := host.run_state.ship_pos + Vector2.from_angle(float(item.angle)) * radius + wobble
			hounds.steer_follow(i, goal, host.run_state.ship_pos, host.run_state.world_time + host.FOLLOW_HOLD, r)

	func cancel(host: CanisMajorBoss) -> void:
		super(host)
		var hounds = host._hounds()
		for i: int in members:
			if hounds != null and host.table.id[i] == members[i].id: hounds.release_order(i)
			host.lunging.erase(i)
		members.clear()

	func windup_progress(host: CanisMajorBoss) -> float:
		return jump.windup_progress(host) if jump != null else clampf((host.clock - started) / maxf(float(values.warn), 0.001), 0, 1)

	func body_pose(host: CanisMajorBoss) -> Dictionary:
		if host.mode not in [&"windup", &"active", &"bay"]: return {}
		if jump != null: return jump.body_pose(host)
		return {"bay": true, "shout": host.mode == &"windup"}
