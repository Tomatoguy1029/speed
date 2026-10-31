## 射撃の武器の砲口の光と、光弾が当たった所の光・火花。ブラスター・スプレッドブラスター・リアブラスターで共通に使う。
class_name ShotFlashes
extends RefCounted

var muzzle_time := 99.0
var muzzle_angle := 0.0
var muzzle_big := 2
var muzzle_seconds := 0.1
var hits: Array[Dictionary] = []
var sparks := PixelSparks.new()

func fire(angle: float) -> void:
	muzzle_time = 0.0
	muzzle_angle = angle

## big：0 は細い光弾（スプレッドブラスター）、2 は太い光弾（ブラスター・リアブラスター）。
func hit(pos: Vector2, dir: Vector2, big: int) -> void:
	hits.append({"pos": pos, "age": 0.0, "big": big})
	var a := dir.angle() + PI
	if big == 2:
		sparks.add(pos, 13, a, 2.6, 30.0, 120.0, 0.22, [Color.WHITE, Color("#bff3ff"), Color("#4fb8ff")])
	else:
		sparks.add(pos, 5, a, 2.0, 30.0, 90.0, 0.22, [Color.WHITE, Color("#bff3ff"), Color("#4fb8ff")])

## muzzle_pos は今の砲口の位置（機体と一緒に動く）。
func draw(painter: PixelPainter, dt: float, muzzle_pos: Vector2) -> void:
	muzzle_time += dt
	var kept := 0
	for h in hits:
		h.age += dt
		if h.age < 0.18:
			hits[kept] = h
			kept += 1
		var duration := 0.18 if h.big == 2 else 0.14
		if h.age < duration: painter.hit_flash(h.pos, h.age / duration, h.big)
	hits.resize(kept)
	sparks.draw(painter, dt)
	painter.muzzle(muzzle_pos, muzzle_angle, muzzle_time / muzzle_seconds, muzzle_big)
