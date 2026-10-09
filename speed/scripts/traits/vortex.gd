## T03 余韻の渦：線の終点に、敵を吸い寄せる渦を残す。ボスは引き寄せない（一覧 docs/game/catalog/traits.md）。
extends TraitBehavior

## 渦：pos、radius、life、max、power
var vortexes: Array = []
var _buf: Array = []

func on_end() -> void:
	var life := val("life")
	vortexes.append({"pos": state.ship_pos, "radius": val("radius"), "life": life, "max": life, "power": val("power")})
	if vortexes.size() > 12:
		vortexes.pop_front()

func tick(dt: float, _busy: bool) -> void:
	for v in vortexes:
		v.life -= dt
		build.combat.nearby(v.pos, v.radius, _buf)
		for e: Enemy in _buf:
			if e.is_boss:
				continue
			var d: Vector2 = v.pos - e.pos
			var dist := d.length()
			if dist > v.radius or dist < 10.0:
				continue
			var move := minf(dist - 10.0, v.power * dt / maxf(1.0, e.r / 30.0))
			var from := e.pos
			e.pos += d / dist * move
			build.field.collide_enemy(e, from)
	vortexes = vortexes.filter(func(v): return v.life > 0.0)
