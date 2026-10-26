## たて座の見た目（盾と、奪える背面）。
extends EnemyVisual

func setup(render: RunPresentation, behavior_name: StringName) -> void:
	super(render, behavior_name)
	always_marked = true
	draws_weak_arc = false

const SHIELD_VISUAL := preload("res://scripts/render/shield_visual.gd")

func draw_marks(c: CanvasItem, t: EnemyTable, i: int) -> void:
	if rm.look_of(t.type[i]) == null:
		SHIELD_VISUAL.enemy(c, t, i)
	super(c, t, i)
