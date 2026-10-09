## W23 後方ブラスター：逃げながら進行方向の反対へ撃つ。
extends WeaponBehavior

const MOUNT_PIXEL := Vector2(15.5, 29.5)
var _t := 0.0

func aim_direction() -> Vector2:
	return -state.ship_heading

func mount_position() -> Vector2:
	var offset := (MOUNT_PIXEL - Vector2(15.5, 20.0)) * cfg.character_scale
	return state.ship_pos + offset.rotated(state.ship_heading.angle() + PI / 2.0)

func tick(dt: float, busy: bool) -> void:
	if busy:
		return
	var index := clampi(level, 1, def.level_steps.size()) - 1
	var interval := float(p("interval_by_level")[index])
	_t += dt
	if _t < interval:
		return
	_t = fmod(_t, interval)
	var shots := int(p("shots_by_level")[index])
	var backwards := aim_direction()
	var origin := mount_position() + backwards * 12.5 * cfg.character_scale
	for i in shots:
		var angle := backwards.angle() + (i - (shots - 1) / 2.0) * float(p("spread_step"))
		build.projectiles.fire_shot(origin, angle, atk() * float(p("damage_by_level")[index]),
			{"life": p("life"), "color": Color(p("color"))})
	state.emit(&"weapon_fire", {"id": def.id})
