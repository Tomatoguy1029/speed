## みなみのさんかく座。
extends EnemyBehavior

func step(i: int, dt: float) -> void:
	_triangle(i, dt)

## 辺を動いている間（DASH）が攻撃の最中。
func admit_active(i: int, director, owner: String) -> bool:
	return table.mode[i] == EnemyTable.Mode.DASH and director.owns_action(owner, table.id[i])

## 頂点で止まる時間が終わったら、攻撃の枠を取りにいく。枠が取れない間は頂点で止まったまま。
func admit_due(i: int, dt: float) -> bool:
	return table.mode[i] == EnemyTable.Mode.MOVE and table.timer[i] <= dt

func admit_duration(i: int) -> float:
	return float(table.def[i].params.move_time) + 0.1

func on_spawn(i: int, _opts: Dictionary) -> void:
	var t := table
	# 三角の向き（spin）は出たときに決め、そのまま保つ
	t.spin[i] = state.rng.randf() * TAU
	t.mode[i] = EnemyTable.Mode.MOVE
	t.timer[i] = float(t.def[i].params.stop_time)
	t.buds[i] = 0
	t.links[i] = PackedInt32Array([-1, -1, -1])
	var star := def_of(&"triangle_star")
	for k in 3:
		spawn_part(i, star, vertex(i, k))

## みなみのさんかく座：中心（行 i、見えない）がゆっくり機体へ寄り、3つの星が三角の辺に沿って回る。
## 頂点で止まっている間（MOVE）は星に攻撃が通る。止まる時間が終わると、星は次の頂点へ辺を動く（DASH）。
## 動いている間は星に攻撃が通らず、星の後ろに赤いレーザーの軌跡（触れると被弾する残る線）が伸びる。
## buds は、星が頂点を何個進んだか。星の位置と軌跡は after_tick() で毎回置く。
func _triangle(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	_chase(i, dt)
	t.timer[i] -= dt
	match t.mode[i]:
		EnemyTable.Mode.MOVE:
			if t.timer[i] <= 0.0:
				_start_travel(i)
		EnemyTable.Mode.DASH:
			if t.timer[i] <= 0.0:
				_end_travel(i)
				t.buds[i] = (t.buds[i] + 1) % 3
				t.mode[i] = EnemyTable.Mode.MOVE
				t.timer[i] = float(p.stop_time)

## 星が次の頂点へ動き始める。残っている星ごとに、赤いレーザーの軌跡を出して星に付ける。
func _start_travel(i: int) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	t.mode[i] = EnemyTable.Mode.DASH
	t.timer[i] = float(p.move_time)
	var parts := t.parts[i]
	var links := PackedInt32Array([-1, -1, -1])
	for k in 3:
		var j := parts[2 * k]
		if not self.is_same(j, parts[2 * k + 1]) or t.dead[j] != 0:
			continue
		var a := vertex(i, k + t.buds[i])
		var b := vertex(i, k + t.buds[i] + 1)
		var h := projectiles.fire_wall(a, (b - a).angle(), 0.0, float(p.trail_width), 0.0, float(p.move_time) + 0.2,
			float(p.trail_dmg), t.color[i])
		projectiles.hazard_style[h] = ProjectileSystem.HazardStyle.TRAIL
		projectiles.attach_hazard(h, j)
		links[k] = h
	t.links[i] = links

## 星が頂点に着いた。軌跡を消す。
func _end_travel(i: int) -> void:
	var t := table
	var parts := t.parts[i]
	var links := t.links[i]
	for k in links.size():
		var h := links[k]
		if h >= 0 and projectiles.owns_hazard(h, parts[2 * k], parts[2 * k + 1]):
			projectiles.release_hazard(h)
	t.links[i] = PackedInt32Array([-1, -1, -1])

## 星の位置と軌跡を置く。止まっている間も中心は機体へ寄るので、全部の行で毎回置き直す。
## 星が全部倒れたら、中心も倒れる。
func after_tick(_dt: float) -> void:
	var t := table
	for i in rows():
		if t.alive[i] == 0 or t.dead[i] != 0:
			continue
		if parts_alive(i) == 0:
			_end_travel(i)
			projectiles.combat.kill_enemy(i, {"cause": &"collapse"})
			if t.dead[i] == 0:
				mark_dead(i)
			continue
		var p: Dictionary = t.def[i].params
		var travel := t.mode[i] == EnemyTable.Mode.DASH
		var u := clampf(1.0 - t.timer[i] / float(p.move_time), 0.0, 1.0) if travel else 0.0
		var parts := t.parts[i]
		var links := t.links[i]
		for k in 3:
			var j := parts[2 * k]
			if not self.is_same(j, parts[2 * k + 1]) or t.dead[j] != 0:
				continue
			var a := vertex(i, k + t.buds[i])
			var b := vertex(i, k + t.buds[i] + 1)
			var at := a.lerp(b, u)
			t.pos[j] = at
			t.vel[j] = t.vel[i]
			t.facing[j] = (b - a).angle()
			if travel and k < links.size() and links[k] >= 0 and projectiles.owns_hazard(links[k], j, t.id[j]):
				projectiles.move_hazard(links[k], a, (b - a).angle(), a.distance_to(at))

## 三角の頂点 n（0〜2。3以上は回り続ける）の位置。
func vertex(i: int, n: int) -> Vector2:
	var t := table
	return t.pos[i] + Vector2.from_angle(t.spin[i] + TAU * float(posmod(n, 3)) / 3.0) * float(t.def[i].params.span)
