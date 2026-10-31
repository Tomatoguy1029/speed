## 攻撃の演出をドット単位で描く。1ドットは機体の絵の 1/0.55 テクセル（世界座標で 1.82 × character_scale）。
## 位置は世界座標、長さ・半径はドット数で受け取り、ドットの格子へそろえて MultiMesh にまとめて描く。
## 描き方（円・輪・線・火花・光弾）は演出の試作と同じ規則にする。
class_name PixelPainter
extends InstanceBatch

const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
var px := 2.366

func setup_painter(cell: float) -> void:
	px = cell
	setup_shader_quad()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

## 世界座標をドットの座標へ。
func cell(p: Vector2) -> Vector2:
	return p / px

## ドットの座標 (x, y) から幅 w・高さ h ドットを塗る（左上をドット位置に丸める）。
func fill(x: float, y: float, color: Color, w := 1, h := 1) -> void:
	if color.a <= 0.0: return
	var ix := roundf(x)
	var iy := roundf(y)
	# 全ドットが軸に平行なので、回転と単位矩形の変換を経由せず書く。
	var need := (_count + 1) * STRIDE
	if _buf.size() < need:
		_buf.resize(maxi(need, _buf.size() * 2))
	var i := _count * STRIDE
	_buf[i] = w * px * 0.5
	_buf[i + 1] = 0.0
	_buf[i + 2] = 0.0
	_buf[i + 3] = (ix + w * 0.5) * px
	_buf[i + 4] = 0.0
	_buf[i + 5] = h * px * 0.5
	_buf[i + 6] = 0.0
	_buf[i + 7] = (iy + h * 0.5) * px
	_buf[i + 8] = color.r
	_buf[i + 9] = color.g
	_buf[i + 10] = color.b
	_buf[i + 11] = color.a
	_count += 1

## 世界座標の1ドット。
func dot(p: Vector2, color: Color, size := 1) -> void:
	var c := p / px
	fill(c.x, c.y, color, size, size)

## 塗りの円（半径 r ドット）。
func disk(p: Vector2, r: float, color: Color) -> void:
	if r <= 0.0: return
	var c := p / px
	var big := ceili(r)
	for dy in range(-big, big + 1):
		var w := floori(sqrt(maxf(0.0, r * r - dy * dy)))
		fill(c.x - w, c.y + dy, color, w * 2 + 1, 1)

## 隙間のない輪（半径 r ドット、太さ1）。
func ring(p: Vector2, r: float, color: Color) -> void:
	if r <= 0.0: return
	var c := p / px
	var seen := {}
	var n := ceili(r * 8.0)
	for i in n:
		var a := float(i) / n * TAU
		var x := roundf(c.x + cos(a) * r)
		var y := roundf(c.y + sin(a) * r)
		var k := Vector2i(int(x), int(y))
		if seen.has(k): continue
		seen[k] = true
		fill(x, y, color)

## 太さ w ドットの輪（半径 r から内側へ w ドット）。nz は輪の形の揺らぎ（5山の正弦）。
func thick_ring(p: Vector2, r: float, w: int, color: Color, nz := 0.0) -> void:
	if r <= 0.0: return
	var c := p / px
	var n := maxi(16, ceili(r * 7.0))
	for i in n:
		var a := float(i) / n * TAU
		var rr := r * (1.0 + nz * sin(a * 5.0 + r * 0.1))
		for k in w:
			fill(c.x + cos(a) * (rr - k), c.y + sin(a) * (rr - k), color)

## 太さ w ドットの線（両端は世界座標）。
func line(a: Vector2, b: Vector2, color: Color, w := 1) -> void:
	var ca := a / px
	var cb := b / px
	var n := maxi(1, ceili(maxf(absf(cb.x - ca.x), absf(cb.y - ca.y))))
	for i in range(n + 1):
		var k := float(i) / n
		fill(ca.x + (cb.x - ca.x) * k - (w >> 1), ca.y + (cb.y - ca.y) * k - (w >> 1), color, w, w)

## 向き angle の軸に沿って、後ろへ k ドット・横へ o ドットの位置を1ドット塗る（光弾・砲口の部品）。
func along(p: Vector2, angle: float, k: float, o: float, color: Color) -> void:
	var c := p / px
	var u := Vector2.from_angle(angle)
	fill(c.x - u.x * k - u.y * o, c.y - u.y * k + u.x * o, color)

## 射撃の光弾。白い先端・青白い胴・青の尾・外側の淡い青。wide 0〜2（2 はブラスターの太い1発）。
func bolt(p: Vector2, angle: float, length: int, wide: int) -> void:
	var g := 3.0 if wide >= 2 else 2.0
	if wide > 0:
		var glow := Color("#2a7fd0", 0.45)
		for k in range(1, length):
			if k > length * 0.6 and k % 2 == 1: continue
			along(p, angle, k, g, glow)
			along(p, angle, k, -g, glow)
	for k in length:
		var c := Color.WHITE if k < length * 0.4 else Color("#7fd8ff") if k < length * 0.75 else Color("#3a9cf0")
		if k >= length * 0.75 and k % 2 == 1: continue
		along(p, angle, k, 0.0, c)
		if wide > 0 and k < length * 0.75:
			var side := (Color.WHITE if wide >= 2 else Color("#d8f6ff")) if k < length * 0.35 else Color("#7fd8ff")
			along(p, angle, k, 1.0, side)
			along(p, angle, k, -1.0, side)
		if wide >= 2 and k >= 1 and k < length * 0.6:
			var side2 := Color("#d8f6ff") if k < length * 0.3 else Color("#7fd8ff")
			along(p, angle, k, 2.0, side2)
			along(p, angle, k, -2.0, side2)
	along(p, angle, -1, 0.0, Color.WHITE)
	if wide >= 2:
		along(p, angle, -1, 1.0, Color("#d8f6ff"))
		along(p, angle, -1, -1.0, Color("#d8f6ff"))
		along(p, angle, -2, 0.0, Color.WHITE)

