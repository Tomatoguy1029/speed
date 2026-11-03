## 鉄のがれきは、配置ごとに固定した3種類の絵をまとめて描く。
extends Node2D
const PATHS := ["res://assets/pixel/iron.png","res://assets/pixel/iron_debris_2.png","res://assets/pixel/iron_debris_3.png"]
var _batches: Array[InstanceBatch] = []
var _seen := false
func setup(scope: ContentResourceScope, _entry: Dictionary) -> void:
	z_index = -1
	for path in PATHS:
		var batch := InstanceBatch.new()
		batch.setup_texture(scope.resources[path])
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/pixel_sprite.gdshader")
		batch.material = material
		add_child(batch)
		_batches.append(batch)
func begin() -> void:
	_seen = false
func apply_frame(row: Dictionary) -> void:
	_seen = true
	for batch in _batches: batch.begin()
	for i in row.ids.size():
		var n: int = i*6
		_batches[row.flags[i]].add(Vector2(row.transforms[n+4],row.transforms[n+5]),atan2(row.transforms[n+1],row.transforms[n]),Vector2(row.transforms[n],row.transforms[n+1]).length(),row.colors[i])
	for batch in _batches: batch.end()
func end() -> void:
	if _seen: return
	for batch in _batches:
		batch.begin()
		batch.end()
func set_death_brightness(value: float) -> void:
	for batch in _batches: batch.material.set_shader_parameter("brightness",value)
func frame_event(_event: Dictionary, _texture: Texture2D) -> void:
	pass
