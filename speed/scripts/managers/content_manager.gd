## 調整値と定義データを読み込んで持つ。Autoload（設計書 4.3・8.3）。
##
## 元の .tres（res://data/）は書き換えない。調整パネルは実行時の複製 `cfg` だけを書き換え、
## reset_runtime() で元の値に戻せる。武器・特性・敵などの定義はここから ID で引く。
extends Node

const CONFIG_PATH := "res://data/config.tres"

## 元の調整値（読み込んだまま）
var source_hashes: Dictionary = {}
var base: GameConfig
## 実行時に使う調整値（調整パネルが書き換える）
var cfg: GameConfig

var catalog: ContentCatalog
var _tables: Dictionary = {}
var _definitions: Dictionary = {}
var enemies: Dictionary:
	get: return _table(&"enemies")
	set(value): _tables[&"enemies"] = value
var phases: Dictionary:
	get: return _table(&"phases")
	set(value): _tables[&"phases"] = value
var stages: Dictionary:
	get: return _table(&"stages")
	set(value): _tables[&"stages"] = value
var bosses: Dictionary:
	get: return _table(&"bosses")
	set(value): _tables[&"bosses"] = value
var weapons: Dictionary:
	get: return _table(&"weapons")
	set(value): _tables[&"weapons"] = value
var traits: Dictionary:
	get: return _table(&"traits")
	set(value): _tables[&"traits"] = value
var meta_upgrades: Dictionary:
	get: return _table(&"meta_upgrades")
	set(value): _tables[&"meta_upgrades"] = value
var legendary_modules: Dictionary:
	get: return _table(&"legendary_modules")
	set(value): _tables[&"legendary_modules"] = value
var heroes: Dictionary:
	get: return _table(&"heroes")
	set(value): _tables[&"heroes"] = value

func _ready() -> void:
	# エディターの実行前プラグインを通らない起動でも、音源より先に生成する。
	if not _ensure_runtime_content():
		get_tree().quit(1)
		return
	base = load(CONFIG_PATH) as GameConfig
	if OS.has_feature("editor"): source_hashes[CONFIG_PATH] = FileAccess.get_sha256(CONFIG_PATH)
	reset_runtime()
	catalog = load("res://data/content_catalog.tres") as ContentCatalog
	# 記録の基準は読み込み順に依存させない。ファイルのハッシュだけを読む。
	if OS.has_feature("editor"):
		for entry in catalog.entries:
			source_hashes[entry.path] = FileAccess.get_sha256(entry.path)

## 調整値を .tres の値に戻す。
func reset_runtime() -> void:
	cfg = base.duplicate() as GameConfig

## ステージの数。
func stage_count() -> int:
	return catalog.table(&"stages").size()

## ステージの定義。なければ null。
func stage(index: int) -> StageDef:
	return definition(&"stages", index) as StageDef

## order（または id）の順に並べた定義の一覧。
func sorted(table: Dictionary) -> Array:
	var list := table.values()
	list.sort_custom(func(a, b): return _order_key(a) < _order_key(b))
	return list

func _order_key(def: Resource) -> String:
	if "order" in def and def.order > 0:
		return "%04d" % def.order
	return String(def.id)

## フォルダ内の .tres を読み、key の値で引けるようにする。
## 書き出したゲームでは .tres が .tres.remap になっているので、その末尾を外して読む。
func _load_dir(dir_path: String, into: Dictionary, key: String, mode := ResourceLoader.CACHE_MODE_REUSE) -> bool:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return false
	var healthy := true
	for file in dir.get_files():
		var name := file.trim_suffix(".remap")
		if not name.ends_with(".tres"):
			continue
		var res := ResourceLoader.load(dir_path.path_join(name), "", mode)
		if res == null or res.get(key) == null:
			healthy = false
			push_warning("ContentManager: %s を読めない" % name)
			continue
		into[res.get(key)] = res
		source_hashes[dir_path.path_join(name)] = FileAccess.get_sha256(dir_path.path_join(name))
	return healthy

