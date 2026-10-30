## ボス共用の光の矢。長さ0は矢じり、長さを指定した矢は後方の線分まで判定する。配色を変えても同じ形・運動を使う。
extends HostileShape

func spawn(ps: ProjectileSystem, mouth: Vector2, angle: float, speed: float,
		radius: float, travel: float, damage: float, cosmic := false, length := 0.0) -> int:
	if speed <= 0.0 or radius <= 0.0 or travel <= 0.0:
		return -1
	var kind := ProjectileSystem.HostileKind.COSMIC_ARROW if cosmic else ProjectileSystem.HostileKind.LIGHT_ARROW
	var row := ps._add_hostile(mouth, Vector2.from_angle(angle) * speed, speed,
		radius, travel / speed, damage, 0.0, 0.0, kind)
	ps.hostile_length[row] = maxf(0.0, length)
	ps.state.emit(&"shoot", {"pos": mouth, "kind": &"arrow"})
	return row

## 長い矢は、移動前の尾から移動後の先端までを調べる。天体への到達時刻は先端基準のまま比較する。
func contact(ps: ProjectileSystem, i: int, from: Vector2, to: Vector2, body_hit, ship_pos: Vector2, R: float, step: float) -> Variant:
	var length := ps.hostile_length[i]
	if length <= 0.0:
		return super.contact(ps, i, from, to, body_hit, ship_pos, R, step)
	var rr := ps.hostile_r[i] + R
	var reach := rr + step + length
	if ship_pos.distance_squared_to(to) > reach * reach:
		return null
	var tail := from - ps.hostile_vel[i].normalized() * length
	var t := Geom.seg_circle_t(tail, to, ship_pos, rr)
	if t < 0.0:
		return null
	# 最初から線分に触れている場合は時刻0。移動中の命中は先端の移動時間に戻す。
	var contact_t := maxf(0.0, (t * (step + length) - length) / step) if step > 0.0 else 0.0
	if body_hit != null and contact_t >= float(body_hit.t):
		return null
	_damage_ship(ps, i)
	return from.lerp(to, contact_t)
