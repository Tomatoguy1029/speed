## 制作時に固定した機雷・ポンプ着弾・自爆敵の爆発。ライブ編集は可変shaderを使う。
extends RefCounted

const DATA := preload("res://data/visuals/burst_runtime.tres")

static func profile(key: String, live_edit := false) -> Dictionary:
	if live_edit or ShaderTuning.previewing(): return {}
	return DATA.get_meta("profiles", {}).get(key, {})

static func material(spec: Dictionary) -> ShaderMaterial:
	var result := (spec.material as ShaderMaterial).duplicate() as ShaderMaterial
	if "linear_colors" in spec.parameters and RenderingServer.get_current_rendering_method() == "gl_compatibility":
		result.set_shader_parameter("linear_colors", false)
	return result

static func reach(values: Dictionary, radius: float) -> float:
	var r: Array = values.reach
	var size := maxf(radius, 1.0)
	return maxf(maxf(1.7, float(r[2]) + 2.0 / size), maxf(float(r[3]), maxf(float(r[0]) + 17.0 / size, float(r[1]) + 3.0 / size)))