## 調整した敵と出現・ボス・共通値を新しいリソースとして読む。既存ランの参照を変更しない。
func reload_experiment_data() -> bool:
	var fresh := ResourceLoader.load(CONFIG_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as GameConfig
	if fresh == null: return false
	var registries := {"enemies": "id", "phases": "id", "stages": "index", "bosses": "id"}
	var loaded := {}
	var old_hashes := source_hashes.duplicate()
	for name in registries:
		var table := {}
		var healthy := _load_dir("res://data/" + name, table, registries[name], ResourceLoader.CACHE_MODE_IGNORE)
		if not healthy or table.is_empty():
			source_hashes = old_hashes
			return false
		loaded[name] = table
	for stage: StageDef in loaded.stages.values():
		var phase_list := []
		for phase: PhaseDef in stage.phases:
			# タイムラインで追加した時間帯はステージ内に保存し、その値を直接使う。
			if phase.resource_path.contains("::"):
				phase_list.append(phase)
				continue
			if not loaded.phases.has(phase.id):
				source_hashes = old_hashes
				return false
			phase_list.append(loaded.phases[phase.id])
		stage.phases = phase_list
	for name in registries: set(name, loaded[name])
	base = fresh
	reset_runtime()
	if OS.has_feature("editor"): source_hashes[CONFIG_PATH] = FileAccess.get_sha256(CONFIG_PATH)
	return true

## 定義は要求されたIDだけ読む。索引のパスは文字列なので依存資源を読み込まない。
func definition(category: StringName, id: Variant) -> Resource:
	if _tables.has(category) and _tables[category].has(id):
		return _tables[category][id]
	var entry := catalog.find(category, id)
	if entry == null: return null
	var existing: WeakRef = _definitions.get(entry.path)
	var result: Resource = existing.get_ref() if existing != null else null
	if result == null:
		result = load(entry.path)
		_definitions[entry.path] = weakref(result)
		source_hashes[entry.path] = FileAccess.get_sha256(entry.path)
	return result

func _table(category: StringName) -> Dictionary:
	if not _tables.has(category):
		var table := {}
		for id in catalog.table(category):
			table[id] = definition(category, id)
		_tables[category] = table
	return _tables[category]

## 開発中は実験場の保存で生成物が古くなるため、ステージ開始ごとに確認する。
func _ensure_runtime_content() -> bool:
	if not OS.has_feature("editor"):
		return true
	var builder = load("res://addons/content_build/builder.gd")
	if builder.is_current():
		return true
	var error: Error = builder.build_all()
	if error != OK:
		push_error("実行用データの自動生成に失敗: %s" % error_string(error))
		return false
	if catalog != null:
		catalog = ResourceLoader.load("res://data/content_catalog.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as ContentCatalog
		release_runtime_definitions()
	return true

func runtime_stage(index: int) -> RuntimeStage:
	if not _ensure_runtime_content():
		get_tree().quit(1)
		return null
	# 同じ実行中に再生成したステージも、古い読み込み済みリソースを使わず読む。
	var mode := ResourceLoader.CACHE_MODE_IGNORE_DEEP if OS.has_feature("editor") else ResourceLoader.CACHE_MODE_REUSE
	return ResourceLoader.load("res://.content/stage_%d.tres" % index, "", mode) as RuntimeStage

## 読込タスクは結果の資源と終了まで所有し、取り消した要求も回収する。
# Godot 4.6.3 の load_threaded_* は、依存読込との競合で内部トークンが残る。
# load() と結果をこのタスクが所有し、終了を待ってから主スレッドへ渡す。
class ResourceJob:
	extends RefCounted
	var task_id: int
	var resource: Resource
	var waiters: Array[WeakRef] = []
	func start(path: String) -> void:
		task_id = WorkerThreadPool.add_task(_load.bind(path), false, "Load " + path)
	func _load(path: String) -> void:
		resource = ResourceLoader.load(path)
	func finish() -> void:
		# 終了時はフレームが進まないので、描画資源の作成要求も主スレッドで処理する。
		while not WorkerThreadPool.is_task_completed(task_id):
			RenderingServer.force_sync()
			OS.delay_usec(1000)
		WorkerThreadPool.wait_for_task_completion(task_id)

var _resource_jobs: Dictionary = {}
func prepare_resources(paths: PackedStringArray, threaded := true) -> ContentResourceScope:
	var scope := ContentResourceScope.new()
	if paths.is_empty(): scope.warmup_complete = true
	for path in paths:
		if scope.resources.has(path) or path in scope.pending: continue
		# スクリプト・シーン・複合資源の依存解決は主スレッドに集約する。
		# 独立した画像・音源・シェーダーの読込だけを非同期にする。
		if not threaded or path.get_extension() not in ["png", "svg", "jpg", "jpeg", "webp",
			"wav", "ogg", "mp3", "gdshader", "glsl"]:
			scope.provide(path, load(path))
		elif ResourceLoader.has_cached(path):
			scope.provide(path, ResourceLoader.get_cached_ref(path))
		else:
			scope.pending.append(path)
			if not _resource_jobs.has(path):
				var job := ResourceJob.new()
				_resource_jobs[path] = job
				job.start(path)
			_resource_jobs[path].waiters.append(weakref(scope))
	return scope
func pending_resources() -> int:
	return _resource_jobs.size()
func _process(_delta: float) -> void:
	for path: String in _resource_jobs.keys():
		var job: ResourceJob = _resource_jobs[path]
		if not WorkerThreadPool.is_task_completed(job.task_id): continue
		job.finish()
		for reference: WeakRef in job.waiters:
			var scope := reference.get_ref() as ContentResourceScope
			if scope != null: scope.provide(path, job.resource)
		_resource_jobs.erase(path)

func _exit_tree() -> void:
	for job: ResourceJob in _resource_jobs.values(): job.finish()
	_resource_jobs.clear()

func release_runtime_definitions() -> void:
	_tables.clear()
	_definitions.clear()
