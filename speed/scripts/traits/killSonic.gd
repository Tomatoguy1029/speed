## T05 チェインショック：倒れた地点から、上限付きで小さくなる衝撃波を連鎖する。
extends TraitBehavior
var _kills := 0
var _next := 10
var _active := false
var chains := 0
var waves: Array[Dictionary] = []
func _every() -> int: return int(val("kills"))
func on_launch(_full: bool) -> void:
	_kills = 0
	_next = _every()
	_active = true
	chains = 0
func on_end() -> void: _active = false
func on_kill(_cause: StringName) -> void:
	if not _active: return
	_kills += 1
	if _kills < _next or chains >= int(def.params.limit_by_level[n - 1]): return
	_next += _every()
	var radius := val("radius") * pow(float(def.params.radius_decay), chains) * ctx.loadout.area_multiplier()
	var damage := atk() * val("damage") * pow(float(def.params.damage_decay), chains)
	chains += 1
	waves.append({"pos": ctx.loadout.kill_position, "radius": radius, "damage": damage, "age": 0.0, "hit": {}})
	state.emit(&"chain_shock", {"pos": ctx.loadout.kill_position, "radius": radius, "life": 0.4})
func tick(dt: float, _busy: bool) -> void:
	# 命中で次の波が増えるので、更新対象を固定する。
	for wave in waves.duplicate():
		wave.age += dt
		var reach: float = wave.radius * (1.0 - pow(1.0 - minf(1.0, wave.age / 0.4), 3.0))
		var rows := PackedInt32Array()
		ctx.combat.nearby(wave.pos, reach, rows)
		var t := ctx.enemies.table
		for i in rows:
			if t.dead[i] != 0 or wave.hit.has(t.id[i]) or t.pos[i].distance_to(wave.pos) > reach + t.r[i]: continue
			wave.hit[t.id[i]] = true
			ctx.combat.damage_enemy(i, wave.damage, {"cause": &"killSonic", "dir": (t.pos[i] - wave.pos).normalized(), "knock": def.params.knock})
	waves = waves.filter(func(w): return w.age < 0.4)
