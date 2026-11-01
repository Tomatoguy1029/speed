## 編集用shaderだけを差し替え、本番と同じマスク選択・姿勢・特殊部位を使う。
extends "res://scripts/render/landmark_aura.gd"

const AUTHORING_SHADER := preload("res://shaders/build_aura.gdshader")
const NOISE := preload("res://assets/effects/build/aura_noise.png")
var settings: EnemyMarkSettings
var _entries: Dictionary = {}

func setup(render: RunPresentation) -> void:
	super.setup(render)
	for entry: Dictionary in _masks.values():
		_entries[entry.texture] = entry
	_material = ShaderMaterial.new()
	_material.shader = AUTHORING_SHADER
	_material.set_shader_parameter("noise_tex", NOISE)
	for sprite in _sprites:
		sprite.material = _material.duplicate()
	refresh()

func refresh() -> void:
	if settings == null: return
	settings.apply_aura_to(_material)
	for sprite in _sprites:
		settings.apply_aura_to(sprite.material as ShaderMaterial)

func _add_body(t: EnemyTable, row: int, deformation: Dictionary) -> void:
	var slot := _count
	super._add_body(t, row, deformation)
	if _count == slot: return
	var sprite := _sprites[slot]
	# 本番shaderのinstance uniformを、編集shaderでは個別materialへ渡す。
	configure(sprite, _entries[sprite.texture])
	var material := sprite.material as ShaderMaterial
	material.set_shader_parameter("pump_full", _pump_full[slot])
	material.set_shader_parameter("clock", _rm.state.world_time)
