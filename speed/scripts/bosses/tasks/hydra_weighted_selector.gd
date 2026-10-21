## LimboAI の重み編集を使い、抽選だけランの RNG に揃えて再現可能にする。
@tool
extends BTProbabilitySelector
var _choice := -1
var _failed: Array[int] = []
func _enter() -> void:
	_choice = -1
	_failed.clear()
func _tick(delta: float) -> Status:
	while true:
		if _choice < 0:
			var total := 0.0
			for i in get_child_count():
				if not _failed.has(i) and has_probability(i): total += get_weight(i)
			if total <= 0.0: return FAILURE
			var pick: float = agent.run_state.rng.randf() * total
			for i in get_child_count():
				if _failed.has(i) or not has_probability(i) or get_weight(i) <= 0.0: continue
				pick -= get_weight(i)
				_choice = i
				if pick < 0.0: break
		var result := get_child(_choice).execute(delta)
		if result != FAILURE: return result
		_failed.append(_choice)
		_choice = -1
	return FAILURE
func _exit() -> void:
	if _choice >= 0 and get_child(_choice).get_status() == RUNNING:
		get_child(_choice).abort()
