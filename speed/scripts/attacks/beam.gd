## ビーム：pos から angle の向きへ長さ len・幅 width の線。arc が 0 より大きければ、先へ行くほど左右に広がる（みずがめ座）。
extends HazardShape

func touches(ps: ProjectileSystem, i: int, ship_pos: Vector2, R: float) -> bool:
	var a := ps.hazard_pos[i]
	var u := Vector2.from_angle(ps.hazard_angle[i])
	if ps.hazard_arc[i] > 0.0:
		var rel := ship_pos - a
		var along := rel.dot(u)
		return along > -R and along < ps.hazard_len[i] + R and absf(rel.cross(u)) <= ps.flood_half(i, along) + R
	var b := a + u * ps.hazard_len[i]
	var reach := ps.hazard_width[i] * 0.5 + R
	return Geometry2D.get_closest_point_to_segment(ship_pos, a, b).distance_squared_to(ship_pos) <= reach * reach
