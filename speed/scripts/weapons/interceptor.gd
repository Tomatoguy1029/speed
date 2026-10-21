## W25 迎撃ドローン（仮称）：周回編隊から近敵へ制御弾を撒き、突進前の余地を作る。
extends WeaponBehavior

var drones: Array[Dictionary] = []
var _clock := 0.0
var _target_after: Dictionary = {}
var _control_after: Dictionary = {}
var _hit_after: Dictionary = {}
var _buf := PackedInt32Array()

func value(key: String):
	return p(key)[clampi(level, 1, def.level_steps.size()) - 1]

func count() -> int:
	return int(value("drones_by_level"))

func tick(dt: float, busy: bool) -> void:
	_clock += dt
	for times in [_target_after, _control_after, _hit_after]:
		for id in times.keys():
			if float(times[id]) <= _clock:
				times.erase(id)
	while drones.size() < count():
		var i := drones.size()
		drones.append({"pos": state.ship_pos, "angle": 0.0, "flash": 0.0,
			"next": _clock + i * float(value("interval_by_level")) / count(), "left": 0})
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
			var t := build.enemies.table
			_target_after[t.id[target]] = _clock + float(p("target_interval"))
			d.angle = (t.pos[target] - d.pos).angle()
			d.flash = 0.09
			var direction := Vector2.from_angle(float(d.angle))
			build.projectiles.fire_shot(d.pos + direction * 15.0 * cfg.character_scale, d.angle,
				atk() * float(value("damage_by_level")), {"cause": &"interceptor", "r": p("shot_radius"),
				"speed": p("shot_speed"), "life": p("life"), "color": Color(p("color"))})
		d.left = int(d.left) - 1
		d.next = _clock + (float(p("burst_interval")) if int(d.left) > 0 else float(value("interval_by_level")))

func _nearest(from: Vector2) -> int:
	var range_r := float(p("range"))
	build.combat.nearby(state.ship_pos, range_r, _buf)
	var t := build.enemies.table
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

## 実際の着弾だけを扱う。弾の掃引・地形・盾反射は ProjectileManager が先に判定する。
func hit_enemy(i: int, damage: float, impact: Vector2) -> void:
	var t := build.enemies.table
	var id := t.id[i]
	if _hit_after.has(id):
		return
	_hit_after[id] = _clock + float(p("hit_interval"))
	var opts := {"cause": &"interceptor", "impact": impact, "no_crit": true}
	var push_scale := t.def[i].knockback_scale(cfg) if t.def[i] != null else 1.0
	var control := t.is_boss[i] == 0 and t.parent[i] < 0 and push_scale > 0.0 and not _control_after.has(id)
	if control:
		opts.dir = (t.pos[i] - state.ship_pos).normalized()
		opts.knock = float(p("knock"))
	var hp := t.hp[i]
	build.combat.damage_enemy(i, damage, opts)
	if control and t.hp[i] < hp and t.dead[i] == 0:
		# 既存の押し返し時間を使う。耐性・質量補正は damage_enemy が適用する。
		t.knock_t[i] = maxf(t.knock_t[i], float(p("control_time")))
		_control_after[id] = _clock + float(p("control_interval"))
