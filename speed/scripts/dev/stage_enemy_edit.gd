## 敵調整UIの保存境界。読み直したステージの敵調整だけを更新する。
@tool
extends RefCounted

static func read_stage(path: String) -> StageDef:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as StageDef

static func definition(id: String) -> EnemyDef:
	var path := "res://data/enemies/%s.tres" % id
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as EnemyDef if ResourceLoader.exists(path) else null

static func validate(values: Dictionary) -> String:
	for id in values:
		if not id is String or not values[id] is Dictionary: return "敵調整の形式が不正です。"
		var base := definition(id)
		if base == null: return "敵が見つかりません: %s" % id
		var problem := StageEnemyTuning.error_for(base, values[id])
		if not problem.is_empty(): return "%s: %s" % [id, problem]
	return ""

## baselineが変わっていたら保存を止め、別の編集を上書きしない。
static func save(path: String, values: Dictionary, baseline: Dictionary) -> Dictionary:
	var problem := validate(values)
	if not problem.is_empty(): return {"error": problem}
	var stage := read_stage(path)
	if stage == null: return {"error": "ステージを読み込めません。"}
	if stage.enemy_tuning != baseline: return {"error": "別の編集で敵調整が変わりました。再読込してから保存してください。"}
	stage.enemy_tuning = values.duplicate(true)
	var error := ResourceSaver.save(stage, path)
	if error != OK: return {"error": "保存に失敗: %s" % error_string(error)}
	return {"stage": stage}
