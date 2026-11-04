## 承認済み試作の論理画素。前後の色・光を別に保持し、表示側で通常／加算合成する。
## 元: reference/source/app/core.js, fxlib.js, pixelfx_bundle.js の Painter (MIT)。
extends RefCounted

const HEIGHT := 225
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

class Painter:
	extends RefCounted
	var width := 0
	var height := 0
	var color_image: Image
	var light_image: Image
	var colors := PackedByteArray()
	var lights := PackedByteArray()
	var fade := 1.0
	var light_strength := 1.0
	var tx := 0.0
	var ty := 0.0
	var fx := 1.0
	var cs := 1.0
	var sn := 0.0

	func clear(w: int, h: int) -> void:
		width = w
		height = h
		colors.resize(w * h * 4)
		lights.resize(w * h * 4)
		colors.fill(0)
		lights.fill(0)
		fade = 1.0
		light_strength = 1.0
		place(0.0, 0.0)

	func finish() -> void:
		color_image = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, colors)
		# 黒の光も不透明にし、加算合成で透明な背景と同じ結果にする。
		for i in range(3, lights.size(), 4): lights[i] = 255
		light_image = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, lights)

	func place(x: float, y: float, flip := false, angle := 0.0) -> void:
		tx = x
		ty = y
		fx = -1.0 if flip else 1.0
		cs = cos(angle)
		sn = sin(angle)

	func _to(x: float, y: float) -> Vector2:
		return Vector2(tx + x * fx * cs - y * sn, ty + x * fx * sn + y * cs)

	func _from(x: float, y: float) -> Vector2:
		var dx := x - tx
		var dy := y - ty
		return Vector2((dx * cs + dy * sn) * fx, -dx * sn + dy * cs)

	func _cell(x: float, y: float) -> Vector2i:
		var p := _to(floorf(x) + 0.5, floorf(y) + 0.5)
		return Vector2i(floori(p.x), floori(p.y))

	func _index(x: int, y: int) -> int:
		return (y * width + x) * 4 if x >= 0 and y >= 0 and x < width and y < height else -1

	func _put(x: int, y: int, c: Color, alpha: float) -> void:
		if c.a <= 0.0: return
		var a := alpha * fade
		var k := 1.0
		if a >= 0.12 and a < 0.999:
			k = 0.2 + 0.8 * a
		elif a < 1.0 and a <= (float(BAYER[((y & 3) << 2) | (x & 3)]) + 0.5) / 16.0:
			return
		var i := _index(x, y)
		if i < 0: return
		colors[i] = int(clampf(c.r, 0.0, 1.0) * 255.0 * k)
		colors[i + 1] = int(clampf(c.g, 0.0, 1.0) * 255.0 * k)
		colors[i + 2] = int(clampf(c.b, 0.0, 1.0) * 255.0 * k)
		colors[i + 3] = 255 if k != 1.0 else int(clampf(c.a, 0.0, 1.0) * 255.0)

	func _add(x: int, y: int, c: Color, strength: float) -> void:
		var k := strength * fade * light_strength
		if k <= 0.004: return
		var i := _index(x, y)
		if i < 0: return
		lights[i] = mini(255, int(lights[i] + int(c.r * 255.0) * k))
		lights[i + 1] = mini(255, int(lights[i + 1] + int(c.g * 255.0) * k))
		lights[i + 2] = mini(255, int(lights[i + 2] + int(c.b * 255.0) * k))

	func _blend(x: int, y: int, c: Color, alpha: float) -> void:
		var a := alpha * fade
		if c.a <= 0.0 or a <= 0.004: return
		var i := _index(x, y)
		if i < 0: return
		var da := float(colors[i + 3]) / 255.0
		var oa := a + da * (1.0 - a)
		var k := a / oa
		colors[i] = int(int(c.r * 255.0) * k + colors[i] * (1.0 - k)) & 255
		colors[i + 1] = int(int(c.g * 255.0) * k + colors[i + 1] * (1.0 - k)) & 255
		colors[i + 2] = int(int(c.b * 255.0) * k + colors[i + 2] * (1.0 - k)) & 255
		colors[i + 3] = int(oa * 255.0) & 255

	func px(x: float, y: float, c: Color) -> void:
		var p := _cell(x, y)
		_put(p.x, p.y, c, 1.0)

	func dot(x: float, y: float, c: Color, alpha := 1.0) -> void:
		if alpha <= 0.0: return
		var p := _cell(x, y)
		_put(p.x, p.y, c, alpha)

	func light(x: float, y: float, c: Color, strength := 1.0) -> void:
		var p := _cell(x, y)
		_add(p.x, p.y, c, strength)

	func blend(x: float, y: float, c: Color, alpha: float) -> void:
		var p := _cell(x, y)
		_blend(p.x, p.y, c, alpha)

	func _value(v: Variant, args: Array) -> Variant:
		if v is Callable:
			return v.callv(args.slice(0, v.get_argument_count()))
		return v

	## callback は (local_x, local_y, result) を受け、result の c/a/l/k を設定する。
	func shade(x0: float, y0: float, x1: float, y1: float, callback: Callable) -> void:
		var corners := [_to(x0,y0), _to(x1,y0), _to(x0,y1), _to(x1,y1)]
		var lo: Vector2 = corners[0]
		var hi: Vector2 = corners[0]
		for p: Vector2 in corners:
			lo = lo.min(p)
			hi = hi.max(p)
		for y in range(maxi(0, floori(lo.y)), mini(height - 1, ceili(hi.y)) + 1):
			for x in range(maxi(0, floori(lo.x)), mini(width - 1, ceili(hi.x)) + 1):
				var local := _from(x + 0.5, y + 0.5)
				var out := {"c": Color.TRANSPARENT, "a": 1.0, "l": Color.TRANSPARENT, "k": 0.0}
				var returned: Variant = callback.call(local.x, local.y, out)
				var c: Color = returned if returned is Color else out.c
				if c.a > 0.0: _put(x, y, c, out.a)
				if out.k > 0.0: _add(x, y, out.l if out.l.a > 0.0 else c, out.k)

	func line(x0: float, y0: float, x1: float, y1: float, c: Variant, alpha: Variant = 1.0) -> void:
		var p := _cell(x0, y0)
		var end := _cell(x1, y1)
		var dx := absi(end.x - p.x)
		var dy := -absi(end.y - p.y)
		var sx := 1 if p.x < end.x else -1
		var sy := 1 if p.y < end.y else -1
		var n := maxi(1, maxi(dx, -dy))
		var err := dx + dy
		var step := 0
		while true:
			var u := float(step) / n
			_put(p.x, p.y, _value(c, [u]), _value(alpha, [u]))
			step += 1
			if p == end: break
			var e2 := 2 * err
			if e2 >= dy:
				err += dy
				p.x += sx
			if e2 <= dx:
				err += dx
				p.y += sy

	func circle(cx: float, cy: float, r: float, c: Variant, alpha: Variant = 1.0) -> void:
		if r < 0.6:
			dot(cx, cy, _value(c, [0.0, 0.0]), _value(alpha, [0.0, 0.0]))
			return
		shade(cx-r, cy-r, cx+r, cy+r, func(x: float, y: float, out: Dictionary):
			var d := Vector2(x-cx,y-cy)
			if d.length_squared() > r*r: return
			out.c = _value(c, [d.length()/r, d.angle()])
			out.a = _value(alpha, [d.length()/r, d.angle()]))

	func disc(cx: float, cy: float, r: float, c: Variant, alpha: Variant = 1.0) -> void:
		if r < 0.5:
			blend(cx, cy, _value(c, [0.0, 0.0]), _value(alpha, [0.0, 0.0]))
			return
		var lo := _to(cx-r, cy-r)
		var hi := _to(cx+r, cy+r)
		# 変換済み矩形の四隅を使い、回転時にも同じ画素を訪問する。
		var corners := [lo, hi, _to(cx+r,cy-r), _to(cx-r,cy+r)]
		for p: Vector2 in corners:
			lo = lo.min(p)
			hi = hi.max(p)
		for y in range(maxi(0,floori(lo.y)), mini(height-1,ceili(hi.y))+1):
			for x in range(maxi(0,floori(lo.x)), mini(width-1,ceili(hi.x))+1):
				var d := _from(x+0.5,y+0.5) - Vector2(cx,cy)
				if d.length_squared() <= r*r:
					_blend(x,y,_value(c,[d.length()/r,d.angle()]),_value(alpha,[d.length()/r,d.angle()]))

	func beam(x0: float, y0: float, x1: float, y1: float, width0: float, c: Variant, alpha: Variant = 1.0) -> void:
		var a := Vector2(x0,y0)
		var b := Vector2(x1,y1)
		var d := b-a
		var r := width0*0.5
		var l2 := maxf(d.length_squared(), 0.000000001)
		shade(minf(x0,x1)-r,minf(y0,y1)-r,maxf(x0,x1)+r,maxf(y0,y1)+r,func(x: float,y: float,out: Dictionary):
			var p := Vector2(x,y)
			var u := clampf((p-a).dot(d)/l2,0.0,1.0)
			var dist := p.distance_to(a+d*u)
			if dist > r: return
			var v := dist/r if r > 0.0 else 0.0
			out.c = _value(c,[u,v])
			out.a = _value(alpha,[u,v]))

	func ring(cx: float, cy: float, r: float, w: float, c: Variant, alpha: Variant = 1.0) -> void:
		var inner := maxf(0.0,r-w)
		shade(cx-r,cy-r,cx+r,cy+r,func(x: float,y: float,out: Dictionary):
			var d := Vector2(x-cx,y-cy)
			var length := d.length()
			if length > r or length < inner: return
			var v := (length-inner)/maxf(r-inner,0.000000001) if w > 0 else 1.0
			out.c = _value(c,[v,d.angle()])
			out.a = _value(alpha,[v,d.angle()]))

	func rect(x: float, y: float, w: float, h: float, c: Color, alpha := 1.0) -> void:
		if sn == 0.0:
			for yy in range(floori(y+0.5),floori(y+h+0.5)):
				for xx in range(floori(x+0.5),floori(x+w+0.5)): dot(xx,yy,c,alpha)
			return
		shade(x,y,x+w,y+h,func(lx: float,ly: float,out: Dictionary):
			if lx >= x and ly >= y and lx < x+w and ly < y+h:
				out.c = c
				out.a = alpha)

	func poly(points: PackedVector2Array, c: Variant, alpha: Variant = 1.0) -> void:
		if points.size() < 3: return
		var lo := points[0]
		var hi := points[0]
		for p in points:
			lo = lo.min(p)
			hi = hi.max(p)
		shade(lo.x,lo.y,hi.x,hi.y,func(x: float,y: float,out: Dictionary):
			var inside := false
			var j := points.size()-1
			for i in points.size():
				var a := points[i]
				var b := points[j]
				if (a.y > y) != (b.y > y) and x < (b.x-a.x)*(y-a.y)/(b.y-a.y)+a.x: inside = not inside
				j = i
			if inside:
				out.c = _value(c,[x,y])
				out.a = _value(alpha,[x,y]))

	func glow(x: float, y: float, r: float, c: Color, strength := 0.5) -> void:
		if r < 1.0 or strength <= 0.004: return
		var center := _to(x,y)
		for sy in range(maxi(0,floori(center.y-r)),mini(height-1,ceili(center.y+r))+1):
			for sx in range(maxi(0,floori(center.x-r)),mini(width-1,ceili(center.x+r))+1):
				var d := Vector2(sx+0.5,sy+0.5).distance_to(center)/r
				if d < 1.0: _add(sx,sy,c,(1.0-d)*(1.0-d)*strength)

	func glow_line(x0: float, y0: float, x1: float, y1: float, r: float, c: Color, strength := 0.5) -> void:
		if r < 1.0 or strength <= 0.004: return
		var a := _to(x0,y0)
		var b := _to(x1,y1)
		var delta := b-a
		var l2 := maxf(delta.length_squared(),0.000000001)
		for sy in range(maxi(0,floori(minf(a.y,b.y)-r)),mini(height-1,ceili(maxf(a.y,b.y)+r))+1):
			for sx in range(maxi(0,floori(minf(a.x,b.x)-r)),mini(width-1,ceili(maxf(a.x,b.x)+r))+1):
				var p := Vector2(sx+0.5,sy+0.5)
				var u := clampf((p-a).dot(delta)/l2,0.0,1.0)
				var d := p.distance_to(a+delta*u)/r
				if d < 1.0: _add(sx,sy,c,(1.0-d)*(1.0-d)*strength)

	func glow_ring(x: float, y: float, radius: float, r: float, c: Color, strength := 0.5) -> void:
		if r < 1.0 or strength <= 0.004: return
		var center := _to(x,y)
		var extent := radius+r
		for sy in range(maxi(0,floori(center.y-extent)),mini(height-1,ceili(center.y+extent))+1):
			for sx in range(maxi(0,floori(center.x-extent)),mini(width-1,ceili(center.x+extent))+1):
				var d := absf(Vector2(sx+0.5,sy+0.5).distance_to(center)-radius)/r
				if d < 1.0: _add(sx,sy,c,(1.0-d)*(1.0-d)*strength)

var back := Painter.new()
var front := Painter.new()
var world_scale := 1.0
var _camera_position := Vector2.ZERO
var _logical_size := Vector2i.ZERO

## world_to_screen_scale はカメラの基準倍率と現在のズームを掛けた実効値。
func begin_frame(view_size: Vector2, camera_position: Vector2, world_to_screen_scale: float) -> void:
	var logical_pixel := view_size.y / HEIGHT
	_logical_size = Vector2i(maxi(1, floori(view_size.x / logical_pixel + 0.5)), HEIGHT)
	_camera_position = camera_position
	world_scale = world_to_screen_scale / logical_pixel
	back.clear(_logical_size.x, _logical_size.y)
	front.clear(_logical_size.x, _logical_size.y)

func to_logical(world: Vector2) -> Vector2:
	return (world - _camera_position) * world_scale + Vector2(_logical_size) * 0.5

func end_frame() -> void:
	back.finish()
	front.finish()
