## T36 フルバースト：倍率の正はLoadoutSystem。満タンへの遷移だけを通知する。
extends TraitBehavior
var active := false
func tick(_dt: float, _busy: bool) -> void:
	var ready := state.gauge >= 1.0
	if ready and not active:
		state.emit(&"full_burst_ready", {"pos": state.ship_pos})
	active = ready
