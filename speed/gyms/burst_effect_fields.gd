## 爆発の編集項目。保存名と描画の所有元を保ち、部品ごとに並べる。
extends RefCounted

const GROUPS := ["爆発・基本", "火球", "閃光", "衝撃波", "煙", "火の粉", "燃えかす", "稲妻・光粒"]
const SHADERS := ShaderTuning.BURST_SHADERS
const LABELS := {
	"c0": "共通の最も明るい色", "c1": "共通の明るい色", "c2": "共通の中間色", "c3": "火球の外側の色",
	"burn_speed": "火球の薄まる強さ", "cool_speed": "火球の後半の崩れ", "outer_alpha": "火球の外側の濃さ",
	"noise_scale": "火球の模様の細かさ", "roughness": "火球の縁の崩れ", "start_size": "火球の開始サイズ（半径比）",
	"grow_seconds": "最大まで膨らむ時間（秒）", "fire_seconds": "火球の時間（秒）", "hole_size": "中心の穴の広さ",
	"flash_seconds": "閃光の時間（秒）", "flash_size": "閃光の広さ（半径比）",
	"ring_seconds": "衝撃波の時間（秒）", "ring_size": "衝撃波の広さ（半径比）", "ring_alpha": "衝撃波の濃さ",
	"smoke_dark": "煙の暗い色", "smoke_mid": "煙の中間色", "smoke_light": "煙の明るい色",
	"smoke_seconds": "煙の最長寿命（秒）", "spark_seconds": "火の粉の最長寿命（秒）", "cinder_seconds": "燃えかすの最長寿命（秒）",
	"brightness": "着色部分の明るさ",
}

static func shader_name(field: String) -> String:
	return field.get_slice("/", 1) if field.begins_with("shader/") else ""

static func group_for(shader: String, uniform: String) -> String:
	if shader == "hydra_burst":
		if uniform.begins_with("ring_"): return "衝撃波"
		if uniform.begins_with("ray_") or uniform.begins_with("chip_") or uniform == "spokes": return "稲妻・光粒"
		return "閃光"
	if uniform in ["c0", "c1", "c2"]: return "爆発・基本"
	if uniform.begins_with("smoke_"): return "煙"
	if uniform.begins_with("spark_"): return "火の粉"
	if uniform.begins_with("cinder_"): return "燃えかす"
	if uniform.begins_with("ring_"): return "衝撃波"
	if uniform.begins_with("flash_"): return "閃光"
	return "火球"

static func decorate(entries: Array[Dictionary], key: String) -> void:
	if key == "weapon/endBlast": return
	var shaders: Array[String] = []
	for entry in entries:
		var shader := shader_name(entry.name)
		if shader not in SHADERS: continue
		if shader not in shaders: shaders.append(shader)
		var uniform: String = entry.name.get_slice("/", 2)
		entry.group = group_for(shader, uniform)
		if LABELS.has(uniform): entry.fallback = LABELS[uniform]
		if uniform in ["c0", "c1", "c2"]: entry.help = "火球・閃光・衝撃波・火の粉・燃えかすで共有する色。"
		if uniform == "c3": entry.help = "火球の外側の色と透明度。"
		if uniform == "burn_speed": entry.help = "全期間の火球の密度を減らす強さ。"
		if uniform == "cool_speed": entry.help = "後半の火球の密度を追加で減らす強さ。"
		if shader == "fire_burst" and uniform in ["c0", "c1", "c2"]:
			entry.fallback = {"c0": "火球の最も明るい色", "c1": "火球の明るい色", "c2": "火球の中間色"}[uniform]
			entry.help = "火球の色と透明度。"
	if shaders.is_empty(): return
	if not entries.any(func(entry): return entry.name == "effect_tint"):
		entries.append({"name": "effect_tint", "value": Color.WHITE, "fallback": "全体色", "group": "爆発・基本"})
	for entry in entries:
		if entry.name in ["effect_tint", "effect_scale", "pixel_scale", "glow_energy"]: entry.group = "爆発・基本"
		if entry.name == "glow_energy": entry.fallback = "爆発の明るさ（倍）"
	entries.push_front(_number("爆発の時間倍率", "burst_duration_scale", 1.0, "0.1,4,0.05", "爆発・基本", "1が元の速さ。2で同じ動きを2倍の時間で再生します。"))
	if not entries.any(func(entry): return entry.name == "glow_energy"):
		entries.append(_number("爆発の明るさ（倍）", "glow_energy", 1.0, "0,4,0.05", "爆発・基本"))
	if "fire_burst" in shaders:
		entries.append(_number("火球の時間（秒）", "burst_fire_seconds", 0.45 if key == "weapon/massTow" else 0.5, "0.05,4,0.05", "火球"))
	if "hydra_burst" in shaders:
		var small_seconds := 0.3
		for entry in entries:
			if entry.name == "flash_duration": small_seconds = maxf(0.3, float(entry.value))
		# 小閃光の旧保存値は実行側で引き継ぎ、編集欄は一つにする。
		entries.assign(entries.filter(func(entry): return entry.name != "flash_duration"))
		entries.append(_number("大きな閃光の時間（秒）", "burst_large_seconds", 0.8, "0.05,4,0.05", "閃光"))
		entries.append(_number("小さな閃光の時間（秒）", "burst_small_seconds", small_seconds, "0.05,4,0.05", "閃光"))

static func _number(label: String, name: String, value: float, hint: String, group: String, help := "") -> Dictionary:
	return {"name": name, "value": value, "hint": hint, "fallback": label, "group": group, "help": help}
