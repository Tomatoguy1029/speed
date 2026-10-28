## 技に共通する予告・照準・終了処理。技のRunnerが継承する。
extends BossTechnique.Runner

func _begin_windup(host: CanisMajorBoss, r: Dictionary, length: float) -> void:
	host.mode = &"windup"
	host.locked = false
	host.attack_hit = false
	host.table.vel[host.body] = Vector2.ZERO
	host.aim_point = host.run_state.enemy_aim
	var anim := host.timeline.get_animation(&"attack")
	anim.length = length
	while anim.track_get_key_count(0) > 0: anim.track_remove_key(0, 0)
	if host.technique in [&"pounce", &"sirius"]:
		anim.track_insert_key(0, maxf(0.01, float(r.warn) - float(r.lock)), {"method": &"lock_aim", "args": []})
	anim.track_insert_key(0, float(r.warn), {"method": &"launch", "args": []})
	anim.track_insert_key(0, length, {"method": &"end_attack", "args": []})
	host.timeline.play(&"attack")
	host.timeline.advance(0.0)
	host._cue(&"telegraph")

## 構えの間は共通の遅延照準を追い、飛びかかりの着地点を決める。

func _aim(host: CanisMajorBoss, dt: float) -> void:
	host.aim_point = host.run_state.enemy_aim
	host._face(host.aim_point, host.def.turn, dt)

## 飛びかかりは着地点を、シリウスの光は向きを固定する。

func lock_aim(host: CanisMajorBoss) -> void:
	if host.mode != &"windup": return
	host.locked = true
	if host.technique == &"sirius":
		host.direction = Vector2.from_angle(host.table.facing[host.body])
	else:
		var to := host.aim_point - host.table.pos[host.body]
		host.direction = to.normalized() if to.length_squared() > 1.0 else Vector2.from_angle(host.table.facing[host.body])
		host.aim_point += host.direction * float(host.rule().overshoot)
	host._cue(&"aim_locked")

## 口元。シリウスの光はここから出る。

func launch(host: CanisMajorBoss) -> void:
	if host.mode != &"windup": return
	host.mode = &"active"
	host.attack_hit = false
	if host.technique == &"pounce":
		if not host.locked: host.lock_aim()
		host._cue(&"pounce")
		return
	if host.technique == &"sirius":
		host._fire_sirius()
		return
	if host.technique == &"howl":
		host._form_ring(host.rule())
		return
	var r := host.rule()
	var hounds = host._hounds()
	host._cue(&"command")
	if hounds == null: return
	host.lunging = PackedInt32Array(Array(host.led).filter(func(i): return not host.ring.has(i)))
	var until := host.run_state.world_time + float(r.lunge_time)
	for i in host.lunging:
		var speed_scale := float(r.lunge_speed) / maxf(host.table.speed[i], 1.0)
		var toward := (host.run_state.ship_pos - host.table.pos[i]).normalized()
		hounds.follow(i, host.table.pos[i] + toward * float(r.lunge_speed) * (float(r.lunge_time) + 0.2), until, speed_scale)
		# 加速を待たず、最初から全速で飛び出す。
		host.table.vel[i] = toward * float(r.lunge_speed)

## 固定した向きへ光を出す。光は猟犬などの敵をすり抜け、惑星・月で止まる。ボスが倒れると消える。

func _active_tick(host: CanisMajorBoss, dt: float) -> void:
	var r := host.rule()
	if host.technique == &"pounce":
		# 着地の時刻までに、残りの距離を等速で詰める。
		var from := host.table.pos[host.body]
		var left := float(r.warn) + float(r.active) - host.timeline.current_animation_position
		host._move_body((host.aim_point - from) * clampf(dt / maxf(left, dt), 0.0, 1.0), dt)
		host.table.facing[host.body] = host.direction.angle()
		if not host.attack_hit and host._ship_touches(from, host.table.pos[host.body], host.table.r[host.body]):
			host._hit_ship(float(r.damage))
		return
	if host.technique in [&"sirius", &"howl"]:
		host.table.vel[host.body] = Vector2.ZERO
		return
	# 号令：飛び出した猟犬に触れたら1回だけ当たる。
	if host.attack_hit: return
	for i in host.lunging:
		if not host._alive_hound(i): continue
		if host._ship_touches(host.table.pos[i], host.table.pos[i], host.table.r[i]):
			host._hit_ship(float(r.damage))
			return

func end_attack(host: CanisMajorBoss) -> void:
	if host.mode not in [&"windup", &"active"]: return
	host.timeline.stop()
	host.locked = false
	host.lunging.clear()
	host.table.vel[host.body] = Vector2.ZERO
	host.mode = &"recovery"
	host.recovery = float(host.rule().recover)
	host._cue(&"recovery_started")

func _ship_touches(host: CanisMajorBoss, from: Vector2, to: Vector2, radius: float) -> bool:
	var reach := radius + host.ctx.cfg.ship_radius
	var ship := host.run_state.ship_pos
	return Geometry2D.get_closest_point_to_segment(ship, from, to).distance_to(ship) <= reach \
		or Geometry2D.get_closest_point_to_segment(to, host._previous_ship, ship).distance_to(to) <= reach

func _hit_ship(host: CanisMajorBoss, damage: float) -> void:
	host.attack_hit = true
	host.ctx.ship.damage(damage * host.ctx.cfg.atk_scale, 0.0, host.technique, &"canis_major")

# ── 追跡と群れ ────────────────────────────────────────────

## 群れの先頭で、共通の遅延照準を追う。
