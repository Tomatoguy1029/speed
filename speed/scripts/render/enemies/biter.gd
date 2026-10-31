## 噛みつく雑魚だけの顎。固定の分割マップと共通塗装をバッチで再利用する。
extends EnemyVisual
const ASSETS_PATH := "res://data/visuals/biter_parts.tres"
const SOURCE_LOOK := "res://data/visuals/looks/biter.tres"
const ARMOR_SHADER := preload("res://shaders/biter_part_armor.gdshader")
const SPARK_SHADER := preload("res://shaders/biter_sparks.gdshader")
const SNAP := 0.034
const CLOSED_HOLD := 0.051
const RETURN_TIME := 0.12
const SPARK_TIME := 0.11
var _assets: Resource
var _parts: Array[Dictionary] = []
var _sparks: InstanceBatch
var _synced_frame := -1

func setup(render: RunPresentation, behavior_name: StringName) -> void:
	super.setup(render, behavior_name)
	_sparks = InstanceBatch.new()
	_sparks.setup_shader_quad()
	var mat := ShaderMaterial.new()
	mat.shader = SPARK_SHADER
	_sparks.material = mat
	rm._lit_enemy_marks.add_child(_sparks)
	rm._batches[&"biter/sparks"] = _sparks
	var scope := run.ctx.resources
	if not scope.resources.has(ASSETS_PATH) and state.lab_mode: scope.provide(ASSETS_PATH, load(ASSETS_PATH))
	_assets = scope.resources.get(ASSETS_PATH)
	assert(_assets != null, "事前分割した噛みつく雑魚の素材が必要")

func _ensure_parts(type: StringName) -> void:
	if not _parts.is_empty() or _assets == null: return
	rm._ensure_enemy_batch(type)
	var lighting: Node = rm._batches[type].get_parent()
	for entry: Dictionary in _assets.get_meta("parts", []):
		var base := InstanceBatch.new()
		base.setup_texture(entry.base)
		base.material = rm._batches[type].material
		base.z_index = -1
		lighting.add_child(base)
		var armor_texture := CanvasTexture.new()
		armor_texture.diffuse_texture = entry.armor
		armor_texture.normal_texture = entry.normal
		var armor := InstanceBatch.new()
		armor.setup_texture(armor_texture)
		var mat := ShaderMaterial.new()
		mat.shader = ARMOR_SHADER
		armor.material = mat
		armor.z_index = -1
		lighting.add_child(armor)
		rm._batches[StringName("biter/" + entry.name + "/base")] = base
		rm._batches[StringName("biter/" + entry.name + "/armor")] = armor
		_parts.append({"base": base, "armor": armor, "pivot": entry.pivot - Vector2(10, 17), "name": entry.name})

func _sync_materials(type: StringName) -> void:
	var frame := Engine.get_process_frames()
	if frame == _synced_frame: return
	_synced_frame = frame
	var original: ShaderMaterial = rm._armor_batches[type].material
	var paint: Texture2D = (rm._armor_batches[type].texture as CanvasTexture).diffuse_texture
	for part in _parts:
		var mat := part.armor.material as ShaderMaterial
		mat.set_shader_parameter("paint_tex", paint)
		for key in ["brightness", "ambient", "normal_strength"]:
			mat.set_shader_parameter(key, original.get_shader_parameter(key))

func _jaw_degrees(t: EnemyTable, i: int) -> float:
	if t.mode[i] == EnemyTable.Mode.WINDUP:
		return -8.0 * smoothstep(0.0, 1.0, t.charge[i])
	if t.mode[i] != EnemyTable.Mode.RECOVER: return 0.0
	var age := maxf(0.0, float(t.def[i].params.bite_rest) - t.timer[i])
	if age < SNAP: return lerpf(-8.0, 12.0, smoothstep(0.0, SNAP, age))
	if age < SNAP + CLOSED_HOLD: return 12.0
	return 12.0 * (1.0 - smoothstep(SNAP + CLOSED_HOLD, SNAP + CLOSED_HOLD + RETURN_TIME, age))

func draw_body(_c: CanvasItem, t: EnemyTable, i: int, p: Vector2) -> bool:
	if t.type[i] != &"biter": return false
	var radius := sprite_radius(t, i)
	if t.mode[i] == EnemyTable.Mode.RECOVER:
		var spark_age := float(t.def[i].params.bite_rest) - t.timer[i] - SNAP
		if spark_age >= 0.0 and spark_age < SPARK_TIME:
			var scale_px := radius / 17.0
			var u := Vector2.from_angle(t.facing[i])
			var mouth := p + u * radius * (16.0 / 17.0)
			_sparks.add(mouth + u * 12.0 * scale_px, t.facing[i], 32.0 * scale_px, Color(spark_age / SPARK_TIME, 0, 0, 1))
	var look := rm.look_of(t.type[i])
	# ステージ4の蛇は元の外観を使う。別の輪郭へ顎のマスクを流用しない。
	if look == null or look.source_path != SOURCE_LOOK: return false
	_ensure_parts(t.type[i])
	_sync_materials(t.type[i])
	var angle := rm._enemy_sprite_angle(t.type[i], t.facing[i])
	var jaw := deg_to_rad(_jaw_degrees(t, i))
	var color := Color(1.0 if t.flash[i] > 0.0 else 0.0, 0, 0, 1)
	var deformation: Dictionary = rm._enemy_wave_deformations.get(t.id[i], {})
	if not deformation.is_empty() and deformation.flash: color.r = 1.0
	for part in _parts:
		var turn := jaw if part.name == "jaw_left" else -jaw if part.name == "jaw_right" else 0.0
		var pivot: Vector2 = part.pivot * (radius / 17.0)
		var center := p + (pivot - pivot.rotated(turn)).rotated(angle)
		part.base.add(center, angle + turn, radius, color)
		part.armor.add(center, angle + turn, radius, color)
		if not deformation.is_empty():
			part.base.deform_last(deformation.direction, deformation.amount)
			part.armor.deform_last(deformation.direction, deformation.amount)
	return true

func draw_marks(c: CanvasItem, t: EnemyTable, i: int) -> void:
	var look := rm.look_of(t.type[i])
	if look == null or look.source_path != SOURCE_LOOK: super.draw_marks(c, t, i)
