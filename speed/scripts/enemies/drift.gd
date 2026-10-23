## 漂流：回転するだけ。時間で消える漂流物（うみへび座の瓦礫など）は、吐き出された勢いが少しずつ落ちる。
extends EnemyBehavior

func step(i: int, dt: float) -> void:
	var t := table
	t.facing[i] += t.spin[i] * dt
	if t.def[i].params.has("life"):
		t.vel[i] *= maxf(0.0, 1.0 - 1.5 * dt)
		if t.age[i] > float(t.def[i].params.life):
			mark_dead(i)
