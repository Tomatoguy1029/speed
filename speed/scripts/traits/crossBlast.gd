## T02 交差爆破：過去12秒の線を横切ると、交わった点で爆発。同じ交点は1回の突進で1回だけ（一覧 docs/game/catalog/traits.md）。
extends TraitBehavior

## 記録した線の区間：a、b、until
var paths: Array = []
var _pending: Array = []
var _used: Dictionary = {}

func on_launch(_full: bool) -> void:
	_pending = []
	_used = {}

func on_trail(_run: TraceRun, p0: Vector2, p1: Vector2) -> void:
	if p0.distance_squared_to(p1) < 1e-6:
		return
	var now := state.time
	for old in paths:
		if old.until <= now:
			continue
		var x = Geom.seg_cross(p0, p1, old.a, old.b)
		if x == null:
			continue
		var key := "%d,%d" % [roundi(x.x / 20.0), roundi(x.y / 20.0)]
		if _used.has(key):
			continue
		_used[key] = true
		build.combat.explode(x, val("radius"), atk() * val("damage"), {"cause": &"crossBlast", "color": Color("#ff6bd5"), "knock": def.params.knock})
		if state.phase != RunState.Phase.PLAY:
			return
	_pending.append({"a": p0, "b": p1, "until": now + float(def.params.memory)})

func on_end() -> void:
	var now := state.time
	paths = paths.filter(func(p): return p.until > now)
	paths.append_array(_pending)
	var max_n := int(def.params.max_segments)
	if paths.size() > max_n:
		paths = paths.slice(paths.size() - max_n)
	_pending = []
