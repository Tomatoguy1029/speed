## 自爆する雑魚の見た目。
extends EnemyVisual

## カウントダウンの予告は装甲の赤い明滅で示す。移動中は導火線の火花を描く。
static func draw_frame(c: CanvasItem, values: PackedFloat32Array, pixel: float) -> void:
	for i in range(0,values.size(),5):
		var p := Vector2(values[i],values[i+1])
		var r := values[i+2]
		var fuse := p-Vector2.from_angle(values[i+3])*r*0.95
		c.draw_circle(fuse,maxf(pixel*1.5,r*0.12)*values[i+4],Color("#ffd36b"))
