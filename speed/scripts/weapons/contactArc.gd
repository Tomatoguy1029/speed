## W17 接触電撃：普段・高速を問わず敵に触れると、その敵から近くの敵へ電撃がつながる（一覧 docs/game/catalog/weapons.md）。
## つながる数は Lv × 2。同じ敵には1回の連鎖で1度だけ。隕石には流れない。
extends WeaponBehavior

var _buf := PackedInt32Array()

func on_any_contact(target: int) -> void:
	var t := build.enemies.table
	if t.type[target] == &"meteor":
		return
	var dmg := atk() * float(p("damage")) * dmg_k()
	var used := {t.id[target]: true}
	var pts := [state.ship_pos, t.pos[target]]
	var from := t.pos[target]
	if t.dead[target] == 0:
		build.combat.damage_enemy(target, dmg, {"cause": &"contactArc"})
	var reach: float = p("range")
	for k in level * int(p("chains_per_level")):
		if state.phase != RunState.Phase.PLAY:
			break
		build.combat.nearby(from, reach, _buf)
		var next := -1
		var best := reach * reach
		for i in _buf:
			if t.type[i] == &"meteor" or used.has(t.id[i]):
				continue
			var d := t.pos[i].distance_squared_to(from)
			if d < best:
				best = d
				next = i
		if next < 0:
			break
		used[t.id[next]] = true
		var next_pos := t.pos[next]
		pts.append(next_pos)
		var dir := (next_pos - from).normalized()
		build.combat.damage_enemy(next, dmg, {"cause": &"contactArc", "dir": dir})
		from = next_pos
	state.emit(&"bolt", {"points": pts})
