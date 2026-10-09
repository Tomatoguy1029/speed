## W17 接触電撃：普段・高速を問わず敵に触れると、その敵から近くの敵へ電撃がつながる（一覧 docs/game/weapons.md）。
## つながる数は Lv × 2。同じ敵には1回の連鎖で1度だけ。隕石には流れない。
extends WeaponBehavior

var _buf: Array = []

func on_any_contact(target: Enemy) -> void:
	if target.type == &"meteor":
		return
	var dmg := atk() * float(p("damage")) * dmg_k()
	var used := {target.id: true}
	var pts := [state.ship_pos, target.pos]
	var from := target.pos
	if not target.dead:
		build.combat.damage_enemy(target, dmg, {"cause": &"contactArc"})
	var reach: float = p("range")
	for i in level * int(p("chains_per_level")):
		if state.phase != RunState.Phase.PLAY:
			break
		build.combat.nearby(from, reach, _buf)
		var next: Enemy = null
		var best := reach * reach
		for e: Enemy in _buf:
			if e.type == &"meteor" or used.has(e.id):
				continue
			var d := e.pos.distance_squared_to(from)
			if d < best:
				best = d
				next = e
		if next == null:
			break
		used[next.id] = true
		pts.append(next.pos)
		var dir := (next.pos - from).normalized()
		build.combat.damage_enemy(next, dmg, {"cause": &"contactArc", "dir": dir})
		from = next.pos
	state.emit(&"bolt", {"points": pts})
