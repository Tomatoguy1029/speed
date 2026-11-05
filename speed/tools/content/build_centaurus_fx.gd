## 表示履歴の保持期間を、確定した技ごとの時間倍率から生成する。
@tool
extends RefCounted
const SETTINGS := preload("res://data/visuals/fx_reference.tres")
static func apply(data: Dictionary) -> Error:
	if not SETTINGS.valid(): return ERR_INVALID_DATA
	data.CentaurusReferenceFxDefinition = [{"id":1,
		"release_life":0.4*float(SETTINGS.for_id("C10-release").timing),
		"landing_life":0.3*float(SETTINGS.for_id("C05-landing").timing),
		"stomp_life":0.9*float(SETTINGS.for_id("C13-stomp").timing)}]
	return OK
