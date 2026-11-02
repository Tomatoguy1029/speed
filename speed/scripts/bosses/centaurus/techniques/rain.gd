## 通常入口を切り替えるまで使う互換Runner。編集値は専用Resourceへ置く。
@tool
extends "res://scripts/data_types/boss_techniques/centaurus/rain.gd"

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/centaurus/technique_runner.gd":
	func begin_rain(host: CentaurusBoss) -> void:
		if host.mode != &"windup": return
		host.timeline.stop()
		host._clear_rain()
		host.mode = &"rain"
		host._rain_left = int(host.rule().traces)
		host._rain_next_at = host.clock
		host._cue(&"rain_started")

	func _clear_rain(host: CentaurusBoss) -> void:
		host.rain_traces.clear()
		host.rain_arrows.clear()
		host._rain_left = 0

	func _trace_duration(host: CentaurusBoss, r: Dictionary) -> float:
		return float(r.trace_length) / maxf(float(r.trace_speed), 1.0)

	## トレースの道すじの、走り始めから距離 s の点。円弧で、曲がりの合計が trace_bend になる。

	func trace_point(host: CentaurusBoss, trace: Dictionary, s: float) -> Vector2:
		var r := host.rule()
		var start: Vector2 = trace.start
		var direction: Vector2 = trace.dir
		var bend := float(r.trace_bend)
		if absf(bend) < 0.001: return start + direction * s
		var radius := float(r.trace_length) / bend
		var normal := direction.orthogonal() * float(trace.turn)
		var center := start + normal * radius
		return center + (start - center).rotated(-float(trace.turn) * s / radius)

	## 自機の進む向きの前方に始点を置き、弧が自機の位置を通るように向けて走らせる。

	func _start_trace(host: CentaurusBoss, r: Dictionary) -> void:
		var ship := host.run_state.ship_pos
		var heading := host.run_state.ship_vel.normalized() if host.run_state.ship_vel.length() > 60.0 else (ship - host.table.pos[host.body]).normalized()
		var start := ship + heading * float(r.forward)
		var trace := {"start": start, "dir": (ship - start).normalized(), "turn": 1.0 if host.rain_traces.size() % 2 == 0 else -1.0,
			"t0": host.clock, "next_drop": 0.0, "landed": 0.0, "hit": false}
		# 弧の上で、始点から自機までの直線距離にあたる点を自機へ重ねる。
		var bend := float(r.trace_bend)
		var reach := float(r.forward)
		if absf(bend) >= 0.001:
			var radius := float(r.trace_length) / absf(bend)
			reach = 2.0 * radius * asin(minf(1.0, reach / (2.0 * radius)))
		var probe := host.trace_point(trace, reach)
		trace.dir = (trace.dir as Vector2).rotated(Geom.angle_diff((ship - start).angle(), (probe - start).angle()))
		host.rain_traces.append(trace)
		host._cue(&"rain_trace")

	func _rain_tick(host: CentaurusBoss, dt: float) -> void:
		host._position_tick(dt)
		var r := host.rule()
		var length := float(r.trace_length)
		var speed := maxf(float(r.trace_speed), 1.0)
		if host._rain_left > 0 and host.clock >= host._rain_next_at:
			host._start_trace(r)
			host._rain_left -= 1
			host._rain_next_at = host.clock + host._trace_duration(r) + float(r.trace_gap)
		var delay := float(r.get("drop_delay", 0.0))
		var fall := float(r.fall)
		var radius := float(r.circle_radius)
		var gap := maxf(float(r.arrow_gap), 1.0)
		var all_landed := true
		for trace in host.rain_traces:
			var run := host.clock - float(trace.t0)
			var head := clampf(run * speed, 0.0, length)
			# 円が通った所へ、drop_delay 遅れて矢を落とし始める。
			while float(trace.next_drop) <= head:
				var center := host.trace_point(trace, trace.next_drop)
				for k in int(r.arrows_per_step):
					var offset := Vector2.from_angle(host.run_state.rng.randf() * TAU) * sqrt(host.run_state.rng.randf()) * radius
					host.rain_arrows.append(Vector3(center.x + offset.x, center.y + offset.y, float(trace.t0) + float(trace.next_drop) / speed + delay))
				trace.next_drop = float(trace.next_drop) + gap
			# 着弾の円は drop_delay と fall 遅れて同じ道すじを進む。前回からの区間で機体に触れたら1回だけ当たる。
			var land := clampf((run - delay - fall) * speed, 0.0, length)
			if not trace.hit and land > float(trace.landed):
				var a := host.trace_point(trace, trace.landed)
				var b := host.trace_point(trace, land)
				host.combat_trace.evaluate()
				var ship := host.run_state.ship_pos
				if Geometry2D.get_closest_point_to_segment(ship, a, b).distance_to(ship) <= radius + host.ctx.cfg.ship_radius:
					trace.hit = true
					host.combat_trace.damage(float(r.damage) * host.ctx.cfg.atk_scale, 0.0, &"arrow", &"centaurus")
			trace.landed = land
			if land < length: all_landed = false
		var expire := fall + float(r.linger) + host.RAIN_OUT
		var spent := 0
		while spent < host.rain_arrows.size() and host.rain_arrows[spent].z + expire < host.clock: spent += 1
		if spent > 0: host.rain_arrows = host.rain_arrows.slice(spent)
		if host._rain_left == 0 and all_landed and host.rain_arrows.is_empty():
			host._clear_rain()
			host.finish_technique()

	# ── 移動 ──────────────────────────────────────────────────

	func kind() -> StringName:
		return &"rain"
