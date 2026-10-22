## やまねこ座。
extends EnemyBehavior

func step(i: int, dt: float) -> void:
	_lynx(i, dt)

## やまねこ座：距離を保ち、間隔ごとに前足を構えて（charge が構えの進み）、片側1組の斬撃を左右交互に飛ばし続ける
## （buds が撃った数）。斬撃は真ん中の少し先から外側へ伸び、外側で本体の方へ反り上がる。撃ったときの機体の向きへ
## 形を保って直進し、追尾しない。内側の端を左右交互によけて真ん中を抜けさせ、外側からの回り込みを難しくする。
func _lynx(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	# 遠くから撃つが、どこから撃っているか見えるように、本体は画面の中に収まる位置を保つ
	var d := t.pos[i] - _aim
	var u := d / maxf(d.length(), 1.0)
	var room := _vh - Vector2.ONE * (t.r[i] + 40.0)
	var goal := (_aim + u * float(p.keep)).clamp(_vc - room, _vc + room)
	_steer_to(i, goal, t.speed[i], t.accel[i], dt)
	_turn_toward(i, (state.ship_pos - t.pos[i]).angle(), t.turn[i], dt)
	if _gun_timer(i, dt):
		var side := lynx_side(i)
		t.buds[i] += 1
		var a := (state.ship_pos - t.pos[i]).angle()
		projectiles.fire_slash(t.pos[i] + Vector2.from_angle(a) * t.r[i], a, float(p.slash_speed), float(p.slash_size),
			float(p.slash_range), float(p.bullet_dmg), side)

## やまねこ座が次に斬撃を伸ばす側（1 か -1。構えの見た目にも使う）。
func lynx_side(i: int) -> float:
	return 1.0 if table.buds[i] % 2 == 0 else -1.0
