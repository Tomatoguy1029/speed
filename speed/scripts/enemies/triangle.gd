## みなみのさんかく座。
extends EnemyBehavior

func step(i: int, dt: float) -> void:
	_keep_distance(i, dt)
	_triangle(i, dt)
	if table.mode[i] != EnemyTable.Mode.RECOVER and _gun_timer(i, dt):
		fire_volley(i)

func admit_due(_i: int, _dt: float) -> bool:
	return true

func on_spawn(i: int, _opts: Dictionary) -> void:
	_spawn_triangle_stars(i)

## みなみのさんかく座：核の周りに3つの星を出す。
func _spawn_triangle_stars(i: int) -> void:
	var star := def_of(&"triangle_star")
	for k in 3:
		spawn_part(i, star, table.pos[i] + Vector2.from_angle(TAU * k / 3.0) * float(table.def[i].params.span))

## みなみのさんかく座：3つの星を核の周りでゆっくり回し、星の間に光の膜（触れると被弾する線）を張る。
## 星が1つでも欠けると膜が消え（mode が RECOVER）、中の核を倒せる。
func _triangle(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	t.facing[i] += float(p.spin) * dt
	var parts := t.parts[i]
	var verts := PackedVector2Array()
	for k in range(0, parts.size(), 2):
		var j := parts[k]
		var a := t.facing[i] + TAU * (k / 2) / 3.0
		var at := t.pos[i] + Vector2.from_angle(a) * float(p.span)
		if is_same(j, parts[k + 1]) and t.dead[j] == 0:
			t.pos[j] = at
		verts.append(at)
	var links := t.links[i]
	if t.mode[i] != EnemyTable.Mode.RECOVER and parts_alive(i) < 3:
		t.mode[i] = EnemyTable.Mode.RECOVER
		for h in links:
			projectiles.release_hazard(h)
		t.links[i] = PackedInt32Array()
		t.charge[i] = 0.0
		state.emit(&"membrane_break", {"points": verts, "color": t.color[i]})
		return
	if t.mode[i] == EnemyTable.Mode.RECOVER or verts.size() < 3:
		return
	if links.is_empty():
		for k in 3:
			var h := projectiles.fire_wall(verts[k], 0.0, 0.0, float(p.wall_width), float(p.telegraph), 1e9,
				float(p.bullet_dmg), t.color[i])
			projectiles.attach_hazard(h, i)
			links.append(h)
		t.links[i] = links
	for k in 3:
		var a := verts[k]
		var b := verts[(k + 1) % 3]
		projectiles.move_hazard(links[k], a, (b - a).angle(), a.distance_to(b))
