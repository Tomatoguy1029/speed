## 広がる輪・扇：angle の向きを中心に左右 arc の角度、速さ speed で半径 len まで広がる。gap_w があれば切れ目を空ける。
## 敵へのダメージ（edmg）があれば、先頭が通り過ぎた敵に1回ずつ当たる（いるか座の波動）。
extends HazardShape

func touches(ps: ProjectileSystem, i: int, ship_pos: Vector2, R: float) -> bool:
	var d := ship_pos - ps.hazard_pos[i]
	var band := ps.hazard_width[i] * 0.5 + R
	if absf(d.length() - ps.wave_radius(i)) > band:
		return false
	var a := d.angle()
	if absf(Geom.angle_diff(a, ps.hazard_angle[i])) > ps.hazard_arc[i]:
		return false
	return ps.hazard_gap_w[i] <= 0.0 or absf(Geom.angle_diff(a, ps.hazard_gap[i])) > ps.hazard_gap_w[i]

func act(ps: ProjectileSystem, i: int, dt: float) -> bool:
	if ps.hazard_edmg[i] <= 0.0:
		return true
	var t := ps.combat.enemies.table
	var now := ps.wave_radius(i)
	var before := minf(ps.hazard_len[i], maxf(0.0, ps.hazard_t[i] - dt - ps.hazard_delay[i]) * ps.hazard_speed[i])
	var half := ps.hazard_width[i] * 0.5
	var lo := maxf(before - half, 30.0)
	var rows := PackedInt32Array()
	ps.combat.nearby(ps.hazard_pos[i], now + half, rows)
	for j in rows:
		if t.dead[j] != 0 or t.meteor_index[j] >= 0:
			continue
		var d := t.pos[j] - ps.hazard_pos[i]
		var dist := d.length()
		if dist + t.r[j] < lo or dist - t.r[j] > now + half:
			continue
		if absf(Geom.angle_diff(d.angle(), ps.hazard_angle[i])) > ps.hazard_arc[i] + t.r[j] / maxf(dist, 1.0):
			continue
		ps.combat.damage_enemy(j, ps.hazard_edmg[i], {"cause": &"wave", "dir": d / maxf(dist, 1.0), "knock": 300.0, "no_crit": true})
		if ps.state.phase != RunState.Phase.PLAY:
			return false
	return true

func spawn(ps: ProjectileSystem, center: Vector2, angle: float, arc: float, radius: float, speed: float, width: float, delay: float,
		dmg: float, gap := 0.0, gap_w := 0.0, color := Color("#9ad8ff")) -> int:
	return ps._add_hazard(ProjectileSystem.HazardKind.WAVE, ProjectileSystem.HazardStyle.PLAIN, center, angle, radius, width, delay, radius / maxf(speed, 1.0),
		dmg, color, speed, arc, gap, gap_w)
