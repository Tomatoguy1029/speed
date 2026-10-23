## わし座。
extends EnemyBehavior

func step(i: int, dt: float) -> void:
	_drive(i, dt)
	_aquila(i, dt)

## わし座：雷を運ぶ鷲。大きく旋回しながら飛び、通り道に沿って雷を落とす。
func _aquila(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	t.fire_t[i] -= dt
	if t.fire_t[i] > 0.0:
		return
	t.fire_t[i] = float(p.drop_step)
	projectiles.fire_zone(t.pos[i], float(p.blast_radius), float(p.blast_delay), float(p.bullet_dmg),
		ProjectileSystem.HazardStyle.LIGHTNING, Color("#ffe46b"))
