## 雑魚の目標の数の曲線
## ステージに出る雑魚1種類の、時刻ごとの「フィールドにいてほしい数」。打った点をなめらかな曲線でつなぐ
## （点より行き過ぎないつなぎ方）。最初の点より前は最初の点の数、最後の点より後は最後の点の数。
## ---
## 値の正は res://data/stages/*.tres の zako_curves。
class_name SpawnCurve
extends Resource

## 種類
## この曲線で数を決める雑魚の type ID。
## 単位：type ID
@export var type: StringName
## 点
## 時刻（x、実秒）と目標の数（y、体）の点。時刻の順に並べる。
## 単位：実秒・体
@export var points: PackedVector2Array = PackedVector2Array()

## 時刻 t の目標の数。
func value_at(t: float) -> float:
	return SpawnCurve.sample(points, t)

## 点の並び pts を、行き過ぎないなめらかな曲線（単調な3次補間）でつないだときの、時刻 t の値。
static func sample(pts: PackedVector2Array, t: float) -> float:
	var n := pts.size()
	if n == 0:
		return 0.0
	if n == 1 or t <= pts[0].x:
		return pts[0].y
	if t >= pts[n - 1].x:
		return pts[n - 1].y
	var k := 0
	while k < n - 2 and t > pts[k + 1].x:
		k += 1
	var h := maxf(pts[k + 1].x - pts[k].x, 0.0001)
	var s := (t - pts[k].x) / h
	var m0 := _slope(pts, k)
	var m1 := _slope(pts, k + 1)
	var s2 := s * s
	var s3 := s2 * s
	return (2.0 * s3 - 3.0 * s2 + 1.0) * pts[k].y + (s3 - 2.0 * s2 + s) * h * m0 \
		+ (-2.0 * s3 + 3.0 * s2) * pts[k + 1].y + (s3 - s2) * h * m1

## 点 k での傾き（Fritsch–Carlson：隣の区間の傾きの向きが違う所や平らな所では 0 にして、行き過ぎを防ぐ）。
static func _slope(pts: PackedVector2Array, k: int) -> float:
	var n := pts.size()
	var left := (pts[k].y - pts[k - 1].y) / maxf(pts[k].x - pts[k - 1].x, 0.0001) if k > 0 else 0.0
	var right := (pts[k + 1].y - pts[k].y) / maxf(pts[k + 1].x - pts[k].x, 0.0001) if k < n - 1 else 0.0
	if k == 0:
		return right
	if k == n - 1:
		return left
	if left * right <= 0.0:
		return 0.0
	# 2つの傾きの調和平均（行き過ぎない）
	return 2.0 * left * right / (left + right)
