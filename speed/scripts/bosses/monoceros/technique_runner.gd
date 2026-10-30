## 技に共通する予告・照準・終了処理。技のRunnerが継承する。
extends BossTechnique.Runner

func sequenced() -> bool:
	return false

func advance_sequence(_host: MonocerosBoss, _dt: float) -> void:
	pass

func horn_angle(host: MonocerosBoss) -> float:
	return host.table.facing[host.body]

func glow(_host: MonocerosBoss) -> float:
	return 0.0

func booster(_host: MonocerosBoss) -> float:
	return -1.0

func _begin_pass(host: MonocerosBoss) -> void:
	host.mode = &"windup"
	host.locked = false
	host.attack_hit = false
	host.table.vel[host.body] = Vector2.ZERO
	host.aim_point = host._strike_aim()
	host.direction = Vector2.from_angle(host.table.facing[host.body] + (PI if kind() == &"kick" else 0.0))
	if kind() == &"kick" and not host.aim_point.is_equal_approx(host.table.pos[host.body]):
		host.direction = (host.aim_point - host.table.pos[host.body]).normalized()
	var r := host.rule()
	var anim := host.timeline.get_animation(&"attack")
	anim.length = float(r.warn) + float(r.active)
	while anim.track_get_key_count(0) > 0: anim.track_remove_key(0, 0)
	anim.track_insert_key(0, maxf(0.01, float(r.warn) - float(host.def.params.lock_lead)), {"method": &"lock_aim", "args": []})
	anim.track_insert_key(0, float(r.warn), {"method": &"launch_strike", "args": []})
	anim.track_insert_key(0, anim.length, {"method": &"end_strike", "args": []})
	host.timeline.play(&"attack")
	host.timeline.advance(0.0)
	host._cue(&"telegraph")

func _aim(host: MonocerosBoss, dt: float) -> void:
	host.aim_point = host._strike_aim()
	if kind() == &"kick":
		host.direction = (host.aim_point - host.table.pos[host.body]).normalized()
		return
	var wanted := (host.aim_point - host.table.pos[host.body]).angle()
	var prior := host.table.facing[host.body]
	host.table.facing[host.body] = rotate_toward(prior, wanted, host.def.turn * dt)
	host.turn_motion = Geom.angle_diff(host.table.facing[host.body], prior) / maxf(dt, 0.001)
	host.direction = Vector2.from_angle(host.table.facing[host.body])

func _strike_aim(host: MonocerosBoss, attack: StringName = &"", lead := -1.0) -> Vector2:
	# ボス固有の捕捉。選択時・予告中だけ現在位置と速度から接触時点を狙う。
	if attack == &"": attack = host.technique
	var velocity := host.run_state.ship_vel
	var target := host.run_state.ship_pos + velocity * (float(host.def.params.lock_lead) if lead < 0.0 else lead)
	if host.tech_kind(attack) not in [&"charge", &"return_charge"]: return target
	var r: Dictionary = host._values_of(attack)
	var speed := float(r.distance) / float(r.active)
	var reach := float(r.get("reach", host.horn_length()))
	var offset := target - host.table.pos[host.body]
	var a := velocity.length_squared() - speed * speed
	var b := 2.0 * (offset.dot(velocity) - reach * speed)
	var c := offset.length_squared() - reach * reach
	var contact := 0.0
	if c > 0.0:
		contact = float(r.active)
		if absf(a) < 0.001:
			if b < -0.001: contact = -c / b
		else:
			var discriminant := b * b - 4.0 * a * c
			if discriminant >= 0.0:
				for root in [(-b - sqrt(discriminant)) / (2.0 * a), (-b + sqrt(discriminant)) / (2.0 * a)]:
					if root >= 0.0: contact = minf(contact, root)
	return target + velocity * clampf(contact, 0.0, float(r.active))

func lock_aim(host: MonocerosBoss) -> void:
	if host.mode != &"windup" or host.locked: return
	# 固定後は再捕捉せず、予告で見せた方向へ発進する。
	# 蹴りは背後への攻撃なので本体の向きを保つ。
	if kind() != &"kick" and not host.aim_point.is_equal_approx(host.table.pos[host.body]):
		host.table.facing[host.body] = (host.aim_point - host.table.pos[host.body]).angle()
	host.locked = true
	host.direction = (host.aim_point - host.table.pos[host.body]).normalized() if kind() == &"kick" else Vector2.from_angle(host.table.facing[host.body])
	host._cue(&"aim_locked")

func launch_strike(host: MonocerosBoss) -> void:
	if host.mode != &"windup": return
	host.lock_aim()
	if host.table.pos[host.body].distance_to(host.aim_point) > host._reach(host.technique) or (kind() == &"kick" and absf(Geom.angle_diff(host.direction.angle(), host.table.facing[host.body] + PI)) > float(host.def.params.kick_trigger_arc)):
		host.combat_trace.finish("interrupted", "target_left_launch_range")
		# 予告中に届かない位置へ離れた自機へ、空の近接攻撃を出し続けない。
		host.timeline.stop()
		host.combo_pending = false
		host.passes_left = 0
		host.mode = &"recovery"
		host.recovery = host._begin_settle() + float(host.rule().recover)
		host._cue(&"recovery_started")
		return
	if kind() in [&"charge", &"return_charge", &"lance"] and host._path_blocked():
		begin_reposition(host)
		return
	host.mode = &"active"
	host.previous_horn = host.horn_points()
	host._cue(&"attack_started")

