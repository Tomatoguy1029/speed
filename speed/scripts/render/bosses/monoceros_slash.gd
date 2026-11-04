## 光の剣の線状の斬撃。元 bosses_common.js の bossSlash と同じ画素計算。
extends RefCounted

static func _hash(value: float) -> float:
	var n := sin(value * 127.1 + 311.7) * 43758.5453
	return n - floorf(n)

static func _ramp(base: Color) -> Array[Color]:
	var result: Array[Color] = []
	for factor in [0.35, 0.6, 1.0]:
		result.append(Color(roundf(clampf(base.r*factor,0.0,1.0)*255.0)/255.0,roundf(clampf(base.g*factor,0.0,1.0)*255.0)/255.0,roundf(clampf(base.b*factor,0.0,1.0)*255.0)/255.0))
	result.append(Color(roundf(lerpf(base.r,1.0,0.45)*255.0)/255.0,roundf(lerpf(base.g,1.0,0.45)*255.0)/255.0,roundf(lerpf(base.b,1.0,0.45)*255.0)/255.0))
	result.append(Color.WHITE)
	return result

## 両端・幅はワールド座標、年齢・寿命は戦闘時計の秒。出力は前面の論理画素。
static func draw(canvas, from: Vector2, to: Vector2, width: float, age: float, life: float, seed: float, params: Dictionary) -> void:
	var time := age / float(params.timing)
	if time < 0.0 or time > life: return
	var a: Vector2 = canvas.to_logical(from)
	var b: Vector2 = canvas.to_logical(to)
	var direction := (b-a).normalized()
	var normal := direction.orthogonal()
	var length := a.distance_to(b)
	var colors := _ramp(Color(params.color))
	var fade := 1.0-time/life
	var distance := 0.0
	while distance <= length:
		var k := distance/maxf(1.0,length)
		var taper := pow(sin(k*PI),0.7)
		var half_width := width*float(canvas.world_scale)*0.5*taper*float(params.size)*fade
		var center := a+direction*distance+normal*sin(distance*0.3+seed)*0.6
		var offset := -half_width
		while offset <= half_width:
			var edge := absf(offset)/maxf(0.1,half_width)
			if fade >= 0.35 or _hash(distance*13.0+floorf(offset)*7.0+seed) <= fade*2.7:
				var point := center+normal*offset
				var level := 4 if time < 0.06 and edge < 0.5 else 3 if edge < 0.5 else 1
				canvas.front.px(point.x,point.y,colors[level])
			offset += 0.7
		if int(distance)%4 == 0: canvas.front.glow(center.x,center.y,2.0+half_width,colors[2],fade*0.16*float(params.intensity))
		distance += 1.0
