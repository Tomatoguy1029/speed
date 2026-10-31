## 表示部品の調整契約。使用元ごとに複製し、物理判定で使うResourceを変更しない。
class_name VisualEffectComponents
extends RefCounted
const SETTINGS := preload("res://data/visuals/effect_settings.tres")
const FIRE_FIELDS := ["birth_rate", "lifetime", "rise_speed", "sway", "particle_size", "capacity", "layer_rates", "layer_lifetimes", "layer_sizes", "outer_color", "inner_color", "core_color", "field_size", "density_pixel_size", "merge_threshold", "edge_softness", "deformation", "pixel_size", "update_fps", "glow_strength", "glow_radius"]
const PHOENIX_FIELDS := ["ember_color", "flame_color", "hot_color", "smoke_color", "amount", "speed", "pixel_size", "turbulence", "sparks", "opacity", "emission", "stretch", "lift"]
const QUALITY_FIELDS := ["capacity", "field_size", "density_pixel_size", "update_fps"]
const LABELS := {
	"birth_rate": "炎の密度", "lifetime": "表示粒の寿命（秒）", "rise_speed": "模様の上昇速度", "sway": "横揺れ", "particle_size": "表示粒の半径",
	"capacity": "表示粒の上限", "layer_rates": "外炎・内炎・芯の密度", "layer_lifetimes": "外炎・内炎・芯の寿命比", "layer_sizes": "外炎・内炎・芯の大きさ比",
	"outer_color": "外炎の色", "inner_color": "内炎の色", "core_color": "芯の色", "field_size": "描画域の大きさ", "density_pixel_size": "密度場の画素幅", "merge_threshold": "炎がつながる密度", "edge_softness": "縁の柔らかさ", "deformation": "輪郭の揺れ", "pixel_size": "ドット幅", "update_fps": "表示更新FPS", "glow_strength": "発光の強さ", "glow_radius": "発光の広がり",
	"ember_color": "残り火の色", "flame_color": "炎の色", "hot_color": "熱い芯の色", "smoke_color": "煙の色", "amount": "炎の密度", "speed": "流れる速さ", "turbulence": "乱れの強さ", "sparks": "火の粉の量", "opacity": "不透明度", "emission": "発光量", "stretch": "炎の舌の長さ", "lift": "消える間の持ち上がり",
}
static var _cache: Dictionary = {}

static func fire_presets(key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var names: Array[String] = []
	match key:
		"boss/move/canis_major/sirius": names = ["jet", "trail"]
		"boss/move/canis_major/hunt", "boss/move/canis_major/relay": names = ["jet"]
		"boss/move/canis_major/sirius_flame": names = ["flame"]
		"boss/move/canis_major/blaze": names = ["ignite", "hound", "burst"]
		"trait/fullCharge":
			return [{"resource": preload("res://data/visuals/gear_fire.tres"), "title": "ギアアップの炎"}]
	for name in names:
		var path := "res://data/visuals/canis_fire_%s.tres" % name
		result.append({"resource": load(path), "title": {"jet": "放射する炎", "trail": "焼け跡", "flame": "シリウスの炎", "ignite": "点火の炎", "hound": "猟犬を包む炎", "burst": "猟犬の爆炎"}[name]})
	return result

static func prefix(source: Resource) -> String:
	return "component/" + source.resource_path.get_file().get_basename() + "/"

static func fire(key: String, source: PixelFireSettings) -> PixelFireSettings:
	return resolved(key, source, FIRE_FIELDS) as PixelFireSettings

static func phoenix(key: String, source: Resource) -> Resource:
	return resolved(key, source, PHOENIX_FIELDS)

static func resolved(key: String, source: Resource, allowed: Array) -> Resource:
	var cache_key := key + ":" + str(source.get_instance_id())
	var revision: int = SETTINGS.preview_revision
	if _cache.has(cache_key) and _cache[cache_key].revision == revision: return _cache[cache_key].resource
	var values := SETTINGS.values_for(key)
	var start := prefix(source)
	var result: Resource = source
	for field in allowed:
		var original: Variant = source.get(field)
		var value: Variant = values.get(start + field, original)
		if original is Vector2 or original is Vector3:
			var axes := 2 if original is Vector2 else 3
			for axis in axes: value[axis] = values.get(start + field + "/" + "xyz"[axis], value[axis])
		if value != original:
			if result == source: result = source.duplicate()
			result.set(field, value)
	_cache[cache_key] = {"revision": revision, "resource": result}
	return result
