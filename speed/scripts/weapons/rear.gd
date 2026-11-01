## W23 後方ブラスター：逃げながら進行方向の反対へ撃つ。
extends WeaponBehavior

const MOUNT_PIXEL := Vector2(15.5, 39.5)
var _t := 0.0
var recoil := 0.0

func aim_direction() -> Vector2:
	return -state.ship_heading

func mount_position() -> Vector2:
	var offset := (MOUNT_PIXEL - Vector2(15.5, 30.0)) * cfg.character_scale
	return state.ship_pos + offset.rotated(state.ship_heading.angle() + PI / 2.0)

func tick(dt: float, busy: bool) -> void:
	recoil = maxf(0.0, recoil - dt)
	if busy:
		return
	var index := clampi(level, 1, def.level_steps.size()) - 1
	var shot_interval := shooting_interval(at_level("interval_by_level"))
	_t += dt
	if _t < shot_interval:
		return
	_t = fmod(_t, shot_interval)
	var count := shots(1)
	var backwards := aim_direction()
	var origin := mount_position() + backwards * 12.5 * cfg.character_scale
	var a := backwards.angle()
	var spread := float(p("spread_step"))
	var damage := atk() * float(p("damage_by_level")[index])
	var opts := {"life": p("life"), "pierce_left": int(at_level("pierce_by_level")), "knock": def.params.knock, "color": Color(p("color")), "visual_key": "weapon/rear"}
	for i in count:
		var angle := a + (i - (count - 1) / 2.0) * spread
		fire_shot(origin, angle, damage, opts)
	recoil = 0.12
	state.emit(&"weapon_fire", {"id": def.id, "pos": origin, "angle": a, "visual_key": "weapon/rear"})