## 地形が狙いを塞ぐときは発進を見送り、横へ位置を変える。
func begin_reposition(host: MonocerosBoss) -> void:
	host.combat_trace.finish("interrupted", "path_obstructed")
	host.combo_pending = false
	host.passes_left = 0
	host.timeline.stop()
	host.mode = &"idle"
	host.technique = &""
	host.reposition = float(host.def.params.reposition_time)
	var toward := (host.aim_point - host.table.pos[host.body]).normalized()
	var side := toward.orthogonal()
	var a := host.ctx.field.body_gap(host.table.pos[host.body] + side * 220.0, host.table.r[host.body])
	var b := host.ctx.field.body_gap(host.table.pos[host.body] - side * 220.0, host.table.r[host.body])
	host.reposition_direction = side if a >= b else -side
	host._cue(&"reposition")

func _path_blocked(host: MonocerosBoss) -> bool:
	var at := host.table.pos[host.body]
	var distance := maxf(float(host.def.params.near_clearance), minf(at.distance_to(host.aim_point), float(host.rule().distance)))
	# 狙いまでを確認する。かわされた先までの全突進経路は調べない。
	return host.ctx.field.first_body_hit(at, at + host.direction * distance, host.table.r[host.body]) != null

func _tick_strike(host: MonocerosBoss, _dt: float, prior: PackedVector2Array) -> void:
	host._damage_shape(prior, host.horn_points())

func end_strike(host: MonocerosBoss) -> void:
	if host.mode != &"active": return
	host.timeline.stop()
	host.table.vel[host.body] = Vector2.ZERO
	host.previous_horn.clear()
	host.passes_left -= 1
	if kind() == &"return_charge" and host.passes_left > 0:
		host.mode = &"turnaround"
		host.recovery = float(host.def.params.turnaround_time)
	else:
		host.mode = &"recovery"
		host.recovery = host._begin_settle() + float(host.rule().recover)
	host._cue(&"recovery_started")

## 姿勢戻しを始め、止まる時間と正面へ戻る時間の合計を返す。姿勢を持たない技は0。

func _begin_settle(host: MonocerosBoss) -> float:
	host.settle_at = host.clock
	host.settle_hold = 0.0
	host.settle_return = 0.0
	if kind() != &"kick": return 0.0
	var r := host.rule()
	# 後ろへ回した後脚を正面へ戻す。
	var angle := PI
	var speed := float(r.get("return_speed", 0.0))
	host.settle_hold = maxf(0.0, float(r.get("hold", 0.0)))
	host.settle_return = angle / speed if speed > 0.0 else 0.0
	return host.settle_hold + host.settle_return

## 攻撃後の姿勢戻しの進み。0は終わった姿勢のまま、1は正面の姿勢。

func horn_points(host: MonocerosBoss, _sweep_fraction := -1.0) -> PackedVector2Array:
	var at := host.table.pos[host.body]
	var direction := Vector2.from_angle(horn_angle(host))
	return PackedVector2Array([at + direction * host.table.r[host.body] * 0.65, at + direction * host.horn_length()])

func warning_points(host: MonocerosBoss) -> PackedVector2Array:
	var points := host.horn_points()
	if kind() in [&"charge", &"return_charge", &"lance"]:
		points[1] += host.direction * float(host.rule().distance)
	return points

func hit_width(host: MonocerosBoss) -> float:
	return float(host.def.params.horn_width)

func _damage_shape(host: MonocerosBoss, prior: PackedVector2Array, points: PackedVector2Array) -> void:
	if host.attack_hit or host.mode != &"active": return
	host.combat_trace.evaluate()
	var radius := hit_width(host) * 0.5 + host.ctx.cfg.ship_radius
	var paths: Array[PackedVector2Array] = [points, prior]
	if prior.size() == 2:
		paths.append(PackedVector2Array([prior[0], points[0]]))
		paths.append(PackedVector2Array([prior[1], points[1]]))
		if Geometry2D.is_point_in_polygon(host.run_state.ship_pos, PackedVector2Array([prior[0], prior[1], points[1], points[0]])):
			host._hit_ship()
	for line in paths:
		if line.size() != 2: continue
		if Geometry2D.segment_intersects_segment(host.previous_ship, host.run_state.ship_pos, line[0], line[1]) != null:
			host._hit_ship()
		for pair in [[host.previous_ship,line[0],line[1]],[host.run_state.ship_pos,line[0],line[1]],[line[0],host.previous_ship,host.run_state.ship_pos],[line[1],host.previous_ship,host.run_state.ship_pos]]:
			if Geometry2D.get_closest_point_to_segment(pair[0], pair[1], pair[2]).distance_squared_to(pair[0]) <= radius * radius: host._hit_ship()

func _hit_ship(host: MonocerosBoss) -> void:
	if host.attack_hit: return
	host.combat_trace.damage(float(host.rule().damage) * host.ctx.cfg.atk_scale, 0.0, &"horn", &"monoceros")
	host.attack_hit = true

func body_pose(_host: MonocerosBoss, _parts: Node2D) -> Dictionary:
	return {"neck": 0.0, "legs": []}

func kind() -> StringName:
	return &""
