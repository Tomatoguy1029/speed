## T06 クリティカルランス：クリティカルのたびに、進む向きへ貫く光の槍。槍からは再び発動しない（一覧 docs/game/catalog/traits.md）。
extends TraitBehavior

var _next_time := 0.0

func on_critical(from: Vector2) -> void:
	if state.time < _next_time or state.phase != RunState.Phase.PLAY:
		return
	_next_time = state.time + float(def.params.cooldown)
	var v := state.ship_vel
	var u := v.normalized() if v.length() > 1.0 else state.ship_heading
	ctx.projectiles.attached_attack(&"light_lances").fire(from, u, val("length"),
		val("width") * ctx.loadout.area_multiplier(), atk() * val("damage"), float(def.params.knock))
