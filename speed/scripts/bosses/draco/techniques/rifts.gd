## 三本爪の亀裂の値と動き。
@tool
extends BossTechnique

## 予告（秒）
@export_range(0,100000,0.01) var warn := 0.7:
	set(value):
		warn = value
		_values_dirty = true
## 攻撃の継続時間
@export_range(0,100000,0.01) var active := 3.8:
	set(value):
		active = value
		_values_dirty = true
## 爪の開く角度（度）
@export_range(0,360,0.1,"radians_as_degrees") var claw_angle := 0.0666:
	set(value):
		claw_angle = value
		_values_dirty = true
## 片側の爪の数
@export_range(0,100000,1) var claw_count := 3:
	set(value):
		claw_count = value
		_values_dirty = true
## 爪の間隔
@export_range(0,100000,0.01) var claw_gap := 70.0:
	set(value):
		claw_gap = value
		_values_dirty = true
## 中心から最初の爪までの横のずれ
@export_range(0,100000,0.01) var claw_offset := 135.0:
	set(value):
		claw_offset = value
		_values_dirty = true
## 自機の先まで伸ばす長さ
@export_range(0,100000,0.01) var claw_overshoot := 125.0:
	set(value):
		claw_overshoot = value
		_values_dirty = true
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 0.7:
	set(value):
		recover = value
		_values_dirty = true
## ダメージ
@export_range(0,100000,0.01) var damage := 30.0:
	set(value):
		damage = value
		_values_dirty = true
## 到達距離
@export_range(0,100000,0.01) var reach := 1500.0:
	set(value):
		reach = value
		_values_dirty = true
## 当たりの太さ（中心から片側）
@export_range(0,100000,0.01) var width := 24.0:
	set(value):
		width = value
		_values_dirty = true
## 矢の間隔（秒）
@export_range(0,100000,0.01) var interval := 0.4:
	set(value):
		interval = value
		_values_dirty = true
## ひっかきの時間
@export_range(0,100000,0.01) var scratch_time := 0.32:
	set(value):
		scratch_time = value
		_values_dirty = true
