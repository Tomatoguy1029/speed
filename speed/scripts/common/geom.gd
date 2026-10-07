## 複数の場所で使う幾何の関数。
class_name Geom
extends RefCounted

## 線分 p0→p1 が中心 c・半径 r の円に初めて入る位置（0〜1）。入らなければ -1、始点が中なら 0。
static func seg_circle_t(p0: Vector2, p1: Vector2, c: Vector2, r: float) -> float:
	var f := p0 - c
	var cc := f.length_squared() - r * r
	if cc <= 0.0:
		return 0.0
	var d := p1 - p0
	var a := d.length_squared()
	if a == 0.0:
		return -1.0
	var b := 2.0 * f.dot(d)
	var disc := b * b - 4.0 * a * cc
	if disc < 0.0:
		return -1.0
	var t := (-b - sqrt(disc)) / (2.0 * a)
	return t if t >= 0.0 and t <= 1.0 else -1.0

## 2つの角の差（-PI〜PI）。
static func angle_diff(a: float, b: float) -> float:
	return wrapf(a - b, -PI, PI)

## 線分 a→b と c→d の交点。交わらなければ null。
static func seg_cross(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> Variant:
	var r := b - a
	var s := d - c
	var den := r.cross(s)
	if absf(den) < 1e-7:
		return null
	var q := c - a
	var t := q.cross(s) / den
	var u := q.cross(r) / den
	if t <= 1e-6 or t > 1.0 or u < 0.0 or u > 1.0:
		return null
	return a + r * t
