## 敵調整UIの保存境界。読み直したステージの敵調整だけを更新する。
@tool
extends RefCounted

static var _names: Dictionary = {}
static var _names_key := ""

## 一覧はビルド済みの名前だけを使い、敵定義の読込は選択された種類だけにする。
static func enemy_names() -> Dictionary:
	var files := DirAccess.get_files_at("res://data/enemies")
	var path := "res://data/content_catalog.tres"
	var key := "%s:%s" % [FileAccess.get_modified_time(path), str(files)]
	if key != _names_key:
		var mode := ResourceLoader.CACHE_MODE_REUSE if _names_key.is_empty() else ResourceLoader.CACHE_MODE_IGNORE
		var catalog := ResourceLoader.load(path, "", mode) as ContentCatalog
		var entries := catalog.table(&"enemies")
		_names = {}
		for file in files:
			if not file.ends_with(".tres"): continue
			var id := file.trim_suffix(".tres")
			var entry: ContentEntry = entries.get(StringName(id))
			# エディターで追加した直後の種類も、索引の生成前から選択できる。
			_names[id] = entry.params.display_name if entry != null and entry.params.has("display_name") else definition(id).display_name
		_names_key = key
	return _names

static func read_stage(path: String) -> StageDef:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as StageDef

static func definition(id: String) -> EnemyDef:
	var path := "res://data/enemies/%s.tres" % id
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as EnemyDef if ResourceLoader.exists(path) else null

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
