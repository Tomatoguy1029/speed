## 承認された試作の全実効値。描画値と比較条件を技IDごとに保持する。
class_name FxReferenceSettings
extends Resource

@export var source_sha256 := ""
@export var parameters: Dictionary = {}
## 技の攻撃と区別する、通常のボス本体接触ダメージ。
@export var boss_touch_damage := 1.0

## 読取専用として扱う。技の開始時に取得し、共通プリセットで上書きしない。
func for_id(prototype_id: String) -> Dictionary:
	return parameters.get(prototype_id, {})

func valid() -> bool:
	if source_sha256.length() != 64 or parameters.size() != 42: return false
	for prototype_id: String in parameters:
		var values: Variant = parameters[prototype_id]
		if not values is Dictionary or values.is_empty(): return false
	return true
