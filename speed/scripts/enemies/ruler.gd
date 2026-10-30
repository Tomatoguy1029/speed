## じょうぎ座。
extends EnemyBehavior

func step(i: int, dt: float) -> void:
	_ruler(i, dt)

func admit_active(i: int, director, owner: String) -> bool:
	return director.owns_action(owner, table.id[i]) and (table.mode[i] in [EnemyTable.Mode.WINDUP, EnemyTable.Mode.RECOVER] \
		or not table.links[i].is_empty())

func admit_due(i: int, dt: float) -> bool:
	return table.buds[i] != 0 and table.mode[i] == EnemyTable.Mode.DASH and table.timer[i] <= dt

## じょうぎ座：1体の定規として現れ、split_delay たつと二つに分かれる（buds が左右の印 1・-1。0 は分かれる前）。
## 2体は、機体の方へ向かう縦か横の軸（facing）をそろえ、機体を左右から挟む位置へ展開する（DASH）。
## 照射の向きを予告し（WINDUP、charge が予告の進み）、それぞれ長いビームを出し続ける（RECOVER）。ビームは発射元に
## つながり、機体の移動を止める壁になる。照射が終わると、また機体を挟む位置へ展開し直す。倒した個体のビームは消える。
func _ruler(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	if t.buds[i] == 0:
		_keep_distance(i, dt)
		if t.age[i] >= float(p.split_delay):
			_split_ruler(i)
		return
	var d := Vector2.from_angle(t.facing[i])
	t.timer[i] -= dt
	match t.mode[i]:
		EnemyTable.Mode.DASH:
			var n := Vector2(-d.y, d.x)
			var goal := state.ship_pos + n * float(t.buds[i]) * float(p.half_gap) - d * float(p.emit_back)
			_steer_to(i, goal, float(p.deploy_speed), 6.0, dt)
			if t.timer[i] <= 0.0:
				t.mode[i] = EnemyTable.Mode.WINDUP
				t.timer[i] = float(p.telegraph)
				state.emit(&"enemy_laser_charge", {"id": t.id[i], "row": i})
		EnemyTable.Mode.WINDUP:
			_hold(i, dt)
			t.charge[i] = 1.0 - maxf(0.0, t.timer[i]) / float(p.telegraph)
			if t.timer[i] <= 0.0:
				var h := projectiles.fire_wall(beam_origin(i), t.facing[i], float(p.beam_len), float(p.beam_width), 0.0,
					float(p.beam_time), float(p.bullet_dmg), t.color[i])
				projectiles.hazard_style[h] = ProjectileSystem.HazardStyle.RAY
				projectiles.hazard_block[h] = 1
				projectiles.attach_hazard(h, i)
				state.emit(&"enemy_laser_fire", {"id": t.id[i]})
				t.links[i] = PackedInt32Array([h])
				t.charge[i] = 0.0
				t.mode[i] = EnemyTable.Mode.RECOVER
				t.timer[i] = float(p.beam_time)
		EnemyTable.Mode.RECOVER:
			_hold(i, dt)
			for h in t.links[i]:
				if projectiles.owns_hazard(h, i, t.id[i]):
					projectiles.move_hazard(h, beam_origin(i), t.facing[i])
			if t.timer[i] <= 0.0:
				for h in t.links[i]:
					if projectiles.owns_hazard(h, i, t.id[i]):
						projectiles.release_hazard(h)
				t.links[i] = PackedInt32Array()
				t.mode[i] = EnemyTable.Mode.DASH
				t.timer[i] = float(p.deploy_time)

## 本体とビーム端の間に隙間を設ける。予告・発射・追従で共有する。
func beam_origin(i: int) -> Vector2:
	var params: Dictionary = table.def[i].params
	var gap := maxf(0.0, float(params.get("beam_start_gap", 0.0)))
	var distance := table.r[i] + float(params.beam_width) * 0.5 + gap
	return table.pos[i] + Vector2.from_angle(table.facing[i]) * distance

## じょうぎ座（行 i）が二つに分かれる。機体への向きの縦横の大きい方を照射の軸にし、もう1体を同じ位置に出して展開を始める。
func _split_ruler(i: int) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	var rel := state.ship_pos - t.pos[i]
	var d := Vector2(signf(rel.x), 0.0) if absf(rel.x) > absf(rel.y) else Vector2(0.0, signf(rel.y))
	if d == Vector2.ZERO:
		d = Vector2.DOWN
	var halves := [i, spawn(t.def[i], t.pos[i], {"facing": d.angle(), "elite": t.elite[i] != 0, "attack_group": t.attack_group[i], "attack_value": t.attack_value[i], "attack_priority": t.attack_priority[i]})]
	for k in 2:
		var j: int = halves[k]
		t.buds[j] = 1 if k == 0 else -1
		t.facing[j] = d.angle()
		t.mode[j] = EnemyTable.Mode.DASH
		t.timer[j] = float(p.deploy_time)
		t.vel[j] = Vector2(-d.y, d.x) * float(t.buds[j]) * float(p.deploy_speed) * 0.6
	state.emit(&"ruler_split", {"pos": t.pos[i], "angle": d.angle(), "color": t.color[i]})
