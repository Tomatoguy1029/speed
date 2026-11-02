## 生成で使う攻撃の固定値と形状。実行中の状態は持たない。
@tool
extends RefCounted
const ENEMY_MIN_DISTANCE := 30.0
const ENEMY_KNOCK := 300.0
const RADIUS := 9.0
const LIFE := 4.5
const DEFAULT_DAMAGE := 7.0
const ZONE_FLASH := 0.25
const REAR_MOUNT_PIXEL := Vector2(15.5,39.5)
const SLASH_TALL := 0.48
const SLASH_STEP := 0.15
const SLASH_STRETCH := 0.22
const SLASH_INNER := 0.12
const SLASH_THICK := 0.07
const SLASH_FROM := -100.0 * PI / 180.0
const SLASH_RISE := 16.0 * PI / 180.0
const SLASH_SAMPLES := 16

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
