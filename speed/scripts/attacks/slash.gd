## やまねこ座の斬撃：片側1組の、潰れた弧の3本の爪痕。真ん中の少し先から外側へ横に伸び、外側で本体の方へ反り上がる。
## 形を保ったまま直進する。hostile_r が爪痕の横の大きさ、hostile_turn が伸びる側（進む向きに対して 1 なら左、-1 なら右）。
extends HostileShape

## 斬撃の爪痕の形。横の大きさ（hostile_r）に対する割合：縦の大きさ、爪痕どうしの間隔、外側の爪痕ほど縦に伸びる量、
## 真ん中を越えて伸びる量、太さ。爪痕は楕円の弧で、本体の方を上・伸びる側を右にしたとき SLASH_FROM の角度（−100°）から
## 反り上がる。外側（機体側）の爪痕ほど反り上がりが長く（SLASH_RISE ずつ先まで回り込む）、外からの回り込みを防ぐ
const SLASH_TALL := 0.48
const SLASH_STEP := 0.15
const SLASH_STRETCH := 0.22
const SLASH_INNER := 0.12
const SLASH_THICK := 0.07
const SLASH_FROM := -100.0 * PI / 180.0
const SLASH_RISE := 16.0 * PI / 180.0
const SLASH_SAMPLES := 16

func contact(ps: ProjectileSystem, i: int, _from: Vector2, to: Vector2, _body_hit, ship_pos: Vector2, R: float, _step: float) -> Variant:
	if not slash_touches(to, ps.hostile_vel[i].angle(), ps.hostile_r[i], ps.hostile_turn[i], ship_pos, R):
		return null
	ps.ship.damage(ps.hostile_dmg[i], 0.0, ProjectileSystem.HOSTILE_CAUSE[ps.hostile_kind[i]])
	return to

## 斬撃の k 本目（0〜2）の爪痕の点（斬撃の向きの座標。x が伸びる側、y が本体の方。横の大きさ 1）。k が大きいほど外側（機体側）。
static func slash_local(k: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var a := 1.0 + SLASH_STEP * float(k)
	var b := SLASH_TALL + (SLASH_STEP + SLASH_STRETCH) * float(k)
	var center := Vector2(SLASH_INNER, SLASH_TALL + SLASH_STRETCH * float(k))
	for n in SLASH_SAMPLES + 1:
		var phi := lerpf(SLASH_FROM, SLASH_RISE * float(k), float(n) / SLASH_SAMPLES)
		pts.append(center + Vector2(a * cos(phi), b * sin(phi)))
	return pts

## 斬撃（真ん中の先端 pos、進む向き angle、横の大きさ size、伸びる側 side）の k 本目の爪痕の点（世界の座標）。
static func slash_points(pos: Vector2, angle: float, size: float, side: float, k: int) -> PackedVector2Array:
	var u := Vector2.from_angle(angle)
	var across := Vector2(-u.y, u.x) * side
	var pts := slash_local(k)
	for n in pts.size():
		pts[n] = pos + (across * pts[n].x - u * pts[n].y) * size
	return pts

## 位置 at（半径 reach の円）が斬撃の爪痕のどれかに触れているか。
static func slash_touches(pos: Vector2, angle: float, size: float, side: float, at: Vector2, reach: float) -> bool:
	var u := Vector2.from_angle(angle)
	var d := at - pos
	var local := Vector2(d.dot(Vector2(-u.y, u.x)) * side, -d.dot(u)) / size
	var m := (SLASH_THICK * 0.5 * size + reach) / size
	for k in 3:
		var pts := slash_local(k)
		for n in range(1, pts.size()):
			if Geometry2D.get_closest_point_to_segment(local, pts[n - 1], pts[n]).distance_squared_to(local) <= m * m:
				return true
	return false

func spawn(ps: ProjectileSystem, from: Vector2, angle: float, speed: float, size: float, range: float, dmg: float, side: float) -> void:
	var u := Vector2.from_angle(angle)
	ps._add_hostile(from, u * speed, speed, size, range / maxf(speed, 1.0), dmg, 0.0, side, ProjectileSystem.HostileKind.SLASH)
	ps.state.emit(&"shoot", {"pos": from, "kind": &"slash"})
