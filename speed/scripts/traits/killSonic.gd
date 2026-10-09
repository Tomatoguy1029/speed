## T05 連鎖ソニック：1回の突進で一定数を倒すたびに衝撃波（一覧 docs/game/traits.md）。
## 衝撃波で倒した敵では、次の衝撃波を起こさない。
extends TraitBehavior

var _kills := 0
var _next := 0
var _active := false

func _every() -> int:
	return maxi(3, int(val("kills")))

func on_launch(_full: bool) -> void:
	_kills = 0
	_next = _every()
	_active = true

func on_end() -> void:
	_active = false

func on_kill(cause: StringName) -> void:
	if not _active:
		return
	_kills += 1
	if cause == &"killSonic" or _kills < _next or state.phase != RunState.Phase.PLAY:
		return
	_next = _kills + _every()
	build.run_sonic(&"killSonic", val("radius"), atk() * val("damage"), def.params.knock, def.params.travel)
