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

## 複数の猟犬と本体を並行して進める技だけ、世界時間で個別に更新する。
var manual := false
var shots: Dictionary = {}
var sequence: Array = []
var sequence_start := 0.0
var last_launch := 0.0

func manual_tick(_host: CanisMajorBoss, _dt: float) -> void: pass

func windup_progress(_host: CanisMajorBoss) -> float: return 0.0

func cancel(host: CanisMajorBoss) -> void:
	var hounds = host._hounds()
	if hounds != null:
		for item in sequence:
			if host.table.id[item.row] == item.id: hounds.release_order(item.row)
		for i in shots:
			host.lunging.erase(i)
			if host.table.id[i] == shots[i].id: hounds.release_order(i)
	shots.clear()
	sequence.clear()

func finish(host: CanisMajorBoss, recover: float) -> void:
	host.timeline.stop()
	host.locked = false
	host.table.vel[host.body] = Vector2.ZERO
	host.mode = &"recovery"
	host.recovery = recover
	host._cue(&"recovery_started")

func begin_sequence(host: CanisMajorBoss, rows: Array, start: float, interval: float, warn: float) -> void:
	sequence.clear()
	sequence_start = start
	last_launch = start + maxf(0, rows.size() - 1) * interval + warn
	for k in rows.size():
		var i := int(rows[k])
		sequence.append({"row": i, "id": host.table.id[i], "mark": start + k * interval, "launch": start + k * interval + warn, "marked": false, "launched": false})

func valid_hound(host: CanisMajorBoss, i: int, id: int) -> bool:
	return host.table.alive[i] != 0 and host.table.dead[i] == 0 and host.table.id[i] == id

func tick_sequence(host: CanisMajorBoss, r: Dictionary, prefix: String) -> void:
	var hounds = host._hounds()
	if hounds == null: return
	for item in sequence:
		var i := int(item.row)
		if not valid_hound(host, i, item.id): continue
		if not item.marked and host.clock >= float(item.mark):
			item.marked = true
			hounds.mark(i, host.run_state.world_time + maxf(0.0, float(item.launch) - host.clock))
			host._cue(StringName(prefix + "_mark"), host.table.pos[i])
		if not item.launched and host.clock >= float(item.launch):
			item.launched = true
			launch_hound(host, i, float(r.lunge_speed), float(r.lunge_time), float(r.damage))
			host.ring.erase(i)
			host._cue(StringName(prefix + "_launch"), host.table.pos[i])

func launch_hound(host: CanisMajorBoss, i: int, speed: float, duration: float, damage: float) -> void:
	var hounds = host._hounds()
	if hounds == null: return
	hounds.release_order(i)
	var toward := (host.run_state.ship_pos - host.table.pos[i]).normalized()
	var until := host.run_state.world_time + duration
	hounds.follow(i, host.table.pos[i] + toward * speed * (duration + 0.2), until, speed / maxf(host.table.speed[i], 1.0))
	hounds.quiet(i, until, toward * speed)
	host.table.vel[i] = toward * speed
	host.table.facing[i] = toward.angle()
	if not host.lunging.has(i): host.lunging.append(i)
	shots[i] = {"id": host.table.id[i], "until": host.clock + duration, "from": host.table.pos[i], "hit": false, "damage": damage, "velocity": toward * speed}

func tick_lunges(host: CanisMajorBoss) -> void:
	var hounds = host._hounds()
	for i: int in shots.keys():
		var shot: Dictionary = shots[i]
		if not valid_hound(host, i, shot.id):
			shots.erase(i)
			host.lunging.erase(i)
			continue
		if not shot.hit and _ship_touches(host, shot.from, host.table.pos[i], host.table.r[i]):
			shot.hit = true
			host.ctx.ship.damage(float(shot.damage) * host.ctx.cfg.atk_scale, 0.0, host.technique, &"canis_major")
		shot.from = host.table.pos[i]
		if host.clock >= float(shot.until):
			if hounds != null: hounds.release_order(i)
			host.lunging.erase(i)
			shots.erase(i)
		else:
			# ボスの突進は固定した向き。群れの分離や通常の噛みつきに曲げられない。
			host.table.vel[i] = shot.velocity

func shuffled_pack(host: CanisMajorBoss) -> Array:
	var rows: Array = []
	for i in host.led:
		if host._alive_hound(i) and not host.ring.has(i): rows.append(i)
	for k in range(rows.size() - 1, 0, -1):
		var j := host.run_state.rng.randi_range(0, k)
		var row = rows[k]
		rows[k] = rows[j]
		rows[j] = row
	return rows

## 直線の光に共通する、追尾・固定・発射。各技が自分の値を渡す。
class BeamAim extends RefCounted:
	var cfg: Dictionary
	var age := 0.0
	var fired := false
	var done := false
	var result: Dictionary = {}
	func begin(host: CanisMajorBoss, values: Dictionary) -> void:
		cfg = values
		age = 0.0
		fired = false
		done = false
		host.mode = &"windup"
		host.locked = false
		host.table.vel[host.body] = Vector2.ZERO
		host._cue(&"telegraph")
	func step(host: CanisMajorBoss, dt: float) -> bool:
		if done: return true
		if not fired:
			if not host.locked:
				var lead := maxf(0.0, float(cfg.warn) - age) if cfg.get("remaining_lead", false) else float(cfg.get("lead", 0.0))
				if host._moves[host.technique].track_during_warn:
					host._face(host.run_state.ship_pos + host.run_state.ship_vel * lead, float(cfg.turn), dt)
				if age >= float(cfg.warn) - float(cfg.lock):
					host.locked = true
					host.direction = Vector2.from_angle(host.table.facing[host.body])
					host._cue(&"aim_locked")
			age += dt
			host.sirius_effects.warnings = [{"from": host.mouth(), "angle": host.table.facing[host.body], "length": cfg.length, "width": cfg.width, "progress": progress(), "locked": host.locked}]
			if age < float(cfg.warn): return false
			host.locked = true
			host.direction = Vector2.from_angle(host.table.facing[host.body])
			result = host.sirius_effects.fire_beam(host.mouth(), host.direction.angle(), float(cfg.length), float(cfg.width), float(cfg.time), float(cfg.damage))
			fired = true
			age = 0.0
			host.mode = &"active"
			host.sirius_effects.warnings.clear()
			host._cue(&"sirius")
			return false
		age += dt
		done = age >= float(cfg.time)
		return done
	func progress() -> float:
		return clampf(age / maxf(float(cfg.warn), 0.001), 0.0, 1.0) if not fired else 0.0
