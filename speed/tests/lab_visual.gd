extends Node

func _ready() -> void:
	var lab = load("res://gyms/enemy_lab/enemy_lab.tscn").instantiate()
	add_child(lab)
	await get_tree().create_timer(0.4).timeout
	lab.session.perform("spawn", {"type": "drifter", "pos": [-250, -80], "count": 18, "spacing": 70})
	lab.session.perform("spawn", {"type": "beamer", "pos": [300, -140], "count": 3})
	lab.session.perform("spawn", {"type": "armored", "pos": [150, 200], "count": 4})
	lab.canvas.route = PackedVector2Array([Vector2(-450,-100), Vector2(-100,0), Vector2(300,150)])
	lab._refresh()
	lab.inspector.refresh(true)
	await get_tree().process_frame
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	get_viewport().get_texture().get_image().save_png("/private/tmp/speed-lab-first.png")
	get_tree().quit()
