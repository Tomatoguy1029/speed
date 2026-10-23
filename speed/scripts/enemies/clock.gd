## とけい座：機体を追いながら、長針と短針の刃を回し続ける。
extends EnemyBehavior

func step(i: int, dt: float) -> void:
	_chase(i, dt)
	_clock(i, dt)

func admit_due(_i: int, _dt: float) -> bool:
	return true

## とけい座：長針と短針が刃として回り続ける。針は付いて動く残る線で、速さが違う。
func _clock(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	var links := t.links[i]
	# 針が消されていたら（ボスの撃破など）作り直す
	if not links.is_empty() and not (projectiles.owns_hazard(links[0], i, t.id[i]) and projectiles.owns_hazard(links[1], i, t.id[i])):
		links = PackedInt32Array()
	if links.is_empty():
		var dmg := float(p.bullet_dmg)
		for k in 2:
			var length := float(p.hand_long) if k == 0 else float(p.hand_short)
			var h := projectiles.fire_wall(t.pos[i], 0.0, length, float(p.hand_width), float(p.telegraph), 1e9, dmg, t.color[i])
			projectiles.attach_hazard(h, i)
			links.append(h)
		t.links[i] = links
	t.spin[i] += dt
	var a0 := t.spin[i] * float(p.long_speed)
	var a1 := t.spin[i] * float(p.short_speed) + PI
	projectiles.move_hazard(links[0], t.pos[i], a0)
	projectiles.move_hazard(links[1], t.pos[i], a1)
