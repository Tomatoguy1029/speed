## ぼうえんきょう座の見た目。
extends EnemyVisual

func setup(render: RunPresentation, behavior_name: StringName) -> void:
	super(render, behavior_name)
	always_marked = true

## ぼうえんきょう座：レンズから伸びるサーチライトの帯。狙いが溜まるほど細く赤くなり、本体の周りの輪が狙いの溜まり具合を示す。
## 光は隕石・惑星・月で遮られ、その裏には描かない（光線の束の届く長さで形を作る）。
## 機体が光の中にいる間は帯が明るくなる。撃ったあとの休みの間は暗い。
func draw_marks(c: CanvasItem, t: EnemyTable, i: int) -> void:
	if not behavior.telescope_aiming(i):
		return
	draw_view(c,t.pos[i],t.r[i],t.facing[i],t.mode[i],t.charge[i],t.timer[i],float(t.def[i].params.laser_charge),behavior.telescope_half(i),float(t.def[i].params.band_len),behavior.telescope_rays(i),behavior.telescope_sight(i,state.ship_pos)==1,state.world_time,_px(1.0))

static func draw_frame(c: CanvasItem, values: PackedFloat32Array, world_time: float, pixel: float) -> void:
	for i in range(0,values.size(),59):
		draw_view(c,Vector2(values[i],values[i+1]),values[i+2],values[i+3],int(values[i+4]),values[i+5],values[i+6],values[i+7],values[i+8],values[i+9],values.slice(i+11,i+59),values[i+10]>0.0,world_time,pixel)

static func draw_view(c: CanvasItem, p: Vector2, r: float, f: float, mode: int, k: float, timer: float, laser_charge: float, half: float, length: float, rays: PackedFloat32Array, seen: bool, world_time: float, pixel: float) -> void:
	var lens := p+Vector2.from_angle(f)*r*0.9
	var col := Color(0.62,0.9,1.0).lerp(Color(1.0,0.22,0.2),k)
	var resting := mode==EnemyTable.Mode.RECOVER
	var a0 := (0.06 if resting else 0.16+0.22*k)+(0.08 if seen else 0.0)
	var count := rays.size()
	if count<2: return
	var pts := PackedVector2Array([lens])
	var cols := PackedColorArray([Color(col,a0)])
	for n in count:
		var reach := rays[n]
		pts.append(lens+Vector2.from_angle(f-half+2.0*half*n/float(count-1))*reach)
		cols.append(Color(col,a0*(1.0-reach/length)))
	if mode==EnemyTable.Mode.WINDUP:
		var w := 1.0-clampf(timer/laser_charge,0.0,1.0)
		var reach := lerpf(rays[23],rays[24],0.5)
		var pulse := 0.5+0.5*sin(world_time*(30.0+40.0*w))
		var tip := lens+Vector2.from_angle(f)*reach
		c.draw_line(lens,tip,Color(1.0,0.25,0.2,0.25+0.35*pulse),maxf(2.0*pixel,4.0+10.0*w))
		c.draw_line(lens,tip,Color(1.0,0.85,0.8,0.5+0.4*pulse),maxf(pixel,1.5+2.0*w))
		for n in 10:
			var fr := fmod(w*3.0+n/10.0,1.0)
			var q := lens+Vector2.from_angle(n*TAU/10.0+w*4.0)*r*(2.4-2.2*fr)
			c.draw_circle(q,maxf(1.5*pixel,r*0.07),Color(1.0,0.45,0.3,fr))
		c.draw_circle(lens,r*(0.35+0.6*w),Color(1.0,0.3,0.22,0.35+0.3*pulse))
		c.draw_circle(lens,r*(0.18+0.3*w),Color(1.0,0.92,0.85,0.9))
		return
	c.draw_polygon(pts,cols)
	c.draw_line(lens,pts[1],Color(col,a0*1.6),1.5*pixel)
	c.draw_line(lens,pts[count],Color(col,a0*1.6),1.5*pixel)
	c.draw_circle(lens,2.0*pixel+r*(0.2+0.2*k),Color(col,0.5+0.4*k))
	if k>0.0: c.draw_arc(p,r*1.35,-PI/2.0,-PI/2.0+TAU*k,32,Color(col,0.9),maxf(2.0*pixel,r*0.12))
