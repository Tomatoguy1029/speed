## 噛みつく雑魚。
extends EnemyBehavior

func setup(system: EnemySystem, behavior_name: StringName, idx: int) -> void:
	super(system, behavior_name, idx)
	custom_loop = true

func admit_duration(i: int) -> float:
	return float(table.def[i].params.bite_telegraph) + 0.1

## 噛みつく雑魚（小さなヘビなど。ステージごとに見た目だけ変える）：追ってきて、機体が噛みつける距離に入ると一瞬光って構え（WINDUP）、
## その場で小さく噛みつく（体の前の小さな範囲が一瞬当たる）。噛みついたあとは少し休む（RECOVER）。弾は出さない。
## 数の多い雑魚なので、関数をまとめて呼ばずにここで計算する。定義の数値は、同じ定義が続くあいだは読み直さない。
func tick_rows(rows: PackedInt32Array, dt: float) -> void:
	var t := table
	var vc := state.view_center
	var lim := state.view_half * 1.25 + Vector2(300, 300)
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
	var stone := t.stone
	var held := t.held
	var r := t.r
	var mode := t.mode
	var timer := t.timer
	var charge := t.charge
	var now := state.world_time
	var director = projectiles.director
	var body_move := field.body_speed_max
	var body_gap := t.body_gap
	var body_gap_pos := t.body_gap_pos
	var body_gap_time := t.body_gap_time
	var cached: EnemyDef = null
	var reach_add := 0.0
	var half_reach := 0.0
	var telegraph := 1.0
	var rest := 0.0
	var bite_radius := 0.0
	var bite_dmg := 0.0
	projectiles.lab_context = 0
	for i in rows:
		if dead[i] != 0 or held[i] != 0:
			continue
		if stone[i] > 0.0:
			stone[i] -= dt
			vel[i] = Vector2.ZERO
			continue
		age[i] += dt
		if hit_cd[i] > 0.0:
			hit_cd[i] -= dt
		if guard[i] > 0.0:
			guard[i] -= dt
		if flash[i] > 0.0:
			flash[i] -= dt
		var from := pos[i]
		# 出現時に解決したvalueが0なら、枠・待機・追跡へ入れない。
		var managed := t.attack_managed[i] != 0
		projectiles.lab_context = 0
		if managed and director != null and mode[i] == EnemyTable.Mode.WINDUP:
			projectiles.lab_context = director.token(m._lab_owner(i))
		# 画面から遠い敵は、m.LOD 回に1回だけ、まとめた時間で判断する。間の回は今の速度で進むだけ
		var bdt := dt
		var rel := from - vc
		if absf(rel.x) > lim.x or absf(rel.y) > lim.y:
			if (t.id[i] + m._lod) % m.LOD != 0 and shove_time[i] <= 0.0 and knock_t[i] <= 0.0:
				pos[i] = from + vel[i] * dt
				continue
			bdt = dt * m.LOD
		if shove_time[i] > 0.0 or knock_t[i] > 0.0:
			m.motion._update_pushed(i, dt)
		else:
			var def: EnemyDef = t.def[i]
			if def != cached:
				cached = def
				var p := def.params
				reach_add = float(p.bite_reach) + cfg.ship_radius
				half_reach = float(p.bite_reach) * 0.5
				telegraph = float(p.bite_telegraph)
				rest = float(p.bite_rest)
				bite_radius = float(p.bite_radius)
				bite_dmg = float(p.bullet_dmg)
			var m := mode[i]
			if _move_without_bite(i, bdt):
				pass
			elif m == EnemyTable.Mode.WINDUP:
				# 止まって機体の方へ向き直り、予告が終わったら噛みつく
				vel[i] *= maxf(0.0, 1.0 - 8.0 * bdt)
				_turn_toward(i, (ship - from).angle(), t.turn[i] * 2.0, bdt)
				timer[i] -= bdt
				charge[i] = 1.0 - maxf(0.0, timer[i]) / telegraph
				if timer[i] <= 0.0:
					var at := from + Vector2.from_angle(facing[i]) * (r[i] + half_reach)
					projectiles.fire_zone(at, bite_radius, 0.0, bite_dmg, ProjectileSystem.HazardStyle.BITE, t.color[i].lightened(0.4))
					charge[i] = 0.0
					mode[i] = EnemyTable.Mode.RECOVER
					timer[i] = rest
			else:
				# 噛みつきは共通に保ち、派生する種類は追跡の速度だけを変える。
				var d := ship - from
				var dist := d.length()
				vel[i] = _pursuit_velocity(i, ship, bdt)
				if vel[i].length_squared() > 0.000001:
					facing[i] = vel[i].angle()
				if m == EnemyTable.Mode.RECOVER:
					timer[i] -= bdt
					if timer[i] <= 0.0:
						mode[i] = EnemyTable.Mode.MOVE
				else:
					var reach := r[i] + reach_add
					if dist * dist <= reach * reach:
						if not managed or _lab_admit(i, bdt):
							mode[i] = EnemyTable.Mode.WINDUP
							timer[i] = telegraph
							flash[i] = 0.1
			if dead[i] != 0:
				continue
			pos[i] += vel[i] * dt
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
	projectiles.lab_context = 0

## 機体へまっすぐ、決まった速さで向かう（_chase と同じ）。
func _pursuit_velocity(i: int, ship: Vector2, _dt: float) -> Vector2:
	var d := ship - table.pos[i]
	return d.normalized() * table.speed[i] if d.length_squared() >= 0.000001 else Vector2.ZERO

## 守る雑魚など、噛みつきを休んで別の移動をする種類の入口。
## true のときも、共通の石化・外力・移動・天体衝突は同じ更新で処理する。
func _move_without_bite(_i: int, _dt: float) -> bool:
	return false
