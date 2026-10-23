## 永続強化の係数をセーブの読込・購入・リセット時に計算し、ランへ値として渡す。
extends Node
var baseline: Dictionary = {}
var _levels_signature := ""
func _ready() -> void:
	SaveManager.save_changed.connect(refresh)
	refresh()
func _levels() -> Dictionary:
	var levels: Dictionary = SaveManager.data.get("meta", {}).duplicate(true)
	if OS.is_debug_build(): levels.merge(SaveManager.dev_meta_override, true)
	return levels
func refresh() -> void:
	var levels := _levels()
	baseline = compute(levels)
	_levels_signature = JSON.stringify(levels)
func for_run(lab: bool, overrides: Dictionary = {}) -> Dictionary:
	if lab: return compute(overrides)
	if JSON.stringify(_levels()) != _levels_signature: refresh()
	return baseline.duplicate(true)
## 実験場の上書きも、保存された強化も同じ計算を使う。
func compute(levels: Dictionary) -> Dictionary:
	var result := {"mult": {}, "add": {}, "reduce": {}}
	for entry: ContentEntry in ContentManager.catalog.table(&"meta_upgrades").values():
		var level := int(levels.get(String(entry.id), 0))
		var stat := entry.stat
		var amount := entry.per_level
		result.mult[stat] = float(result.mult.get(stat, 1.0)) * (1.0 + amount * level)
		result.add[stat] = float(result.add.get(stat, 0.0)) + amount * level
		result.reduce[stat] = float(result.reduce.get(stat, 1.0)) * pow(1.0 - amount, level)
	return result
