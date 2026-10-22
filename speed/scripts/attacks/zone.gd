## 遅れて弾ける範囲：pos を中心に半径 len の円。弾けた瞬間だけ当たり、以後は見た目だけ。誘爆なら範囲の敵にも当たる。
extends HazardShape

func touches(ps: ProjectileSystem, i: int, ship_pos: Vector2, R: float) -> bool:
	var reach := ps.hazard_len[i] + R
	return ps.hazard_pos[i].distance_squared_to(ship_pos) <= reach * reach

## 弾けた瞬間：以後は当たらない。誘爆なら範囲の敵にダメージを与える。
func before_touch(ps: ProjectileSystem, i: int) -> bool:
	ps.hazard_hit[i] = 1
	if ps.hazard_edmg[i] > 0.0:
		ps.combat.explode(ps.hazard_pos[i], ps.hazard_len[i], ps.hazard_edmg[i],
			{"cause": &"chain", "no_crit": true, "color": ps.hazard_color[i], "life": 0.3})
		if ps.state.phase != RunState.Phase.PLAY:
			return false
	return true

func spawn(ps: ProjectileSystem, center: Vector2, radius: float, delay: float, dmg: float, style := ProjectileSystem.HazardStyle.BLAST,
		color := Color("#ffb36b"), edmg := 0.0) -> int:
	var i := ps._add_hazard(ProjectileSystem.HazardKind.ZONE, style, center, 0.0, radius, 0.0, delay, ProjectileSystem.ZONE_FLASH, dmg, color)
	ps.hazard_edmg[i] = edmg
	return i
