## W25 迎撃ドローン（仮称）：周回編隊から近敵へダメージ弾を撃つ。
extends WeaponBehavior

var drones: Array[Dictionary] = []
var _clock := 0.0
var _target_after: Dictionary = {}
var _hit_after: Dictionary = {}
var _buf := PackedInt32Array()

func value(key: String):
	return p(key)[clampi(level, 1, def.level_steps.size()) - 1]

func count() -> int:
	return int(value("drones_by_level"))

func tick(dt: float, busy: bool) -> void:
	_clock += dt
	for times in [_target_after, _hit_after]:
		for id in times.keys():
			if float(times[id]) <= _clock:
				times.erase(id)
	while drones.size() < count():
		var i := drones.size()
		drones.append({"pos": state.ship_pos, "angle": 0.0, "flash": 0.0,
			"next": _clock + i * interval(float(value("interval_by_level"))) / count(), "left": 0})
	for i in drones.size():
		var d := drones[i]
		# 編隊を常に自機へ固定する。高速経路の記録・追走は行わない。
		var a := _clock * float(p("orbit_speed")) + i * TAU / drones.size()
		var radial := Vector2.from_angle(a)
		d.pos = state.ship_pos + radial * float(p("orbit"))
		d.flash = maxf(0.0, float(d.flash) - dt)
		if int(d.left) == 0:
			d.angle = lerp_angle(float(d.angle), a, minf(dt * 5.0, 1.0))
		if busy or _clock < float(d.next):
			continue
		if int(d.left) == 0:
			d.left = int(value("burst_by_level"))
		var target := _nearest(d.pos)
		if target >= 0:
			var t := ctx.enemies.table
			_target_after[t.id[target]] = _clock + float(p("target_interval"))
			d.angle = (t.pos[target] - d.pos).angle()
			d.flash = 0.09
			var direction := Vector2.from_angle(float(d.angle))
			fire_shot(d.pos + direction * 15.0 * cfg.character_scale, d.angle,
				atk() * float(value("damage_by_level")), {"cause": &"interceptor", "r": p("shot_radius"),
				"speed": p("shot_speed"), "life": p("life"), "color": Color(p("color")), "on_hit": hit_enemy,
				"visual_key": "weapon/interceptor"})
		d.left = int(d.left) - 1
		d.next = _clock + interval(float(p("burst_interval")) if int(d.left) > 0 else float(value("interval_by_level")))

func _nearest(from: Vector2) -> int:
	var range_r := float(p("range"))
	ctx.combat.nearby(state.ship_pos, range_r, _buf)
	var t := ctx.enemies.table
	var best := -1
	var distance := INF
	for i in _buf:
		if t.dead[i] != 0 or t.meteor_index[i] >= 0 or _target_after.has(t.id[i]):
			continue
		if t.pos[i].distance_squared_to(state.ship_pos) > range_r * range_r:
			continue
		# 近い脅威を優先しつつ、ボスへの集中を避けて周囲へ振り分ける。
		var score := t.pos[i].distance_squared_to(from)
		if t.is_boss[i] != 0 or t.parent[i] >= 0:
			score += range_r * range_r
		if score < distance:
			distance = score
			best = i
	return best

## 実際の着弾だけを扱う。弾の掃引・地形・盾反射は ProjectileSystem が先に判定する。
func hit_enemy(i: int, damage: float, impact: Vector2) -> void:
	var t := ctx.enemies.table
	var id := t.id[i]
	if _hit_after.has(id):
		return
	_hit_after[id] = _clock + float(p("hit_interval"))
	ctx.combat.damage_enemy(i, damage, {"cause": &"interceptor", "impact": impact, "no_crit": true})
