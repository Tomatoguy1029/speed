## 地形として置かれる障害物。自力で移動しない。
extends EnemyBehavior
func _init() -> void:
	recycles_far = false
	debug_spawnable = false
