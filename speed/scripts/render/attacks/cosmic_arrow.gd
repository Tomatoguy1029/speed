extends "res://scripts/render/attacks/light_arrow.gd"

func draw_shot(c: CanvasItem, pr: ProjectileSystem, i: int, pos: Vector2) -> bool:
	draw_arrow(c, pos, pr.hostile_vel[i].angle(), pr.hostile_r[i], true, state.world_time)
	return true
