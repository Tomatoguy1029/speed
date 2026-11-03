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
var _busy := false
var _definition_order := PackedStringArray()

static func for_session(owner: RunSession) -> RefCounted:
	if owner.has_meta("dev_content_edit"): return owner.get_meta("dev_content_edit")
	var editor = load("res://scripts/dev/run_content_edit.gd").new()
	if not editor.attach(owner): return editor
	owner.set_meta("dev_content_edit",editor)
	return editor

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
	var current: Dictionary = owner.bridge.read_lab()
	if not current.ok:
		error = "このランの定義を読み込めません。"
		return false
	source.resources = source.resources.duplicate(true)
	_definition_order = current.value.definition_ids.duplicate()
	# ランの定義にはボス本体と技内部の種類も含まれる。通常敵だけを制作元へ戻す。
	source.resources.enemy_ids = PackedStringArray()
	for id: String in _definition_order:
		if definitions.has(StringName(id)) or ContentManager.catalog.find(&"enemies", id) != null:
			source.resources.enemy_ids.append(id)
	# このランで参照する基準を最初に複製し、以後の再読込から隔離する。
	for id: String in source.resources.enemy_ids:
		if not definitions.has(StringName(id)):
			var entry: ContentEntry = ContentManager.catalog.find(&"enemies", id)
			var definition: EnemyDef = ResourceLoader.load(entry.path,"",ResourceLoader.CACHE_MODE_IGNORE_DEEP) if entry != null else null
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
	if _busy: return _failure("資源の準備中です。")
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
	var built: Error = BUILD.build(next,config,output,signature,definitions,[],{},owner.cpp_resources,{},_definition_order)
	if built!=OK: return _failure("定義の生成に失敗しました: %s" % error_string(built))
	var index_path := output.path_join("stage_%d.json" % next.index)
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(index_path))
	var prepared := LOADER.read_bundle(index_path,index.input_sha256)
	if prepared.is_empty(): return _failure("生成した定義を読み込めません。")
	var result: Dictionary = owner.bridge.replace_definition("config",prepared.bytes,"config")
	if result.ok:
		values = tuning.duplicate(true)
		source = next
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

## パネルの値は、このSessionの複製を正規生成してからまとめて適用する。
func apply_config(next_config: GameConfig) -> Dictionary:
	if _busy: return _failure("資源の準備中です。")
	var owner: RunSession = session.get_ref() if session!=null else null
	if owner==null or owner.bridge==null: return _failure("対象のランは終了しています。")
	var built: Dictionary = _build(source,next_config)
	if not built.ok: return built
	var result: Dictionary = owner.bridge.replace_definition("config",built.value.bytes,"config")
	if result.ok: config = next_config
	return result

func _build(stage: RuntimeStage, next_config: GameConfig) -> Dictionary:
	var owner: RunSession = session.get_ref() if session!=null else null
	if owner==null or owner.bridge==null: return _failure("対象のランは終了しています。")
	var output := "res://.content/dev/debug_%d" % owner.id
	var built: Error = BUILD.build(stage,next_config,output,signature,definitions,[],{},owner.cpp_resources,{},_definition_order)
	if built!=OK: return _failure("定義の生成に失敗しました: %s" % error_string(built))
	var path := output.path_join("stage_%d.json" % stage.index)
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var prepared: Dictionary = LOADER.read_bundle(path,index.input_sha256)
	return {"ok":true,"value":prepared} if not prepared.is_empty() else _failure("生成した定義を読み込めません。")

## ステージ外の敵は、明示生成時にだけ追加する。古い資源番号と装備の保留要求を保つ。
func prepare_debug_enemies() -> Dictionary:
	if _busy: return _failure("資源の準備中です。")
	var owner: RunSession = session.get_ref() if session!=null else null
	if owner==null or owner.bridge==null: return _failure("対象のランは終了しています。")
	var next := source.duplicate(true) as RuntimeStage
	var choices := PackedStringArray()
	for entry: ContentEntry in ContentManager.sorted(ContentManager.catalog.table(&"enemies")):
		var id := String(entry.id)
		var definition: EnemyDef = definitions.get(entry.id)
		if definition==null:
			definition = ResourceLoader.load(entry.path,"",ResourceLoader.CACHE_MODE_IGNORE_DEEP).duplicate(true)
			definitions[entry.id] = definition
		if definition.behavior not in [&"part",&"meteor",&"obstacle",&"saw",&"triangle_star"]: choices.append(id)
		if id not in next.resources.enemy_ids: next.resources.enemy_ids.append(id)
	if next.resources.enemy_ids==source.resources.enemy_ids: return {"ok":true,"value":choices}
	var built := _build(next,config)
	if not built.ok: return built
	_busy = true
	var prepared: Dictionary = built.value
	var paths := PackedStringArray()
	for path: String in prepared.resources.paths:
		if not owner.resources.resources.has(path): paths.append(path)
	var scope: ContentResourceScope = ContentManager.prepare_resources(paths,DisplayServer.get_name()!="headless",prepared.resources.signatures)
	owner.closing.connect(scope.cancel.unbind(1),CONNECT_ONE_SHOT)
	while not scope.is_ready() and is_instance_valid(owner) and owner.bridge!=null:
		await owner.get_tree().process_frame
	while not scope.failed and not scope.cancelled and not scope.warmup_complete and is_instance_valid(owner) and owner.bridge!=null:
		load("res://scripts/render/run_presentation.gd").warm_resources(owner,scope)
		if not scope.warmup_complete: await owner.get_tree().process_frame
	_busy = false
	if not is_instance_valid(owner) or owner.bridge==null or scope.failed or scope.cancelled:
		scope.cancel()
		return _failure("追加の外観資源を準備できません。")
	var result: Dictionary = owner.bridge.replace_definition("config",prepared.bytes,"debug_content")
	if not result.ok:
		scope.cancel()
		return result
	for path: String in scope.resources: owner.resources.provide(path,scope.resources[path])
	scope.cancel()
	owner.cpp_resources = prepared.resources
	if owner.cpp_choices!=null: owner.cpp_choices.resources = prepared.resources
	if is_instance_valid(owner.view):
		var presentation: Node = owner.view.get_node("RunPresentation")
		presentation.cpp_resources = prepared.resources
		if presentation.frame_view!=null: presentation.frame_view.replace_lab_visuals(owner.resources,prepared.resources.visuals)
	source = next
	_definition_order = owner.bridge.read_lab().value.definition_ids.duplicate()
	return {"ok":true,"value":choices}
