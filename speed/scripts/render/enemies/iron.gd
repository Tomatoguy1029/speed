## 鉄のがれきは、配置ごとに固定した3種類の絵をまとめて描く。
extends EnemyVisual

const TEXTURES := [preload("res://assets/pixel/iron.png"), preload("res://assets/pixel/iron_debris_2.png"),
	preload("res://assets/pixel/iron_debris_3.png")]
const KEYS := [&"iron", &"iron_debris_2", &"iron_debris_3"]

func setup(render: RunPresentation, behavior_name: StringName) -> void:
	super(render, behavior_name)
	for variant in TEXTURES.size():
		var batch := InstanceBatch.new()
		batch.setup_texture(TEXTURES[variant])
		batch.material = rm._enemy_mat
		batch.z_index = -1
		rm._layers.enemies.add_child(batch)
		rm._batches[KEYS[variant]] = batch

func draw_body(_c: CanvasItem, table: EnemyTable, row: int, pos: Vector2) -> bool:
	var index := table.meteor_index[row] if table.meteor_index[row] >= 0 else table.id[row]
	var variant := posmod(index, TEXTURES.size())
	var batch: InstanceBatch = rm._batches[KEYS[variant]]
	batch.add(pos, table.facing[row], sprite_radius(table, row), Color(0, 0, 0, 1))
	return true
