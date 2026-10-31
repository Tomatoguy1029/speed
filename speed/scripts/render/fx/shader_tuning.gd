## 戦闘エフェクトツールで調整する shader の値。shader の `group_uniforms tuning;` の中の uniform が対象で、
## 値は effect_settings.tres の装備キーに「shader/<shader のファイル名>/<uniform 名>」で持つ。
## 演出は material を作ったときと毎フレーム apply を呼び、停止中の調整もすぐ映す。
class_name ShaderTuning
extends RefCounted

const SETTINGS := preload("res://data/visuals/effect_settings.tres")
const PREFIX := "shader/"

static func field(shader: Shader, uniform: String) -> String:
	return PREFIX + shader.resource_path.get_file().get_basename() + "/" + uniform

static func apply(mat: ShaderMaterial, key: String, fallback := "") -> void:
	if mat == null or mat.shader == null: return
	var values := SETTINGS.resolved_values(key, fallback)
	if values.is_empty(): return
	var prefix := PREFIX + mat.shader.resource_path.get_file().get_basename() + "/"
	for name in values:
		if String(name).begins_with(prefix): mat.set_shader_parameter(String(name).trim_prefix(prefix), values[name])

## tuning の組に入っている uniform（名前・型・範囲）。
static func tunables(shader: Shader) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var inside := false
	for info in shader.get_shader_uniform_list(true):
		if info.usage & PROPERTY_USAGE_GROUP:
			inside = info.name == "tuning"
			continue
		if inside: result.append(info)
	return result

## uniform の既定値。shader の記述から読む。
static func default_value(shader: Shader, uniform: String) -> Variant:
	var found := RegEx.create_from_string("uniform\\s+(\\w+)\\s+" + uniform + "\\b[^=;]*=\\s*([^;]+);").search(shader.code)
	if found == null: return null
	var literal := found.get_string(2).strip_edges()
	if found.get_string(1) == "float": return float(literal)
	var numbers := literal.trim_prefix("vec4(").trim_suffix(")").split(",")
	if numbers.size() == 1: return Color(float(numbers[0]), float(numbers[0]), float(numbers[0]), float(numbers[0]))
	return Color(float(numbers[0]), float(numbers[1]), float(numbers[2]), float(numbers[3]) if numbers.size() > 3 else 1.0)
