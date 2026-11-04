## 確定した敵FX値のうち、当たりの形と位置にも使う値を本番データへ解決する。
extends RefCounted

const SETTINGS := preload("res://data/visuals/fx_reference.tres")

static func apply(data: Dictionary) -> Error:
	var crab: Dictionary = SETTINGS.for_id("G12-crab")
	var lynx: Dictionary = SETTINGS.for_id("G12-lynx")
	var ruler: Dictionary = SETTINGS.for_id("G12-ruler")
	var aquarius: Dictionary = SETTINGS.for_id("G12-aquarius")
	for entry: Array in [[crab, ["reachR", "hitR"]], [lynx, ["span", "maxSize", "size", "start", "grow", "timing", "cutT", "space0", "space1", "gap"]], [ruler, ["muzzle"]], [aquarius, ["size"]]]:
		for key: String in entry[1]:
			if not entry[0].has(key) or not (entry[0][key] is float or entry[0][key] is int):
				push_error("敵FXの当たりに必要な値がありません: " + key)
				return ERR_INVALID_DATA
	for row: Dictionary in data.get("CrabDefinition", []):
		row.fx_reach_r = float(crab.reachR)
		row.fx_hit_r = float(crab.hitR)
	for row: Dictionary in data.get("LynxDefinition", []):
		row.fx_span = deg_to_rad(float(lynx.span))
		row.fx_max_size = float(lynx.maxSize) * float(lynx.size)
		row.fx_start = float(lynx.start)
		row.fx_grow = maxf(0.01, float(lynx.grow) * float(lynx.timing))
		row.fx_cut = maxf(0.01, float(lynx.cutT) * float(lynx.timing))
		row.fx_space0 = float(lynx.space0)
		row.fx_space1 = float(lynx.space1)
		row.fx_gap = float(lynx.gap)
	for row: Dictionary in data.get("RulerDefinition", []):
		row.fx_muzzle = float(ruler.muzzle)
	for row: Dictionary in data.get("AquariusDefinition", []):
		row.fx_size = float(aquarius.size)
	return OK
