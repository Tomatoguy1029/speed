## みずがめ座の見た目。
extends EnemyVisual

func setup(render: RunPresentation, behavior_name: StringName) -> void:
	super(render, behavior_name)
	always_marked = true



## 溜める口の光は、敵の値だけから描く。
static func draw_frame(c: CanvasItem, values: PackedFloat32Array, pixel: float) -> void:
	for i in range(0,values.size(),5):
		var radius: float = values[i+2]
		var charge: float = values[i+4]
		var muzzle := Vector2(values[i],values[i+1])+Vector2.from_angle(values[i+3])*radius
		c.draw_circle(muzzle,3.0*pixel+radius*0.45*charge,Color(1.0,0.9,0.6,0.35+0.55*charge))
