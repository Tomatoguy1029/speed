extends HeroBehavior

func capture_first_trace() -> bool:
	if not active() or not state.twin_first.is_empty():
		return false
	# ふたご座の力：1本目を取っておき、2本目を好きな所から描く（長さの上限は同じ）
	state.gauge = maxf(0.0, state.gauge - state.draw_start_charge * minf(1.0, state.draw_length / state.draw_limit))
	state.twin_first = state.draw_points
	state.draw_points = PackedVector2Array()
	state.draw_length = 0.0
	state.draw_started = false
	state.draw_blocked = false
	state.emit(&"twin_first")
	return true
