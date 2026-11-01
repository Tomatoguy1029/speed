## 制作時に保存値から確定した爆発。編集プレビューは可変shaderを使う。
class_name BurstRuntime
extends RefCounted

const DATA := preload("res://data/visuals/burst_runtime.tres")

static func profile(key: String, live_edit := false) -> Dictionary:
	if live_edit or ShaderTuning.previewing(): return {}
	return DATA.get_meta("profiles", {}).get(key, {})

static func material(values: Dictionary, mode := 0) -> ShaderMaterial:
	var source: ShaderMaterial = values.materials[mode]
	var result := source.duplicate() as ShaderMaterial
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		result.set_shader_parameter("linear_colors", false)
	return result

static func time_scale(key: String) -> float:
	var values := profile(key)
	return float(values.time_scale) if not values.is_empty() else ShaderTuning.burst_time_scale(key)

static func number(key: String, name: String, original: float) -> float:
	var values := profile(key)
	return float(values.get(name, original)) if not values.is_empty() else ShaderTuning.burst_number(key, name, original)

static func reach(values: Dictionary, radius: float) -> float:
	var r: Array = values.reach
	var size := maxf(radius, 1.0)
	return maxf(maxf(1.7, float(r[2]) + 2.0 / size), maxf(float(r[3]), maxf(float(r[0]) + 17.0 / size, float(r[1]) + 3.0 / size)))
