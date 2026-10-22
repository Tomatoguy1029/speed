## 追跡（いちばん多い雑魚）：機体へまっすぐ、決まった速さで向かう（仕様書 11.5）。
extends EnemyBehavior

func setup(system: EnemySystem, behavior_name: StringName, idx: int) -> void:
	super(system, behavior_name, idx)
	custom_loop = true

## 追跡（いちばん多い雑魚）は、関数を呼ばずにここで計算する（仕様書 11.5）。
func tick_rows(rows: PackedInt32Array, dt: float) -> void:
	var t := table
	var vc := state.view_center
	var vh := state.view_half
	var ship := state.ship_pos
	var pos := t.pos
	var vel := t.vel
	var facing := t.facing
	var age := t.age
	var hit_cd := t.hit_cd
	var guard := t.guard
	var flash := t.flash
	var dead := t.dead
	var shove_time := t.shove_time
	var knock_t := t.knock_t
	var speed := t.speed
	var r := t.r
	var now := state.world_time
	var body_move := field.body_speed_max
	var body_gap := t.body_gap
	var body_gap_pos := t.body_gap_pos
	var body_gap_time := t.body_gap_time
	var stone := t.stone
	var held := t.held
	var lod_lim := vh * 1.25 + Vector2(300, 300)
	for i in rows:
		if dead[i] != 0 or held[i] != 0:
			continue
		if stone[i] > 0.0:
			stone[i] -= dt
			vel[i] = Vector2.ZERO
			continue
		var a := age[i] + dt
		age[i] = a
		if hit_cd[i] > 0.0:
			hit_cd[i] -= dt
		if guard[i] > 0.0:
			guard[i] -= dt
		if flash[i] > 0.0:
			flash[i] -= dt
		var from := pos[i]
		var rel := from - vc
		# 画面から遠い敵は、m.LOD 回に1回だけ向きを決め直す。間の回は今の速度で進むだけ
		if absf(rel.x) > lod_lim.x or absf(rel.y) > lod_lim.y:
			if (t.id[i] + m._lod) % m.LOD != 0 and shove_time[i] <= 0.0 and knock_t[i] <= 0.0:
				pos[i] = from + vel[i] * dt
				continue
		if shove_time[i] > 0.0 or knock_t[i] > 0.0:
			m.motion._update_pushed(i, dt)
		else:
			# 機体へまっすぐ、決まった速さで向かう（旋回・慣性なし）
			var d := ship - from
			var dist := d.length()
			var v := Vector2.ZERO
			if dist > 0.001:
				var u := d / dist
				v = u * speed[i]
				facing[i] = u.angle()
			vel[i] = v
			pos[i] = from + v * dt
		var at := pos[i]
		var margin := r[i] + vel[i].length() * dt
		var gap := body_gap[i]
		if gap >= 0.0 and gap - (at.distance_to(body_gap_pos[i]) + (now - body_gap_time[i]) * body_move) > margin:
			continue
		gap = field.body_gap(at, 4.0)
		body_gap[i] = maxf(gap, 0.0)
		body_gap_pos[i] = at
		body_gap_time[i] = now
		if gap < margin:
			field.collide_enemy(i, from)
