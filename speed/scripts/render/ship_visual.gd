## 機体と噴射の表示。表示を生成したランだけが機体の画像を持つ。
extends RefCounted
const AIRSHIP := preload("res://assets/pixel/airship.png")
const AIRSHIP_FLAME := preload("res://assets/pixel/airship_flame.png")
const AIRSHIP_BLUE_FLAME := preload("res://assets/pixel/airship_blue_flame.png")
const AIRSHIP_SPARK := preload("res://assets/pixel/airship_spark.png")
const SHIELD_VISUAL := preload("res://scripts/render/shield_visual.gd")
var rm: RunPresentation
var _jet_time := 0.0
var _exhaust: Array[Dictionary] = []
var state: RunState:
	get: return rm.state
var cfg: GameConfig:
	get: return rm.cfg
var run: RunSimulation:
	get: return rm.run
func setup(render: RunPresentation) -> void:
	rm = render
func clear() -> void:
	_exhaust.clear()
func _px(value: float) -> float:
	return rm._px(value)

func update(dt: float) -> void:
	if dt <= 0.0:
		return
	for sample in _exhaust:
		sample.life -= dt
	_exhaust = _exhaust.filter(func(sample): return sample.life > 0.0)
	if state.phase != RunState.Phase.PLAY and state.phase != RunState.Phase.FINISHING:
		return
	if state.drawing or state.hitstop > 0.0:
		return
	var animation_speed := state.ship_vel.length()
	if state.tracing and run.draw.run != null:
		animation_speed = run.draw.run.rate
	_jet_time += dt * clampf(animation_speed / cfg.base_max_speed, 0.0, 3.0)
	if state.ship_vel.length() < 5.0:
		return
	var tail := state.ship_pos - state.ship_heading * 22.0 * cfg.character_scale
	if not _exhaust.is_empty():
		var distance: float = tail.distance_to(_exhaust.back().pos)
		if distance > maxf(120.0, state.ship_vel.length() * dt * 3.0):
			_exhaust.clear()
		elif distance < 2.0 * cfg.character_scale:
			return
	_exhaust.append({"pos": tail, "life": 0.24})
	if _exhaust.size() > 48:
		_exhaust.pop_front()

func draw_exhaust(c: CanvasItem) -> void:
	var escort = run.loadout.weapon_behaviors.get(&"W26")
	if escort != null and escort.active: return
	var sonic := rm._blue_exhaust()
	var trail_color := Color(0.3, 0.65, 1.0) if sonic else Color(1.0, 0.57, 0.3)
	for i in range(1, _exhaust.size()):
		var fade: float = _exhaust[i - 1].life / 0.24
		trail_color.a = fade * 0.18
		c.draw_line(_exhaust[i - 1].pos, _exhaust[i].pos,
			trail_color, 3.0 * cfg.character_scale)
	if state.phase == RunState.Phase.DYING or state.phase == RunState.Phase.ENDED:
		return
	var size := AIRSHIP.get_size() * cfg.character_scale
	# 上側10px・下側20pxの余白を除いた機体本体の中心へ合わせる。
	var rect := Rect2(Vector2(-AIRSHIP.get_width() / 2.0, -30.0) * cfg.character_scale, size)
	var frame := int(_jet_time * 12.0) % 3
	var region := Rect2(frame * AIRSHIP.get_width(), 0, AIRSHIP.get_width(), AIRSHIP.get_height())
	c.draw_set_transform(state.ship_pos, state.ship_heading.angle() + PI / 2.0)
	var flame := AIRSHIP_BLUE_FLAME if sonic else AIRSHIP_FLAME
	c.draw_texture_rect_region(flame, rect, region)
	c.draw_texture_rect_region(AIRSHIP_SPARK, rect, region, Color(1, 1, 1, 0.65))
	c.draw_set_transform(Vector2.ZERO)

func draw_ship(c: CanvasItem) -> void:
	if state.phase == RunState.Phase.DYING and run.sequence_t >= cfg.death_freeze_time:
		SHIELD_VISUAL.hide_equipped(c)
		return
	var p := state.ship_pos
	for id in [&"W01", &"W02"]:
		var gun = run.loadout.weapon_behaviors.get(id)
		if gun != null and gun.recoil > 0.0: p -= state.ship_heading * (2.0 if gun.recoil > 0.06 else 1.0) * 1.82 * cfg.character_scale
	var R := cfg.ship_radius
	var col := Color.WHITE
	var hurt := state.ship_hurt > 0.0
	if hurt:
		col = Color("#ff6b5a")
		if state.phase != RunState.Phase.PAUSED and state.phase != RunState.Phase.LEVELUP:
			p.x += randf_range(-1.0, 1.0) * _px(cfg.ship_hurt_shake)
	if state.ship_invuln > 0.0 and fmod(state.time * 20.0, 2.0) < 1.0:
		col.a = 0.5
	var dir := state.ship_heading
	var size := AIRSHIP.get_size() * cfg.character_scale
	c.draw_set_transform(p, dir.angle() + PI / 2.0)
	var rect := Rect2(Vector2(-AIRSHIP.get_width() / 2.0, -30.0) * cfg.character_scale, size)
	rm._draw_equipment_parts(c, rect, col, true)
	c.draw_texture_rect(AIRSHIP, rect, false, col)
	rm._draw_equipment_parts(c, rect, col, false)
	c.draw_set_transform(Vector2.ZERO)
	for visual in rm._equipment_visuals.values():
		if visual.active:
			visual.draw_extra(c, p, col)
	SHIELD_VISUAL.equipped(c, rm, R, cfg.character_scale, p)
	for effect in rm.shield_transfers:
		SHIELD_VISUAL.transfer(c, effect, state.ship_pos)
	# HP バー（機体の真下、仕様書 17）
	var frac := clampf(state.ship_hp / state.stats.max_hp, 0.0, 1.0)
	var w := _px(44.0)
	var top := p + Vector2(-w / 2.0, R + _px(10.0))
	c.draw_rect(Rect2(top - Vector2(_px(1), _px(1)), Vector2(w + _px(2), _px(7))), Color(0, 0, 0, 0.55))
	c.draw_rect(Rect2(top, Vector2(w * frac, _px(5.0))), Color("#ff5a4a") if frac < 0.3 else Color("#5dffa0"))
