## かに座の見た目（重ねた絵がないときのハサミ）。
extends EnemyVisual

func setup(render: RenderManager, behavior_name: StringName) -> void:
	super(render, behavior_name)
	always_marked = true

func draw_marks(c: CanvasItem, t: EnemyTable, i: int) -> void:
	super(c, t, i)
	if rm.look_of(t.type[i]) != null:
		return
	# ハサミ：構えから挟んだ直後まで開いている
	var p := t.pos[i]
	var r := t.r[i]
	var open := t.mode[i] == EnemyTable.Mode.WINDUP or t.mode[i] == EnemyTable.Mode.RECOVER
	for side: float in [-1.0, 1.0]:
		var a := t.facing[i] + side * (0.75 if open else 0.35)
		c.draw_circle(p + Vector2.from_angle(a) * r * 1.15, r * 0.38, Color("#ffb38a") if open else t.color[i])
