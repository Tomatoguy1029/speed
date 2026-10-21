## W17 接触電撃：接触した敵から離れた方向へ枝を出し、各枝を順に伸ばす（一覧 docs/game/catalog/weapons.md）。
## 全枝で Lv × chains_per_level 体の追加対象枠を共有。同じ敵には1回だけ。隕石には流れない。
extends WeaponBehavior

var _buf := PackedInt32Array()

func on_any_contact(target: int) -> void:
	var t := build.enemies.table
	if t.meteor_index[target] >= 0:
		return
	var dmg := atk() * float(p("damage")) * dmg_k()
	var used := {t.id[target]: true}
	var origin := t.pos[target]
	var segments := PackedVector2Array([state.ship_pos, origin])
	if t.dead[target] == 0:
		build.combat.damage_enemy(target, dmg, {"cause": &"contactArc"})
	var reach: float = p("range")
	var remaining := level * int(p("chains_per_level"))
	var tips: Array[Vector2] = []
	var directions: Array[Vector2] = []
	var separation := deg_to_rad(clampf(float(p("branch_angle")), 0.0, 180.0))
	# まず接触点の周りへ枝を配る。枝数・角度は .tres の試遊用初期値。
	for k in mini(maxi(1, int(p("branches"))), remaining):
		if state.phase != RunState.Phase.PLAY:
			break
		var next := _nearest(origin, reach, used, directions, separation)
		if next < 0:
			break
		var next_pos := _strike(origin, next, dmg, used, segments)
		directions.append((next_pos - origin).normalized())
		tips.append(next_pos)
		remaining -= 1
	# 各枝へ1体ずつ交互に配り、一方向が全対象枠を使うのを防ぐ。
	var branch := 0
	while remaining > 0 and not tips.is_empty() and state.phase == RunState.Phase.PLAY:
		var from := tips[branch]
		var next := _nearest(from, reach, used)
		if next < 0:
			tips.remove_at(branch)
		else:
			tips[branch] = _strike(from, next, dmg, used, segments)
			remaining -= 1
			branch += 1
		if branch >= tips.size():
			branch = 0
	state.emit(&"bolt", {"segments": segments})

func _nearest(from: Vector2, reach: float, used: Dictionary,
		directions: Array[Vector2] = [], separation := 0.0) -> int:
	build.combat.nearby(from, reach, _buf)
	var t := build.enemies.table
	var next := -1
	var best := reach * reach
	for i in _buf:
		if t.meteor_index[i] >= 0 or used.has(t.id[i]):
			continue
		var offset := t.pos[i] - from
		var d := offset.length_squared()
		if d >= best:
			continue
		var separated := true
		for direction in directions:
			if absf(direction.angle_to(offset)) < separation:
				separated = false
				break
		if separated:
			best = d
			next = i
	return next

func _strike(from: Vector2, next: int, dmg: float, used: Dictionary, segments: PackedVector2Array) -> Vector2:
	var t := build.enemies.table
	used[t.id[next]] = true
	var pos := t.pos[next]
	segments.append(from)
	segments.append(pos)
	build.combat.damage_enemy(next, dmg, {"cause": &"contactArc", "dir": (pos - from).normalized()})
	return pos
