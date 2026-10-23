## ミサイル艇：機体の周りの距離を保ち、間隔ごとに向いた方へ誘導弾を撃つ。
extends EnemyBehavior

func step(i: int, dt: float) -> void:
	_keep_distance(i, dt)
	if _gun_timer(i, dt):
		projectiles.fire_enemy(i, table.facing[i], table.def[i].params.missile_speed, &"missile")
