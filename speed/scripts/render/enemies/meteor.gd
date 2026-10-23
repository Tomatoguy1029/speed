## 地形の隕石と彗星の本体。漂流の行動とは独立した表示を持つ。
extends EnemyVisual

func sprite_radius(table: EnemyTable, row: int) -> float:
	return table.r[row]

func draw_body(c: CanvasItem, table: EnemyTable, row: int, pos: Vector2) -> bool:
	var comet := run.field.comet_at(table.meteor_index[row])
	if comet != null:
		rm._draw_comet(c, pos, table.r[row], table.vel[row], comet.rare_weapon != &"")
		return true
	var meteors = rm._meteors()
	var variant := posmod(table.meteor_index[row], 2)
	var stage := clampi(int((1.0 - table.hp[row] / table.max_hp[row]) * 3.0), 0, 2)
	var key := StringName("meteor_" + str(variant) + "_damage_" + str(stage))
	var batch: InstanceBatch = rm._batches[key]
	batch.add(pos, table.facing[row], meteors.METEOR_SHEETS[variant].get_height() / 2.0, Color(0, 0, 0, 1))
	return true

func on_kill(event: Dictionary) -> void:
	rm._meteors().shatter(event)
