## T06 クリティカルランス：クリティカルのたびに、進む向きへ貫くビーム。ビームからは再び発動しない（一覧 docs/game/catalog/traits.md）。
extends TraitBehavior

var _next_time := 0.0
var _buf := PackedInt32Array()

func on_critical(from: Vector2) -> void:
	if state.time < _next_time or state.phase != RunState.Phase.PLAY:
		return
	_next_time = state.time + float(def.params.cooldown)
	var v := state.ship_vel
	var u := v.normalized() if v.length() > 1.0 else state.ship_heading
	var length := val("length")
	var width := val("width")
	var to := from + u * length
	var pad := Vector2(width / 2.0, width / 2.0)
	build.combat.in_rect(from.min(to) - pad, from.max(to) + pad, _buf)
	var dmg := atk() * val("damage")
	var t := build.enemies.table
	for i in _buf:
		if t.dead[i] != 0 or Geom.seg_circle_t(from, to, t.pos[i], t.r[i] + width / 2.0) < 0.0:
			continue
		build.combat.damage_enemy(i, dmg, {"cause": &"critBeam", "no_crit": true, "dir": u, "knock": def.params.knock})
		if state.phase != RunState.Phase.PLAY:
			return
	state.emit(&"beam", {"from": from, "to": to, "width": width})
