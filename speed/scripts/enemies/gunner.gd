## 射撃型：機体の周りの距離を保ち、間隔ごとに弾を撃つ。
extends EnemyBehavior

func step(i: int, dt: float) -> void:
	_keep_distance(i, dt)
	if _gun_timer(i, dt):
		projectiles.fire_enemy(i, (state.enemy_aim - table.pos[i]).angle(), table.def[i].params.bullet_speed, &"bullet")
