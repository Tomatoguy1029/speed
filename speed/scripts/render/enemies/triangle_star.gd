## 親が決めた軌跡の値を、元の段差と3色で描く。
extends EnemyVisual
const TRAIL_EDGE := Color("#7a0c1a")
const TRAIL_BODY := Color("#ff2b3d")
const TRAIL_CORE := Color("#ffd2d2")
const TRAIL_STEPS := 6
const TRAIL_TAIL := 0.4

static func draw_frame(c: CanvasItem, values: PackedFloat64Array, pixel: float) -> void:
	for i in range(0,values.size(),5):
		var tail := Vector2(values[i],values[i+1])
		var head := Vector2(values[i+2],values[i+3])
		var w := values[i+4]
		var length := tail.distance_to(head)
		if length<1.0: continue
		var u := (head-tail)/length
		for s in TRAIL_STEPS:
			var a := tail+u*length*float(s)/TRAIL_STEPS
			var b := tail+u*length*float(s+1)/TRAIL_STEPS
			var ww := maxf(snappedf(lerpf(w*TRAIL_TAIL,w,float(s+1)/TRAIL_STEPS),pixel*2.0),pixel*2.0)
			c.draw_line(a,b,TRAIL_EDGE,ww+pixel*2.0)
			c.draw_line(a,b,TRAIL_BODY,ww)
			c.draw_line(a,b,TRAIL_CORE,maxf(pixel,snappedf(ww*0.3,pixel)))