## ひっかきの幅
@export_range(0,100000,0.01) var scratch_width := 30.0:
	set(value):
		scratch_width = value
		_values_dirty = true

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends BossTechnique.Runner:
	func kind() -> StringName: return &"rifts"

	const STAGING = preload("res://scripts/bosses/draco_screen_staging.gd")
	var staging: Dictionary
	var walls: Array[int] = []
	var slashes: Array[int] = []
	var sides := 0
	var center := Vector2.ZERO
	var ended := false
	var paths: Array[PackedVector2Array] = []
	var locked := false
	## 片側の爪の数
	var claws := 3
	func begin(a: BossActor) -> void:
		center = a.aim_target()
		var side := -1.0 if a.run_state.rng.randf() < 0.5 else 1.0
		staging = STAGING.begin(a, side, true)

	func _lock(a: BossActor) -> void:
		center = a.aim_target()
		var origin: Vector2 = a.table.pos[a.body]
		var forward: Vector2 = (center - origin).normalized()
		if forward.is_zero_approx(): forward = Vector2(-float(staging.side), 0.0)
		var lateral: Vector2 = forward.orthogonal()
		a.direction = forward
		var p: Dictionary = a.rule()
		claws = maxi(1, int(p.get("claw_count", 3)))
		var start: float = 125.0 * a.head_scale
		# 爪は口の前から自機の先まで伸び、外側へ claw_angle だけ開く。長さは reach で止める。
		var length := minf(float(p.get("reach", 1500.0)), (center - origin).dot(forward) + float(p.get("claw_overshoot", 125.0)) - start)
		for side in [-1, 1]:
			for j in claws:
				var stripe := float(side) * float(p.get("claw_offset", 135.0)) + (j - (claws - 1) * 0.5) * float(p.get("claw_gap", 70.0))
				var from: Vector2 = origin + forward * start + lateral * stripe
				var to: Vector2 = from + forward.rotated(-float(side) * float(p.get("claw_angle", 0.0666))) * maxf(1.0, length)
				paths.append(PackedVector2Array([from, to]))
				a.telegraph_paths.append(paths[-1])
				a.telegraph_widths.append(float(a.rule().get("scratch_width", 30.0)) * 0.5)
		locked = true
		a.combat_trace.stage("telegraph")
		a.combat_trace.stage("lock", {"scope": "rifts_paths"})
	func windup(a: BossActor, dt: float) -> void:
		if not STAGING.advance_full(a, staging, dt): return
		if not locked: _lock(a)
		a.table.facing[a.body] = lerp_angle(a.table.facing[a.body], a.direction.angle(), clampf(dt * 9.0, 0.0, 1.0))
	func tick(a: BossActor, _dt: float) -> void:
		var p: Dictionary = a.rule()
		var scratch_time := float(p.get("scratch_time", 0.32))
		var interval := float(p.interval)
		while sides < 2 and a.elapsed >= sides * interval:
			for j in claws:
				var points: PackedVector2Array = paths[sides * claws + j]
				var delta := points[1] - points[0]
				var slash := a.ctx.projectiles.fire_wall(points[0], delta.angle(), 1.0, float(p.get("scratch_width", 30.0)), 0.0, scratch_time, float(p.damage) * a.ctx.cfg.atk_scale, Color("#e4cfff"))
				slashes.append(slash)
				a.ctx.projectiles.attach_hazard(slash, a.body)
				var h := a.ctx.projectiles.fire_wall(points[0], delta.angle(), 1.0, float(p.width), 0.0, float(p.active) + float(p.recover) + 1.0, 0.0, Color("#34224d"))
				a.ctx.projectiles.hazard_block[h] = 1
				a.ctx.projectiles.attach_hazard(h, a.body)
				walls.append(h)
				a.ctx.projectiles.hazard_style[h] = ProjectileSystem.HazardStyle.TRAIL
			sides += 1
		a.telegraph_paths.clear()
		a.telegraph_widths.clear()
		for index in paths.size():
			var side_index := index / claws
			var local_time: float = a.elapsed - side_index * interval
			if local_time < 0.0:
				a.telegraph_paths.append(paths[index])
				a.telegraph_widths.append(float(p.get("scratch_width", 30.0)) * 0.5)
				continue
			var path: PackedVector2Array = paths[index]
			var tip: Vector2 = path[0].lerp(path[1], clampf(local_time / scratch_time, 0.0, 1.0))
			var delta := tip - path[0]
			if index < slashes.size() and a.ctx.projectiles.owns_hazard(slashes[index], a.body, a.body_id):
				a.ctx.projectiles.move_hazard(slashes[index], path[0], delta.angle(), maxf(1.0, delta.length()))
			if index < walls.size() and a.ctx.projectiles.owns_hazard(walls[index], a.body, a.body_id):
				a.ctx.projectiles.move_hazard(walls[index], path[0], delta.angle(), maxf(1.0, delta.length()))
				var nearest := Geometry2D.get_closest_point_to_segment(a.run_state.ship_pos, path[0], tip)
				var away: Vector2 = a.run_state.ship_pos - nearest
				var margin := a.ctx.cfg.ship_radius + float(p.width) * 0.5 + 1.0
				if away.length() < margin:
					a.run_state.ship_pos = nearest + (away.normalized() if away.length() > 0.01 else delta.normalized().orthogonal()) * margin
	func end(a: BossActor, cancelled: bool) -> void:
		if ended:
			if cancelled:
				for wall: Dictionary in a.closing_walls:
					if int(wall.h) in walls: wall.delay = 0.0
			return
		ended = true
		for h in slashes:
			if a.ctx.projectiles.owns_hazard(h, a.body, a.body_id): a.ctx.projectiles.release_hazard(h)
		for h in walls: a.close_wall(h, 0.3, 0.0 if cancelled else float(a.rule().recover))
		a.telegraph_paths.clear()
		a.telegraph_widths.clear()
