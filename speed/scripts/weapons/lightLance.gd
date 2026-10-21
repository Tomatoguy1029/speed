## W24 光の槍。なぞり中の正面だけを掃き、敵IDごとに1突進1回の追加直撃。
## 体当たりは既存のまま別計算。光跡・命中閃光には攻撃判定を持たせない。
extends WeaponBehavior

var _hit_ids: Dictionary = {}
var _dash_id := -1
var _rows := PackedInt32Array()

func level_value(key: String) -> float:
	var values: Array = p(key, [])
	return float(values[clampi(level - 1, 0, values.size() - 1)]) if not values.is_empty() else 0.0

func reach() -> float:
	return (float(p("nose_offset")) + level_value("length_by_level")) * cfg.character_scale

func on_launch(_full: bool) -> void:
	_hit_ids.clear()
	_dash_id = state.dash_id

func on_trail(run: TraceRun, p0: Vector2, p1: Vector2) -> void:
	if run == null or not state.tracing or state.phase != RunState.Phase.PLAY:
		return
	if _dash_id != state.dash_id:
		on_launch(false)
	var dir := state.ship_heading.normalized()
	if dir.is_zero_approx():
		return
	var width := float(p("hit_half_width")) * cfg.character_scale
	var nose := float(p("nose_offset")) * cfg.character_scale
	var start := p0 + dir * nose
	var end := p1 + dir * reach()
	var pad := Vector2.ONE * width
	build.combat.in_rect(start.min(end) - pad, start.max(end) + pad, _rows)
	var t := build.enemies.table
	var damage := atk() * level_value("damage_by_level")
	for i in _rows:
		if t.dead[i] != 0 or _hit_ids.has(t.id[i]):
			continue
		var hit_t := Geom.seg_circle_t(start, end, t.pos[i], t.r[i] + width)
		if hit_t < 0.0:
			continue
		_hit_ids[t.id[i]] = true
		# damage_enemy が盾・特殊撃破条件・無敵を扱う。武器直撃はクリティカルを再抽選しない。
		var before := t.hp[i]
		build.combat.damage_enemy(i, damage, {"cause": &"lightLance", "dir": dir,
			"impact": start.lerp(end, hit_t), "knock": 0.0, "no_crit": true})
		if t.hp[i] < before:
			state.emit(&"lance_hit", {"pos": start.lerp(end, hit_t), "dir": dir, "level": level})
		if state.phase != RunState.Phase.PLAY:
			return
