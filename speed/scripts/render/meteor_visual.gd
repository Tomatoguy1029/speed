## 隕石を初めて表示するときに、シートと被弾段階のバッチを作る。
extends RefCounted
const METEOR_SHEETS := [preload("res://assets/pixel/meteor_spritesheet.png"),
	preload("res://assets/pixel/meteor2_spritesheet.png")]
var rm: RunPresentation
func setup(render: RunPresentation) -> void:
	rm = render
	for variant in METEOR_SHEETS.size():
		var sheet: Texture2D = METEOR_SHEETS[variant]
		var frame_size := float(sheet.get_height())
		for stage in 3:
			var rock_batch := InstanceBatch.new()
			rock_batch.setup_texture(sheet, Rect2(stage * frame_size, 0, frame_size, frame_size))
			rock_batch.material = rm._enemy_mat
			rock_batch.z_index = -1
			rm._layers.enemies.add_child(rock_batch)
			rm._batches[StringName("meteor_" + str(variant) + "_damage_" + str(stage))] = rock_batch

func shatter(ev: Dictionary) -> void:
	var sheet: Texture2D = METEOR_SHEETS[posmod(int(ev.meteor_index), 2)]
	var size := float(sheet.get_height())
	var half := size / 2.0
	for y in 2:
		for x in 2:
			var offset := Vector2((x - 0.5) * half, (y - 0.5) * half).rotated(ev.facing)
			rm.meteor_shards.append({"texture": sheet,
				"region": Rect2(size * 2.0 + x * half, y * half, half, half),
				"pos": ev.pos + offset, "vel": offset.normalized() * 100.0 + ev.dir * 60.0,
				"angle": ev.facing, "spin": -1.5 if x == y else 1.5, "life": 0.65})
