## 編集用shaderだけを差し替え、本番と同じマスク選択・姿勢・特殊部位を使う。
extends "res://scripts/render/landmark_aura.gd"

const AUTHORING_SHADER := preload("res://shaders/build_aura.gdshader")
const NOISE := preload("res://assets/effects/build/aura_noise.png")
var settings: EnemyMarkSettings
var _entries: Dictionary = {}

func setup(scope: ContentResourceScope) -> void:
	super.setup(scope)
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

func add_body(body: Dictionary, clock: float) -> void:
	var slot := _count
	super.add_body(body, clock)
	if _count == slot: return
	var sprite := _sprites[slot]
	# 本番shaderのinstance uniformを、編集shaderでは個別materialへ渡す。
	configure(sprite, _entries[sprite.texture])
	var material := sprite.material as ShaderMaterial
	material.set_shader_parameter("pump_full", body.get("pump_full",0.0))
	material.set_shader_parameter("clock", clock)
