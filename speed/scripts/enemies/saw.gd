## 接触した向きへ飛ぶ丸鋸。
extends "res://scripts/enemies/obstacle.gd"
func on_contact(row: int, dir: Vector2, from: Vector2, ship_speed: float) -> bool:
	var u := dir if dir != Vector2.ZERO else (table.pos[row] - from).normalized()
	var speed := maxf(cfg.saw_speed, ship_speed)
	projectiles.fire_saw(table.pos[row], u * speed, table.r[row], m.ctx.combat.attack_power() * cfg.saw_power, cfg.saw_life)
	state.emit(&"block_impact", {"pos": table.pos[row], "normal": -u, "enemy_pos": table.pos[row], "r": table.r[row]})
	mark_dead(row)
	return true
