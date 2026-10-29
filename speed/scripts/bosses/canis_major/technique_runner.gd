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
	if kind() in [&"pounce", &"sirius"]:
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
	if kind() == &"sirius":
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
	execute(host)

func execute(_host: CanisMajorBoss) -> void: pass

func _active_tick(host: CanisMajorBoss, _dt: float) -> void:
	host.table.vel[host.body] = Vector2.ZERO

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

func kind() -> StringName:
	return &""

func body_pose(_host: CanisMajorBoss) -> Dictionary:
	return {}
