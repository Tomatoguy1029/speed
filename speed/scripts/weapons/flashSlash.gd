## W28 閃光斬：印の対象は行番号とIDで保持し、再利用された別の敵を斬らない。
extends WeaponBehavior
var marks: Array[Dictionary] = []
## 残っている印をブーストID・敵IDで引く。印の寿命と一緒に解放する。
var _marked_ids: Dictionary = {}
var elapsed := -1.0
var _distance := 0.0
func on_launch(_full: bool) -> void:
	# 前の斬撃は終わるまで進め、次のブーストと区別する。
	_distance = 0.0
func on_ram_hit(i: int, hit: Vector2, _dir: Vector2, damage: float) -> void:
	i = ctx.combat.damage_target(i)
	var t := ctx.enemies.table
	if not state.tracing or t.dead[i] != 0: return
	if not _marked_ids.has(state.dash_id):
		_marked_ids[state.dash_id] = {}
	var ids: Dictionary = _marked_ids[state.dash_id]
	if ids.has(t.id[i]): return
	ids[t.id[i]] = true
	var angle := state.rng.randf() * TAU
	var cuts := int(at_level("cuts_by_level"))
	marks.append({"row": i, "id": t.id[i], "dash": state.dash_id, "distance": ctx.loadout.boost_distance,
		"damage": (damage if damage > 0.0 else atk()) * at_level("mult_by_level"), "left": cuts,
		"total": cuts, "time": -1.0, "angle": angle})
	if t.is_boss[i] == 0: t.slash_hold[i] = 1
	t.flash[i] = 0.07
	state.emit(&"slash_mark", {"pos": t.pos[i], "angle": angle, "radius": t.r[i], "id": t.id[i], "row": i})
func on_end() -> void:
	for mark in marks:
		if mark.dash == state.dash_id and mark.time < 0.0:
			mark.time = 0.0
			mark.delay = float(p("pause")) + float(p("sweep")) * clampf(mark.distance / maxf(ctx.loadout.boost_distance, 1.0), 0.0, 1.0)
	state.emit(&"slash_release", {"path": state.trace_path, "count": int(at_level("streaks_by_level")), "sweep": p("sweep"), "pause": p("pause")})
func tick(dt: float, _busy: bool) -> void:
	var t := ctx.enemies.table
	for mark in marks:
		var i: int = mark.row
		if not ctx.enemies.is_same(i, mark.id) or t.dead[i] != 0:
			mark.left = 0
			if ctx.enemies.is_same(i, mark.id): t.slash_hold[i] = 0
			continue
		if mark.time < 0.0: continue
		mark.time += dt
		while mark.left > 0 and mark.time >= mark.delay + (mark.total - mark.left) * 0.025:
			mark.left -= 1
			ctx.combat.damage_enemy(i, mark.damage / mark.total, {"cause": &"flashSlash", "no_crit": true, "knock": 0.0})
			state.emit(&"flash_slash", {"pos": t.pos[i], "angle": mark.angle + (mark.total - mark.left - 1) * 0.55, "length": 150.0, "width": 3.2, "id": mark.id})
		if mark.left == 0: t.slash_hold[i] = 0
	var kept := 0
	for mark in marks:
		if mark.left > 0:
			marks[kept] = mark
			kept += 1
		else:
			var ids: Dictionary = _marked_ids[mark.dash]
			ids.erase(mark.id)
			if ids.is_empty(): _marked_ids.erase(mark.dash)
	marks.resize(kept)
func dispose() -> void:
	for m in marks:
		if ctx.enemies.is_same(m.row, m.id): ctx.enemies.table.slash_hold[m.row] = 0
	marks.clear()
	_marked_ids.clear()