## 砲口の光。q は 0〜1 の経過、big 0〜2。
func muzzle(p: Vector2, angle: float, q: float, big: int) -> void:
	if q < 0.0 or q >= 1.0: return
	var rr: int = [2, 3, 4][big]
	var rl: int = [8, 8, 13][big]
	var c := p / px
	if q < 0.4:
		for j in range(-rr, rr + 1):
			var w := rr - absi(j)
			fill(c.x - w, c.y + j, Color.WHITE, w * 2 + 1, 1)
		for k in range(2, rl + 1):
			along(p, angle, -k, 0.0, Color.WHITE if k < rl * 0.6 else Color("#7fd8ff"))
			if big == 2 and k < rl * 0.5:
				along(p, angle, -k, 1.0, Color("#d8f6ff"))
				along(p, angle, -k, -1.0, Color("#d8f6ff"))
		for k in range(1, rr + 1):
			along(p, angle, -k, k + 1, Color("#7fd8ff"))
			along(p, angle, -k, -k - 1, Color("#7fd8ff"))
		if big == 2:
			for k in range(1, 5):
				along(p, angle, k * 0.5, k + 2, Color("#3a9cf0"))
				along(p, angle, k * 0.5, -k - 2, Color("#3a9cf0"))
	elif q < 0.75:
		fill(c.x - 1, c.y - 1, Color("#7fd8ff"), 3, 3)
		fill(c.x, c.y, Color.WHITE)
		for k in range(2, int(rl * 0.6) + 1):
			along(p, angle, -k, 0.0, Color("#7fd8ff"))
	else:
		fill(c.x, c.y, Color("#3a9cf0"))
		along(p, angle, -3, 0.0, Color("#3a9cf0"))

## 光弾が当たった所の光。q は 0〜1 の経過、big 0〜2。
func hit_flash(p: Vector2, q: float, big: int) -> void:
	var c := p / px
	var l: int = [3, 4, 7][big]
	if q < 0.45:
		fill(c.x - l, c.y, Color.WHITE, l * 2 + 1, 1)
		fill(c.x, c.y - l, Color.WHITE, 1, l * 2 + 1)
		fill(c.x - 1, c.y - 1, Color.WHITE, 3, 3)
		if big == 2 and q < 0.3: disk(p, 3.0, Color.WHITE)
	ring(p, 2.0 + [5.0, 7.0, 12.0][big] * q, Color("#bff3ff") if q < 0.4 else Color("#4fb8ff"))
	if big == 2 and q > 0.2: ring(p, 1.0 + 6.0 * q, Color("#d8f6ff"))

## 両端の尖った針状の光（菱形）。外側は紫、内側に白い芯。len・w はドット数（w は中心から片側の幅）。
func spindle(p: Vector2, angle: float, length: float, w: float, alpha: float) -> void:
	if alpha <= 0.0 or length <= 0.0: return
	var c := p / px
	var u := Vector2.from_angle(angle)
	var n := u.orthogonal()
	var half := length * 0.5
	var extent := ceili(half + w + 1.0)
	var outer := Color("#a855ff", alpha)
	var inner := Color(1, 1, 1, alpha)
	for y in range(-extent, extent + 1):
		for x in range(-extent, extent + 1):
			var cx := roundf(c.x) + x
			var cy := roundf(c.y) + y
			var d := Vector2(cx + 0.5 - c.x, cy + 0.5 - c.y)
			var a := absf(d.dot(u))
			var b := absf(d.dot(n))
			if a / half + b / maxf(w, 0.01) > 1.0: continue
			var white := a / (length * 0.42) + b / maxf(w * 0.35, 0.01) <= 1.0
			fill(cx, cy, inner if white else outer)

## 試作の vnoise：格子点の乱数をなめらかにつないだ 0〜1 の値ノイズ。
static func vnoise(x: float, y: float, z: float) -> float:
	var xi := floorf(x)
	var yi := floorf(y)
	var zi := floorf(z)
	var u := _smooth(x - xi)
	var v := _smooth(y - yi)
	var w := _smooth(z - zi)
	var a := lerpf(lerpf(_hash(xi, yi, zi), _hash(xi + 1, yi, zi), u), lerpf(_hash(xi, yi + 1, zi), _hash(xi + 1, yi + 1, zi), u), v)
	var b := lerpf(lerpf(_hash(xi, yi, zi + 1), _hash(xi + 1, yi, zi + 1), u), lerpf(_hash(xi, yi + 1, zi + 1), _hash(xi + 1, yi + 1, zi + 1), u), v)
	return lerpf(a, b, w)

static func _hash(i: float, j: float, k: float) -> float:
	var s := sin(i * 127.1 + j * 311.7 + k * 74.7) * 43758.5453
	return s - floorf(s)

static func _smooth(f: float) -> float:
	return f * f * (3.0 - 2.0 * f)

## Bayer 4×4 のしきい値（0〜15）。
static func bayer(x: int, y: int) -> int:
	return BAYER[(y & 3) * 4 + (x & 3)]
