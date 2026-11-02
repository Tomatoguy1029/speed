## 対象Sessionだけの未保存値を共通生成で変換する。保存元と保持済みBundleは変更しない。
extends RefCounted

const BUILD := preload("res://tools/content/build_run_content.gd")
const LOADER := preload("res://scripts/runtime/run_content_loader.gd")
var session: WeakRef
var source: RuntimeStage
var config: GameConfig
var definitions: Dictionary = {}
var values: Dictionary = {}
var signature := ""
var error := ""
var saved_index_path := ""
var _saved_bytes := PackedByteArray()

func attach(owner: RunSession) -> bool:
	session = weakref(owner)
	var index = JSON.parse_string(FileAccess.get_file_as_string(owner.cpp_index_path))
	if not index is Dictionary:
		error = "実行した定義の索引を読み込めません。"
		return false
	var explicit: Dictionary = owner.cpp_edit_source
	if not explicit.is_empty():
		if not explicit.get("stage") is RuntimeStage or not explicit.get("config") is GameConfig:
			error = "試行の制作元の形式が不正です。"
			return false
		source = explicit.get("stage").duplicate(true)
		config = explicit.get("config").duplicate(true)
		definitions = explicit.get("definitions",{}).duplicate(true)
	else:
		var builder = load("res://addons/content_build/builder.gd")
		if index.get("source_sha256","")!=builder.signature():
			error = "開始後に編集元が変わっています。保存値を使うには出撃し直してください。"
			return false
		var stage_path := "res://data/stages/stage_%d.tres" % int(index.stage_id)
		var stage: StageDef = ResourceLoader.load(stage_path,"",ResourceLoader.CACHE_MODE_IGNORE_DEEP) if ResourceLoader.exists(stage_path) else null
		if stage==null:
			error = "このランに対応するステージがありません。"
			return false
		config = ContentManager.base.duplicate(true)
		source = load("res://tools/content/build_runtime_stage.gd").compile(stage.duplicate(true),"res://.content",config)
	if source==null or config==null:
		error = "このランの編集元を読み込めません。"
		return false
	# このランで参照する基準を最初に複製し、以後の再読込から隔離する。
	for id: String in source.resources.enemy_ids:
		if not definitions.has(StringName(id)):
			var definition: EnemyDef = ResourceLoader.load("res://data/enemies/%s.tres" % id,"",ResourceLoader.CACHE_MODE_IGNORE_DEEP)
			if definition!=null: definitions[StringName(id)] = definition.duplicate(true)
	values = source.enemy_tuning.duplicate(true)
	signature = index.source_sha256
	return true

func sync_values() -> bool:
	var owner: RunSession = session.get_ref() if session!=null else null
	if owner==null or owner.bridge==null: return false
	var record: Dictionary = owner.bridge.read_recording(true)
	if not record.ok: return false
	values = {}
	for id in record.value.enemy_tuning: values[String(id)] = record.value.enemy_tuning[id].duplicate(true)
	return true

func apply(tuning: Dictionary) -> Dictionary:
	var owner: RunSession = session.get_ref() if session!=null else null
	if owner==null or owner.bridge==null: return _failure("対象のランは終了しています。")
	if tuning==values: return {"ok":true,"value":null}
	for id in tuning:
		if not id is String or not tuning[id] is Dictionary or not definitions.has(StringName(id)): return _failure("編集できる敵がありません。")
		var problem := StageEnemyTuning.error_for(definitions[StringName(id)],tuning[id])
		if not problem.is_empty(): return _failure(problem)
	var next := source.duplicate(true) as RuntimeStage
	next.enemy_tuning = tuning.duplicate(true)
	var output := "res://.content/dev/live_%d" % owner.id
	var built: Error = BUILD.build(next,config,output,signature,definitions)
	if built!=OK: return _failure("定義の生成に失敗しました: %s" % error_string(built))
	var index_path := output.path_join("stage_%d.json" % next.index)
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(index_path))
	var prepared := LOADER.read_bundle(index_path,index.input_sha256)
	if prepared.is_empty(): return _failure("生成した定義を読み込めません。")
	var result: Dictionary = owner.bridge.replace_definition("config",prepared.bytes,"config")
	if result.ok:
		values = tuning.duplicate(true)
		error = ""
	else: error = result.message
	return result

func _failure(message: String) -> Dictionary:
	error = message
	return {"ok":false,"code":1,"field":"tuning","message":message,"value":null}

## 保存済みの編集元を、正規のC++生成入口から次のラン用に作る。
func generate_saved(stage: StageDef, output := "res://.content") -> Error:
	_saved_bytes = PackedByteArray()
	saved_index_path = ""
	var built: Error = load("res://addons/content_build/builder.gd").build_cpp_stage(stage,config,output)
	if built!=OK: return built
	var path := output.path_join("run/stage_%d.json" % stage.index)
	var index = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not index is Dictionary: return ERR_FILE_CORRUPT
	var prepared := LOADER.read_bundle(path,index.input_sha256)
	if prepared.is_empty(): return ERR_FILE_CORRUPT
	_saved_bytes = prepared.bytes
	saved_index_path = path
	return OK

func notify_saved(path: String) -> Dictionary:
	var owner: RunSession = session.get_ref() if session!=null else null
	if owner==null or owner.bridge==null or _saved_bytes.is_empty(): return _failure("保存済みの生成物を通知できません。")
	return owner.bridge.command("dev_tuning_saved",{"path":path,"bundle":_saved_bytes})
