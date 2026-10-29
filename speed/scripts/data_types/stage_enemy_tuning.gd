## ステージ内だけで使う敵の数値上書き。共通の敵定義は読み取り専用で扱う。
@tool
class_name StageEnemyTuning
extends RefCounted

const FIELDS := ["hp", "armor", "speed", "accel", "turn", "weak_arc", "hitstop_multiplier"]
const REWARDS := ["big_crystal", "gem_count", "shield_time"]
const LABELS := {"hp": "標準HP（星の計算後）", "armor": "装甲", "speed": "速さ", "accel": "加速", "turn": "旋回速度", "weak_arc": "背面の弱点の半角", "hitstop_multiplier": "ヒットストップ時間倍率"}

static func keys_for(definition: EnemyDef) -> Array[String]:
	var keys: Array[String] = []
	keys.assign(FIELDS)
	var params := definition.params.keys()
	params.sort()
	for key in params:
		if key not in REWARDS and typeof(definition.params[key]) in [TYPE_INT, TYPE_FLOAT]:
			keys.append("params." + String(key))
	return keys

static func base_value(definition: EnemyDef, key: String, cfg: GameConfig) -> float:
	if key == "hp": return definition.base_hp(cfg)
	if key.begins_with("params."): return float(definition.params[key.trim_prefix("params.")])
	return float(definition.get(key))

static func label(key: String) -> String:
	if LABELS.has(key): return LABELS[key]
	var name := key.trim_prefix("params.")
	return "%s (%s)" % [EnemyDef.PARAMS_DOCS[name][0], name] if EnemyDef.PARAMS_DOCS.has(name) else name

static func minimum(key: String) -> float:
	var name := key.trim_prefix("params.")
	if key == "hp": return 0.01
	if name in ["volley", "beams", "layers", "strikes", "stars", "rubble_count", "shards", "lump_max", "throw_min"]: return 1.0
	if name in ["telegraph", "windup", "life", "recover", "cooldown", "rest", "fuse"] or name.ends_with("_interval") or name.ends_with("_time") or name.ends_with("_delay") or name.ends_with("_cd"):
		return 0.01
	return -100000.0 if name in ["spin", "pull_spin", "gather_behind", "row_near", "row_far"] else 0.0

static func error_for(definition: EnemyDef, values: Dictionary) -> String:
	var keys := keys_for(definition)
	for key in values:
		if not key is String or key not in keys: return "調整できない項目: %s" % key
		var value: Variant = values[key]
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or float(value) < minimum(key) or float(value) > 100000.0:
			return "範囲外の数値: %s" % key
		if key.begins_with("params.") and definition.params[key.trim_prefix("params.")] is int and float(value) != floorf(float(value)):
			return "整数で指定する項目: %s" % key
	return ""

static func resolve(definition: EnemyDef, values: Dictionary) -> EnemyDef:
	var result := definition.duplicate(true) as EnemyDef
	for key: String in values:
		if key == "hp": result.stage_hp = float(values[key])
		elif key.begins_with("params."):
			var name := key.trim_prefix("params.")
			result.params[name] = int(values[key]) if definition.params[name] is int else float(values[key])
		else: result.set(key, float(values[key]))
	return result
