## 吸引と吐き出しの値と動き。
@tool
extends BossTechnique

## 吐き出す彗星弾の弧
@export var arcs: Array[Resource] = []:
	set(value):
		arcs = value
		_values_dirty = true
## 予告（秒）
@export_range(0,100000,0.01) var warn := 1.2:
	set(value):
		warn = value
		_values_dirty = true
## 攻撃の継続時間
@export_range(0,100000,0.01) var active := 6.0:
	set(value):
		active = value
		_values_dirty = true
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 1.4:
	set(value):
		recover = value
		_values_dirty = true
## ダメージ
@export_range(0,100000,0.01) var damage := 40.0:
	set(value):
		damage = value
		_values_dirty = true
## 到達距離
@export_range(0,100000,0.01) var reach := 1800.0:
	set(value):
		reach = value
		_values_dirty = true
## 当たりの太さ（中心から片側）
@export_range(0,100000,0.01) var width := 120.0:
	set(value):
		width = value
		_values_dirty = true
## 吸い込み時間
@export_range(0,100000,0.01) var inhale_time := 3.0:
	set(value):
		inhale_time = value
		_values_dirty = true
## 引き寄せる範囲
@export_range(0,100000,0.01) var pull_range := 1500.0:
	set(value):
		pull_range = value
		_values_dirty = true
## 引き寄せる速さ
@export_range(0,100000,0.01) var pull_speed := 650.0:
	set(value):
		pull_speed = value
		_values_dirty = true
## 複製体の引き寄せ速度
@export_range(0,100000,0.01) var picaro_pull_speed := 900.0:
	set(value):
		picaro_pull_speed = value
		_values_dirty = true
## 口元の半径
@export_range(0,100000,0.01) var mouth_radius := 75.0:
	set(value):
		mouth_radius = value
		_values_dirty = true
## 噛みつきのダメージ
@export_range(0,100000,0.01) var bite_damage := 30.0:
	set(value):
		bite_damage = value
		_values_dirty = true
## 光を出す時間（秒）
@export_range(0,100000,0.01) var beam_time := 2.0:
	set(value):
		beam_time = value
		_values_dirty = true
## ビームが伸びきる時間（秒）
@export_range(0,100000,0.01) var beam_extend := 0.25:
	set(value):
		beam_extend = value
		_values_dirty = true
## ビームの予告
@export_range(0,100000,0.01) var beam_warn := 0.5:
	set(value):
		beam_warn = value
		_values_dirty = true
## 星ごとの彗星数
@export_range(0,100000,1) var comets_per_star := 2:
	set(value):
		comets_per_star = value
		_values_dirty = true
## 彗星の同時上限
@export_range(0,100000,1) var comet_cap := 24:
	set(value):
		comet_cap = value
		_values_dirty = true
## 彗星の速さ
@export_range(0,100000,0.01) var comet_speed := 480.0:
	set(value):
		comet_speed = value
		_values_dirty = true

## 撃つ弾の見た目
@export var shot_visual: PackedScene = preload("res://scenes/attacks/bolt.tscn"):
	set(value):
		shot_visual = value
		_values_dirty = true
