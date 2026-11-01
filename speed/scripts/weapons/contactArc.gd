## W17 接触電撃：接触点の全周を角度帯に分け、敵がいる方向へ枝を配る（一覧 docs/game/catalog/weapons.md）。
## 全枝で Lv × chains_per_level 体の追加対象枠を共有。同じ敵には1回だけ。隕石には流れない。
extends WeaponBehavior

var _buf := PackedInt32Array()
var _ready_at := 0.0

const COOLDOWN_EPSILON := 0.000001

func on_any_contact(target: int) -> void:
	var t := ctx.enemies.table
	if t.meteor_index[target] >= 0:
		return
	if state.world_time + COOLDOWN_EPSILON < _ready_at:
		return
	_ready_at = state.world_time + float(p("cooldown"))
	var dmg := atk() * float(p("damage")) * dmg_k()
	var used := {t.id[target]: true}
	var origin := t.pos[target]
	var segments := PackedVector2Array([state.ship_pos, origin])
	if t.dead[target] == 0:
		ctx.combat.damage_enemy(target, dmg, {"cause": &"contactArc"})
	var reach: float = area(float(p("range")))
	var remaining := level * int(p("chains_per_level"))
	var tips: Array[Vector2] = []
	var counts: Array = p("branches_by_level")
	var count := mini(maxi(1, int(counts[clampi(level - 1, 0, counts.size() - 1)])), remaining)
	# Lv ごとの枝数で全周を分割。空の角度帯の枠は、実在する枝の続きへ回す。
	for next in _roots(origin, reach, used, count):
		if state.phase != RunState.Phase.PLAY:
			break
		if t.dead[next] != 0:
			continue
		var next_pos := _strike(origin, next, dmg, used, segments)
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

## 接触点の近傍を1回だけ探索し、全周の各角度帯で最も近い敵を選ぶ。
func _roots(origin: Vector2, reach: float, used: Dictionary, count: int) -> PackedInt32Array:
	if count <= 0:
		return PackedInt32Array()
	ctx.combat.nearby(origin, reach, _buf)
	var t := ctx.enemies.table
	var roots := PackedInt32Array()
	roots.resize(count)
	roots.fill(-1)
	var distances := PackedFloat64Array()
	distances.resize(count)
	distances.fill(reach * reach)
	var width := TAU / count
	for i in _buf:
		if t.meteor_index[i] >= 0 or used.has(t.id[i]):
			continue
		var offset := t.pos[i] - origin
		var sector := int(floor(fposmod(offset.angle() + width * 0.5, TAU) / width)) % count
		var d := offset.length_squared()
		if d < distances[sector]:
			distances[sector] = d
			roots[sector] = i
	var occupied := PackedInt32Array()
	for i in roots:
		if i >= 0:
			occupied.append(i)
	return occupied

func _nearest(from: Vector2, reach: float, used: Dictionary) -> int:
	ctx.combat.nearby(from, reach, _buf)
	var t := ctx.enemies.table
	var next := -1
	var best := reach * reach
	for i in _buf:
		if t.meteor_index[i] >= 0 or used.has(t.id[i]):
			continue
		var offset := t.pos[i] - from
		var d := offset.length_squared()
		if d >= best:
			continue
		best = d
		next = i
	return next

func _strike(from: Vector2, next: int, dmg: float, used: Dictionary, segments: PackedVector2Array) -> Vector2:
	var t := ctx.enemies.table
	used[t.id[next]] = true
	var pos := t.pos[next]
	segments.append(from)
	segments.append(pos)
	ctx.combat.damage_enemy(next, dmg, {"cause": &"contactArc", "dir": (pos - from).normalized(), "knock": 160.0 * post_factor(&"knockback")})
	return pos
