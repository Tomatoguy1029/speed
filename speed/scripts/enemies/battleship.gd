## 戦艦：追いながら、間隔ごとに扇状に弾をばらまく。
extends EnemyBehavior

func step(i: int, dt: float) -> void:
	_chase(i, dt)
	if _gun_timer(i, dt):
		fire_volley(i)
