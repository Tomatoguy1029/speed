## W27 残像機。実際の突進区間を実秒で遅延再生し、通常ram威力の合計予算を機数で分ける。
## 経路・威力・機数を突進ごとに保持し、次の突進や強化で再配分しない。
extends WeaponBehavior

const MAX_DASHES := 8
const MAX_LEGS := 2048
const MAX_RECORD_SECONDS := 4.0
const FADE_SECONDS := 0.12

var echoes: Array[Dictionary] = []
var _current: Dictionary = {}
var _clock := 0.0
var _rows := PackedInt32Array()

func level_value(key: String) -> float:
	var values: Array = p(key, [])
	return float(values[clampi(level - 1, 0, values.size() - 1)]) if not values.is_empty() else 0.0

func on_launch(_full: bool) -> void:
	on_end()
	var count := clampi(int(level_value("echo_count_by_level")), 1, 8)
	var delay := clampf(float(p("echo_delay")), 0.02, 0.5)
	var copies: Array[Dictionary] = []
	for k in count:
		copies.append({"delay": delay * (k + 1), "cursor": 0, "progress": 0.0,
			"hits": {}, "pos": state.ship_pos, "dir": state.ship_heading, "alpha": 0.0})
	_current = {"legs": [], "copies": copies, "start": _clock, "until": _clock,
		"end": false, "share": maxf(0.0, level_value("echo_total_by_level")) / count}
	echoes.append(_current)
	if echoes.size() > MAX_DASHES:
		echoes.pop_front()

func on_trail(run: TraceRun, a: Vector2, b: Vector2) -> void:
	if run == null or _current.is_empty() or not state.tracing or a.is_equal_approx(b):
		return
	if _current.legs.size() >= MAX_LEGS or _clock - float(_current.start) >= MAX_RECORD_SECONDS:
		on_end()
		return
	# 1固定更新内に曲線の複数区間を通っても、長さ/rateで区間ごとの時刻を保つ。
	var start := maxf(_clock, float(_current.until))
	var finish := start + a.distance_to(b) / maxf(run.rate, 1.0)
	_current.legs.append({"a": a, "b": b, "start": start, "finish": finish,
		"power": atk(), "radius": cfg.trace_radius})
	_current.until = finish

func on_end() -> void:
	if not _current.is_empty():
		_current.end = true
	_current = {}

## BuildManagerから実秒で更新する。描画の世界スロー・ボーナスの時計に依存しない。
## ポーズ・カード選択・ヒットストップ中は呼び出し元が更新を止める。
func replay(dt: float) -> void:
	if state.phase != RunState.Phase.PLAY:
		return
	_clock += dt
	for echo in echoes:
		for copy in echo.copies:
			_advance(echo, copy)
			if state.phase != RunState.Phase.PLAY:
				clear()
				return
	# 最後の分身が消えたら経路と敵IDの集合を一緒に解放する。異常に長い記録も打ち切る。
	echoes = echoes.filter(func(e): return _clock < float(e.start) + MAX_RECORD_SECONDS + 4.0 \
		and (not e.end or _clock <= float(e.until) + float(e.copies.back().delay) + FADE_SECONDS))

func clear() -> void:
	echoes.clear()
	_current = {}

func _advance(echo: Dictionary, copy: Dictionary) -> void:
	var now := _clock - float(copy.delay)
	var legs: Array = echo.legs
	while int(copy.cursor) < legs.size():
		var leg: Dictionary = legs[copy.cursor]
		if now < float(leg.start):
			break
		var progress := clampf((now - float(leg.start)) / maxf(float(leg.finish) - float(leg.start), 0.000001), 0.0, 1.0)
		var a: Vector2 = leg.a.lerp(leg.b, float(copy.progress))
		var b: Vector2 = leg.a.lerp(leg.b, progress)
		copy.pos = b
		copy.dir = (leg.b - leg.a).normalized()
		copy.alpha = 1.0
		if progress > float(copy.progress):
			_hit_along(copy, a, b, float(leg.power), float(leg.radius), float(echo.share))
			if state.phase != RunState.Phase.PLAY:
				return
		if progress < 1.0:
			copy.progress = progress
			return
		copy.cursor += 1
		copy.progress = 0.0
	if echo.end and int(copy.cursor) >= legs.size():
		copy.alpha = clampf(1.0 - (now - float(echo.until)) / FADE_SECONDS, 0.0, 1.0) if not legs.is_empty() else 0.0

func _hit_along(copy: Dictionary, a: Vector2, b: Vector2, power: float, radius: float, share: float) -> void:
	var pad := Vector2.ONE * radius
	build.combat.in_rect(a.min(b) - pad, a.max(b) + pad, _rows)
	var t := build.enemies.table
	for i in _rows:
		if t.dead[i] != 0 or copy.hits.has(t.id[i]):
			continue
		var hit_t := Geom.seg_circle_t(a, b, t.pos[i], t.r[i] + radius)
		if hit_t < 0.0:
			continue
		copy.hits[t.id[i]] = true
		# 貫通可否は記録時の通常ram威力、実ダメージはその分配分だけ。クリティカルは複製しない。
		if not build.combat.can_pierce(power, i, false):
			continue
		build.combat.damage_enemy(i, power * share, {"cause": &"afterimage", "dir": copy.dir,
			"impact": a.lerp(b, hit_t), "knock": 0.0, "no_crit": true})
		if state.phase != RunState.Phase.PLAY:
			return
