## 技に合わせた予告とエフェクト。
extends "res://scripts/bosses/draco/technique_visual.gd"

func _draw() -> void:
	if actor == null or not actor.has_body(): return
	super()
	_draw_spiral_charge()

func _draw_spiral_charge() -> void:
	if actor.technique != technique_id or actor.mode != &"active" or actor._runner == null: return
	var wrap: float = actor._runner.coil_time
	if actor.elapsed < wrap or actor.elapsed >= wrap + actor._runner.pause_time: return
	var progress := clampf((actor.elapsed - wrap) / actor._runner.pause_time, 0.0, 1.0)
	var center: Vector2 = actor.to_local(actor._runner.center)
	var radius: float = lerpf(minf(actor._runner.horizontal_extent, actor._runner.extent) * 0.56, actor.body_width * 0.7, progress)
	var warning := Color(1.0, 0.38, 0.23, 0.18 + progress * 0.6)
	draw_arc(center, radius, 0.0, TAU, 64, warning, 4.0 + progress * 4.0, false)
	for j in 12:
		var direction := Vector2.from_angle(float(j) * TAU / 12.0)
		draw_line(center + direction * (radius + 20.0), center + direction * (radius + 4.0), warning, 3.0, false)
	FORM.star(self, center, 7.0 + progress * 12.0, warning)
