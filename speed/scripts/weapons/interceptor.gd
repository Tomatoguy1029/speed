## W25 迎撃ドローン（仮称）：周回編隊から近敵へダメージ弾を撃つ。
extends WeaponBehavior

var drones: Array[Dictionary] = []
var _clock := 0.0
var _target_after: Dictionary = {}
var _buf := PackedInt32Array()
var _candidates_ready := false

func value(key: String):
	return p(key)[clampi(level, 1, def.level_steps.size()) - 1]

func count() -> int:
	return int(value("drones_by_level"))

func tick(dt: float, busy: bool) -> void:
	_clock += dt
	_candidates_ready = false
	for id in _target_after.keys():
		if float(_target_after[id]) <= _clock: _target_after.erase(id)
	while drones.size() < count():
		var i := drones.size()
		drones.append({"pos": state.ship_pos, "angle": 0.0, "flash": 0.0,
			"target": -1, "target_id": -1, "kick": 0.0, "next": _clock + i * interval(float(value("interval_by_level"))) / count(), "left": 0})
	# 同じ自機中心の候補取得を各機・照準・射撃で繰り返さない。
	# 射撃は弾を登録するだけなので、この更新中に敵の位置や生死は変わらない。
	var range_r := float(p("range"))
	for i in drones.size():
		var d := drones[i]
		# 編隊を常に自機へ固定する。高速経路の記録・追走は行わない。
		var a := _clock * float(p("orbit_speed")) + i * TAU / drones.size()
		var radial := Vector2.from_angle(a)
		d.pos = state.ship_pos + radial * float(p("orbit")) - Vector2.from_angle(float(d.angle)) * float(d.kick)
		d.kick = maxf(0.0, float(d.kick) - dt * 12.0 * 1.82 * cfg.character_scale)
		d.flash = maxf(0.0, float(d.flash) - dt)
		var aim: int = d.target if int(d.left)>0 and ctx.enemies.is_same(int(d.target),int(d.target_id)) else _nearest(d.pos, range_r)
		if aim >= 0:
			d.angle = lerp_angle(float(d.angle), (ctx.enemies.table.pos[aim] - d.pos).angle(), minf(dt * 14.0, 1.0))
		if busy or _clock < float(d.next):
			continue
		var target := -1
		if int(d.left) == 0:
			target = aim
			if target<0: continue
			d.left = int(value("burst_by_level"))
			d.target = target
			d.target_id = ctx.enemies.table.id[target]
		elif ctx.enemies.is_same(int(d.target),int(d.target_id)) and ctx.enemies.table.dead[int(d.target)]==0:
			target = int(d.target)
		else: target = _nearest(d.pos, range_r)
		if target >= 0:
			var t := ctx.enemies.table
			_target_after[t.id[target]] = _clock + float(p("target_interval"))
			d.kick = 1.5 * 1.82 * cfg.character_scale
			d.flash = 0.06
			var direction := Vector2.from_angle(float(d.angle))
			var count := shots(1)
			var origin: Vector2 = d.pos + direction * 15.0 * cfg.character_scale
			var damage := atk() * float(value("damage_by_level"))
			var opts := {"cause": &"interceptor", "r": p("shot_radius"),
				"speed": p("shot_speed"), "life": p("life"), "color": Color(p("color")), "on_hit": hit_enemy,
				"visual_key": "weapon/interceptor"}
			for shot in count:
				fire_shot(origin, d.angle + (shot - (count - 1) / 2.0) * 0.08, damage, opts)
		d.left = int(d.left) - 1
		d.next = _clock + shooting_interval(float(p("burst_interval")) if int(d.left) > 0 else float(value("interval_by_level")))

func _nearest(from: Vector2, range_r: float) -> int:
	if not _candidates_ready:
		ctx.combat.nearby(state.ship_pos, range_r, _buf)
		_candidates_ready = true
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
	ctx.combat.damage_enemy(i, damage, {"cause": &"interceptor", "impact": impact, "no_crit": true})
