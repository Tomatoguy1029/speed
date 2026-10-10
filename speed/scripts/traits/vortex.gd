## T03 余韻の渦：線の終点に、敵を吸い寄せる渦を残す。ボスは引き寄せない（一覧 docs/game/catalog/traits.md）。
extends TraitBehavior

## 渦：pos、radius、life、max、power
var vortexes: Array = []
var _buf := PackedInt32Array()

func on_end() -> void:
	var life := val("life")
	vortexes.append({"pos": state.ship_pos, "radius": val("radius"), "life": life, "max": life, "power": val("power")})
	if vortexes.size() > 12:
		vortexes.pop_front()

func tick(dt: float, _busy: bool) -> void:
	for v in vortexes:
		v.life -= dt
		build.combat.nearby(v.pos, v.radius, _buf)
		var t := build.enemies.table
		for i in _buf:
			if t.is_boss[i] != 0:
				continue
			var from := t.pos[i]
			var d: Vector2 = v.pos - from
			var dist := d.length()
			if dist > v.radius or dist < 10.0:
				continue
			var move := minf(dist - 10.0, v.power * dt / maxf(1.0, t.r[i] / 30.0))
			t.pos[i] = from + d / dist * move
			build.field.collide_enemy(i, from)
	vortexes = vortexes.filter(func(v): return v.life > 0.0)
