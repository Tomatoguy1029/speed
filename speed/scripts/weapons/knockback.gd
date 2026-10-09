## W03 吹き飛ばし衝角：高速で触れた敵を進む向きへ吹き飛ばし、ほかの敵にぶつける（一覧 docs/game/catalog/weapons.md）。
## 倒した大型の敵は破片を扇状に飛ばし、小型の敵は1つの死体として飛ばす。
extends WeaponBehavior

var _buf: Array = []

func _speed() -> float:
	return float(p("speed_base")) + float(p("speed_per_tier")) * tier()

func _dmg() -> float:
	return atk() * float(p("damage")) * dmg_k()

func on_contact(e: Enemy, _hit: Vector2, dir: Vector2) -> void:
	var v := _speed()
	if e.dead:
		if not e.hull_scattered and not build.projectiles.scatter_hull(e, dir, v, _dmg()):
			build.projectiles.fling_corpse(e, dir * v, _dmg())
	else:
		e.shove_time = p("shove_time")
		e.shove_vel = dir * v
		e.shove_dmg = _dmg()
		e.shove_hits = {e.id: true}
		e.vel = dir * v

## 押し出されている敵が、ほかの敵にぶつかったらダメージを与える。
func tick(_dt: float, _busy: bool) -> void:
	for e: Enemy in build.enemies.list:
		if e.dead or not e.shoved:
			continue
		e.shoved = false
		var from := e.shove_from
		var pad := Vector2(e.r, e.r)
		build.combat.in_rect(from.min(e.pos) - pad, from.max(e.pos) + pad, _buf)
		for other: Enemy in _buf:
			if other == e or e.shove_hits.has(other.id):
				continue
			if Geom.seg_circle_t(from, e.pos, other.pos, other.r + e.r) < 0.0:
				continue
			e.shove_hits[other.id] = true
			var sp := e.shove_vel.length()
			build.combat.damage_enemy(other, e.shove_dmg, {"cause": &"knockbackChain", "dir": e.shove_vel / sp if sp > 0.0 else Vector2.ZERO, "knock": p("chain_knock")})
			state.emit(&"ring", {"pos": other.pos, "radius": other.r + 30.0, "color": Color("#ff986b"), "life": 0.25})
			if state.phase != RunState.Phase.PLAY:
				return