## ビームの見た目
@export var beam_visual: PackedScene = preload("res://scenes/attacks/beam_draco.tscn"):
	set(value):
		beam_visual = value
		_values_dirty = true

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends BossTechnique.Runner:
	func kind() -> StringName: return &"inhale"

	const STAGING = preload("res://scripts/bosses/draco_screen_staging.gd")
	const MOTION = preload("res://scripts/bosses/draco_attack_motion.gd")
	## 吸い込みの間に自機の方へ向き直る速さ（ラジアン/秒）
	const INHALE_TURN := 1.2
	var staging: Dictionary
	var stars := 0
	var spent := false
	var caught := false
	var release_at := 0.0
	var beam := -1
	var beam_direction := Vector2.RIGHT
	func begin(a: BossActor) -> void:
		a.picaro.pause(true)
		beam_direction = (a.aim_target() - a.table.pos[a.body]).normalized()
		if beam_direction.is_zero_approx(): beam_direction = Vector2.from_angle(a.table.facing[a.body])
		a.direction = beam_direction
		a.table.facing[a.body] = beam_direction.angle()
		staging = STAGING.side_entry(a, a.aim_target())
	func windup(a: BossActor, _dt: float) -> void:
		var progress := clampf(a.elapsed / float(a.rule().warn), 0.0, 1.0)
		STAGING.advance(a, staging, progress)
		if progress >= 0.4:
			# 画面へ入ったら自機の方を向き、来た道に沿った体を頭の後ろへまっすぐ伸ばしていく。
			var turn := smoothstep(0.4, 0.8, progress)
			a.table.facing[a.body] = lerp_angle(a.table.facing[a.body], (a.aim_target() - a.table.pos[a.body]).angle(), turn)
			var head: Vector2 = a.table.pos[a.body]
			var straight: PackedVector2Array = a.neutral_body_points(head, a.table.facing[a.body])
			var trail: PackedVector2Array = a.body_pose if not a.body_pose.is_empty() else straight
			var from := PackedVector2Array()
			for point in trail: from.append(point + head - trail[0])
			MOTION.blend(a, from, straight, smoothstep(0.4, 1.0, progress))
		a.direction = Vector2.from_angle(a.table.facing[a.body])

	func _stretch(a: BossActor) -> void:
		a.body_override = a.neutral_body_points(a.table.pos[a.body], a.table.facing[a.body])
	func tick(a: BossActor, dt: float) -> void:
		var mouth: Vector2 = a.mouth_pos()
		var inhale_time := float(a.rule().inhale_time)
		_stretch(a)
		if a.elapsed < inhale_time:
			if not caught:
				a.combat_trace.evaluate()
				a.table.facing[a.body] = rotate_toward(a.table.facing[a.body], (a.run_state.ship_pos - a.table.pos[a.body]).angle(), INHALE_TURN * dt)
				a.direction = Vector2.from_angle(a.table.facing[a.body])
			var toward: Vector2 = mouth - a.run_state.ship_pos
			if toward.length() < float(a.rule().pull_range) and not caught:
				a.run_state.ship_pos += toward.normalized() * minf(toward.length(), float(a.rule().pull_speed) * dt)
				if toward.length() < float(a.rule().mouth_radius) + a.ctx.cfg.ship_radius:
					caught = true
					a.combat_trace.damage(float(a.rule().bite_damage) * a.ctx.cfg.atk_scale, 0.0, &"bite", &"draco")
					a.run_state.ship_pos = mouth + a.direction * (a.head_scale * 100.0)
					a.run_state.ship_vel = a.direction * 1000.0
					a.run_state.ship_invuln = maxf(a.run_state.ship_invuln, 1.2)
					a.run_state.steering_locked = true
					release_at = a.clock + 0.8
			for member: Dictionary in a.picaro.alive():
				var delta: Vector2 = mouth - a.table.pos[member.row]
				a.table.pos[member.row] += delta.normalized() * minf(delta.length(), float(a.rule().picaro_pull_speed) * dt)
				if delta.length() < a.head_scale * 80.0:
					stars += int(member.stars)
					a.ctx.enemies.mark_dead(member.row)
			if caught and a.clock >= release_at: a.run_state.steering_locked = false
			return
		if a.run_state.steering_locked:
			if a.clock < release_at:
				a.elapsed = inhale_time
				return
			a.run_state.steering_locked = false
		if spent:
			_extend_beam(a)
			return
		spent = true
		# 吐き出す時点の現在位置へ向くが、警告を見せた後は一切追わない。
		beam_direction = (a.aim_target() - a.table.pos[a.body]).normalized()
		if beam_direction.is_zero_approx(): beam_direction = a.direction
		a.direction = beam_direction
		a.table.facing[a.body] = a.direction.angle()
		mouth = a.mouth_pos()
		a.combat_trace.stage("lock", {"scope": "exhale", "aim": [a.aim_target().x, a.aim_target().y]})
		beam = a.ctx.projectiles.emit_attack(&"beam", [mouth, a.direction.angle(), float(a.rule().reach), float(a.rule().width), float(a.rule().get("beam_warn", 0.5)), float(a.rule().beam_time), float(a.rule().damage) * a.ctx.cfg.atk_scale, Color("#d4bbff")], a.rule().get("beam_visual"))
		a.ctx.projectiles.hazard_style[beam] = ProjectileSystem.HazardStyle.DRACO
		a.ctx.projectiles.attach_hazard(beam, a.body)
		_extend_beam(a)
		# 実験場では吸い込むピカロがいないので、調整欄で決めた星の数を吸い込んだことにする。
		if stars == 0 and a.run_state.lab_mode: stars = int(a.get("lab_inhale_stars"))
		if stars > 0:
			var remaining := mini(int(a.rule().comet_cap), stars * int(a.rule().comets_per_star))
			var arcs: Array = a.rule().arcs
			for index in arcs.size():
				var arc: DracoExhaleArc = arcs[index]
				var quota := mini(arc.count, ceili(float(remaining) / float(arcs.size() - index)))
				for j in quota:
					var angle: float = a.direction.angle() + deg_to_rad(arc.angle_degrees + lerpf(-arc.spread_degrees, arc.spread_degrees, float(j) / maxf(1.0, float(quota) - 1.0)))
					var origin: Vector2 = mouth + arc.offset.rotated(a.direction.angle()) + Vector2.from_angle(angle) * arc.radius
					a.ctx.projectiles.emit_attack(&"bolt", [origin, angle, float(a.rule().comet_speed), float(a.rule().damage) * 0.6 * a.ctx.cfg.atk_scale], a.rule().get("shot_visual"))
				remaining -= quota
		stars = 0
	## 光線の先を口から射程まで伸ばす。判定も同じ長さを使う。
	func _extend_beam(a: BossActor) -> void:
		var pr: ProjectileSystem = a.ctx.projectiles
		if not pr.owns_hazard(beam, a.body, a.body_id): return
		var extend := float(a.rule().get("beam_extend", 0.25))
		var fired := pr.hazard_t[beam] - pr.hazard_delay[beam]
		pr.hazard_len[beam] = float(a.rule().reach) * (clampf(fired / extend, 0.0, 1.0) if extend > 0.0 else 1.0)

	func recover(a: BossActor, _dt: float) -> void:
		_stretch(a)

	func end(a: BossActor, _cancelled: bool) -> void:
		if a.ctx.projectiles.owns_hazard(beam, a.body, a.body_id): a.ctx.projectiles.release_hazard(beam)
		a.run_state.steering_locked = false
		stars = 0

	func pose(a: BossActor) -> void:
		a.mouth_open = 1.35 if a.mode == &"active" else 0.8 if a.mode == &"windup" else 0.0
