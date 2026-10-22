## 残る線：pos から angle の向きへ長さ len・幅 width。触れている間ずっと危ない（被弾後の無敵の間は当たらない）。
## block が 1 なら、当たっている間は機体の移動を止める壁になる（じょうぎ座のビーム）。
extends HazardShape

func _init() -> void:
	hits_once = false

func touches(ps: ProjectileSystem, i: int, ship_pos: Vector2, R: float) -> bool:
	var a := ps.hazard_pos[i]
	var b := a + Vector2.from_angle(ps.hazard_angle[i]) * ps.hazard_len[i]
	var reach := ps.hazard_width[i] * 0.5 + R
	return Geometry2D.get_closest_point_to_segment(ship_pos, a, b).distance_squared_to(ship_pos) <= reach * reach

func spawn(ps: ProjectileSystem, from: Vector2, angle: float, length: float, width: float, delay: float, active: float, dmg: float,
		color := Color("#ffd27a")) -> int:
	return ps._add_hazard(ProjectileSystem.HazardKind.WALL, ProjectileSystem.HazardStyle.PLAIN, from, angle, length, width, delay, active, dmg, color)
