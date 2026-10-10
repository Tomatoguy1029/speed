## W03 吹き飛ばし衝角：高速で触れた敵を進む向きへ吹き飛ばし、ほかの敵にぶつける（一覧 docs/game/catalog/weapons.md）。
## 倒した大型の敵は破片を扇状に飛ばし、小型の敵は1つの死体として飛ばす。
extends WeaponBehavior

var _buf := PackedInt32Array()

func _speed() -> float:
	return float(p("speed_base")) + float(p("speed_per_tier")) * tier()

func _dmg() -> float:
	return atk() * float(p("damage")) * dmg_k()

func on_contact(i: int, _hit: Vector2, dir: Vector2) -> void:
	var t := build.enemies.table
	var v := _speed()
	if t.dead[i] != 0:
		if t.hull_scattered[i] == 0 and not build.projectiles.scatter_hull(i, dir, v, _dmg()):
			build.projectiles.fling_corpse(i, dir * v, _dmg())
	else:
		t.shove_time[i] = p("shove_time")
		t.shove_vel[i] = dir * v
		t.shove_dmg[i] = _dmg()
		t.shove_hits[i] = {t.id[i]: true}
		t.vel[i] = dir * v

## 押し出されている敵が、ほかの敵にぶつかったらダメージを与える。
func tick(_dt: float, _busy: bool) -> void:
	var t := build.enemies.table
	var shoved := t.shoved
	for i in shoved.size():
		if shoved[i] == 0 or t.alive[i] == 0:
			continue
		shoved[i] = 0
		if t.dead[i] != 0:
			continue
		var from := t.shove_from[i]
		var pos := t.pos[i]
		var r := t.r[i]
		var pad := Vector2(r, r)
		var hits: Dictionary = t.shove_hits[i]
		build.combat.in_rect(from.min(pos) - pad, from.max(pos) + pad, _buf)
		for other in _buf:
			if other == i or hits.has(t.id[other]):
				continue
			if Geom.seg_circle_t(from, pos, t.pos[other], t.r[other] + r) < 0.0:
				continue
			hits[t.id[other]] = true
			var sv := t.shove_vel[i]
			var sp := sv.length()
			build.combat.damage_enemy(other, t.shove_dmg[i], {"cause": &"knockbackChain", "dir": sv / sp if sp > 0.0 else Vector2.ZERO, "knock": p("chain_knock")})
			state.emit(&"ring", {"pos": t.pos[other], "radius": t.r[other] + 30.0, "color": Color("#ff986b"), "life": 0.25})
			if state.phase != RunState.Phase.PLAY:
				return
