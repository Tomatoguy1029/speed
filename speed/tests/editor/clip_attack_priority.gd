## クリップ優先度だけの確認。通常実行で伝播・待機順、--editorで実際のInspectorとUndo/Redoを確認する。
## godot --headless --path speed --script res://tests/editor/clip_attack_priority.gd
## godot --headless --editor --path speed --script res://tests/editor/clip_attack_priority.gd
@tool
extends SceneTree

const SAVE := "/tmp/speed-clip-priority-fixture.tres"
var checks := 0
var failed := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed += 1
		push_error(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if Engine.is_editor_hint():
		await _editor_checks()
	else:
		await _runtime_checks()
	check(checks == (7 if Engine.is_editor_hint() else 16), "All targeted checks completed")
	DirAccess.remove_absolute(SAVE)
	print("[clip_attack_priority] %d checks, %d failures" % [checks, failed])
	quit(1 if failed else 0)

func _runtime_checks() -> void:
	var clip := SpawnClip.new()
	check(clip.attack_priority == 0.0, "New clip defaults to zero")
	var legacy := FileAccess.open(SAVE, FileAccess.WRITE)
	legacy.store_string('[gd_resource type="Resource" load_steps=2 format=3]\n[ext_resource type="Script" path="res://scripts/data_types/spawn_clip.gd" id="1"]\n[resource]\nscript = ExtResource("1")\n')
	legacy.close()
	var loaded: SpawnClip = ResourceLoader.load(SAVE, "", ResourceLoader.CACHE_MODE_IGNORE)
	check(loaded.attack_priority == 0.0, "Legacy clip without property loads as zero")
	clip.attack_priority = 1.0
	check(ResourceSaver.save(clip, SAVE) == OK, "Priority saves")
	loaded = ResourceLoader.load(SAVE, "", ResourceLoader.CACHE_MODE_IGNORE)
	check(loaded.attack_priority == 1.0, "Priority survives reload")
	var cfg: GameConfig = ContentManager.base.duplicate(true)
	cfg.planet_radius = 0.0
	var stage := RuntimeStage.new()
	stage.index = 245
	stage.enemy_attack_priorities = {"aquarius":9.0,"telescope":5.0}
	stage.resources = StageResources.new()
	stage.resources.enemy_ids = PackedStringArray(["aquarius","telescope","ruler"])
	clip.formations = [load("res://data/formations/aquarius_solo.tscn")]
	clip.types = [&"aquarius"]
	clip.length = 10.0
	stage.clips = [load("res://tools/content/build_runtime_stage.gd").clip(clip)]
	var data := {"layouts":[{"weight":1.0,"markers":[{"type":&"aquarius","pos":Vector2.ZERO,"rot":0.0},{"type":&"telescope","pos":Vector2(100,0),"rot":0.0}]}],"entries":[{"weight":1.0,"pos":Vector2.ZERO,"rot":0.0}]}
	var phase := PhaseDef.new()
	phase.pop_from=0.0;phase.pop_to=0.0;phase.rate=0.0
	stage.phases=[phase]
	var builder = load("res://tools/content/build_run_content.gd")
	var output := "res://.content/dev/clip_priority"
	var built: Error = builder.build(stage,cfg,output,"クリップの優先度".sha256_text(),{},[data])
	var bridge = load("res://scripts/runtime/run_bridge.gd").new()
	var ready := false
	if built==OK:
		var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("stage_245.json")))
		ready = bridge.configure(FileAccess.get_file_as_bytes(index.binary),{"api_version":1,"run_id":245,"mode":1,"stage_id":"priority","profile":{},"settings":{}}).ok and bridge.start(932).ok
	if not ready:
		check(false,"優先度の編集値をC++ランへ生成する")
		bridge.dispose()
		return
	var core = bridge._core
	var aquarius: int = core.spawn_enemy(&"aquarius",Vector2.ZERO,{})
	check(_priority(core,aquarius).priority==9.0,"通常出現はステージの優先度を使う")
	var ids: PackedInt64Array = core.spawn_formation(1,0,0,PackedStringArray(),-1.0,0.0,null)
	check(not ids.is_empty() and _all_priority(core,ids,0.0),"クリップの明示的な0で全種類の優先度を上書きする")
	ids = core.spawn_formation(1,0,0,PackedStringArray(),2.0,1.0,null)
	check(not ids.is_empty() and _all_priority(core,ids,1.0),"共有の優先度を編成の全種類へ渡す")
	check(not ids.is_empty() and _priority(core,ids[0]).value==2.0,"優先度と独立した共有コストを保つ")
	if ids.is_empty(): bridge.dispose();return
	var part: Dictionary = bridge.command("dev_spawn_part",{"parent_id":int(ids[0]),"definition_id":"telescope","position":Vector2.ZERO})
	check(part.ok and _priority(core,int(part.value)).priority==1.0,"派生部位は親の優先度を受け取る")
	core.configure_attack_budget({"enabled":false})
	core.spawn_enemy(&"ruler",Vector2.ZERO,{"attack_priority":1.0})
	core.step(float(ContentManager.enemies[&"ruler"].params.split_delay)+0.01)
	var halves: Array = core.enemies_snapshot().filter(func(row):return row.type=="ruler")
	check(halves.size()==2 and _priority(core,halves[1].id).priority==1.0,"分裂した定規も優先度を保つ")
	# 通常更新が持つクリップへ、生成済みの索引を戻してInspector値を確認する。
	core.step_clips()
	var groups: Array = core.clips_snapshot()[0].groups
	check(not groups.is_empty() and not groups[0].is_empty() and _all_priority(core,groups[0],1.0),"通常更新のクリップ出現にInspector値を渡す")
	var cats := PackedStringArray(["beam"])
	for names in [["formation:99","1"],["1","formation:99"]]:
		core.configure_attack_budget({"enabled":true,"budget":0.0,"jitter":0.0})
		core.request_attack(names[0],cats,ids[0],1.0,0.0,1.0)
		core.request_attack(names[1],cats,ids[-1],1.0,0.0,1.0)
		core.configure_attack_budget({"enabled":true,"budget":1.0,"jitter":0.0})
		check(not core.request_attack(names[1],cats,ids[-1],1.0,0.0,1.0) and core.request_attack(names[0],cats,ids[0],1.0,0.0,1.0),"同順位は所有者名に関係なく登録順を使う: "+names[0])
		core.cancel_attack(names[0],ids[0]);core.cancel_attack_wait(names[1],ids[-1])
	core.configure_attack_budget({"enabled":true,"budget":0.0,"jitter":0.0})
	core.request_attack("low",cats,ids[0],1.0,0.0,1.0)
	core.request_attack("high",cats,ids[-1],1.0,1.0,1.0)
	var waiting: Array = core.attack_budget_snapshot().waiting
	check(waiting.size()==2 and waiting[0].priority==0.0 and waiting[1].priority==1.0,"要求の優先度へ画面内の加点を足さない")
	core.configure_attack_budget({"enabled":true,"budget":1.0,"jitter":0.0})
	check(core.request_attack("high",cats,ids[-1],1.0,1.0,1.0),"高い優先度を先に許可する")
	core.cancel_attack("high",ids[-1]);core.cancel_attack_wait("low",ids[0])
	core.configure_attack_budget({"enabled":true,"budget":0.0,"jitter":0.0})
	core.request_attack("older",cats,ids[0],1.0,0.0,1.0)
	core.advance_attack_budget(core.attack_budget_snapshot().now+6.0)
	core.request_attack("newer",cats,ids[-1],1.0,1.0,1.0)
	core.configure_attack_budget({"enabled":true,"budget":1.0,"jitter":0.0})
	check(core.request_attack("older",cats,ids[0],1.0,0.0,1.0),"待ち時間による公平性を保つ")
	bridge.dispose()

func _priority(core, id: int) -> Dictionary:
	for row: Dictionary in core.enemy_attack_snapshot():
		if row.id==id:return row
	return {}

func _all_priority(core, ids, value: float) -> bool:
	for id in ids:
		if _priority(core,int(id)).get("priority",-1.0)!=value:return false
	return true

func _editor_checks() -> void:
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	# 初回スキャン後に初期化されるエディタープラグインの接続まで待つ。
	for frame in 5:
		await process_frame
	var stage := StageDef.new()
	var clip := SpawnClip.new()
	stage.clips = [clip]
	stage.enemies = [&"aquarius"]
	ResourceSaver.save(stage, SAVE)
	stage = ResourceLoader.load(SAVE, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	clip = stage.clips[0]
	EditorInterface.inspect_object(stage)
	for frame in 3:
		await process_frame
	var stage_field := _property_field(stage, &"enemy_attack_priorities")
	var numbers: Array = stage_field.get("_numbers") if stage_field != null else []
	check(numbers.size() == 1 and numbers[0].min_value == 0.0 and numbers[0].max_value == 5.0
		and numbers[0].step == 1.0 and numbers[0].rounded, "Stage priority Inspector uses integers zero through five")
	EditorInterface.inspect_object(clip)
	await process_frame
	var priority_property: Dictionary = {}
	for property in clip.get_property_list():
		if property.name == &"attack_priority":
			priority_property = property
	var limits := str(priority_property.get("hint_string", "")).split(",")
	check(priority_property.get("type") == TYPE_INT and limits.size() == 3 and float(limits[0]) == 0.0
		and float(limits[1]) == 5.0 and float(limits[2]) == 1.0,
		"Clip priority Inspector uses integers zero through five")
	var field := _property_field(clip, &"attack_priority")
	check(field != null, "Selected clip Inspector exposes Attack Priority")
	if field == null:
		return
	field.emit_changed(&"attack_priority", 1.0)
	await process_frame
	check(clip.attack_priority == 1.0, "Inspector change updates clip")
	var plugin := EditorPlugin.new()
	var manager := plugin.get_undo_redo()
	var history := manager.get_history_undo_redo(manager.get_object_history_id(clip))
	history.undo()
	await process_frame
	check(clip.attack_priority == 0.0, "Inspector undo restores zero")
	history.redo()
	for frame in 3:
		await process_frame
	check(clip.attack_priority == 1.0, "Inspector redo restores one")
	var loaded: StageDef = ResourceLoader.load(SAVE, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	check(loaded.clips[0].attack_priority == 1.0, "Timeline autosave persists redone clip priority")
	EditorInterface.inspect_object(null)
	history.clear_history()
	plugin.free()

func _property_field(object: Object, property: StringName) -> EditorProperty:
	var stack: Array[Node] = [EditorInterface.get_inspector()]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is EditorProperty and node.get_edited_object() == object and node.get_edited_property() == property:
			return node
		stack.append_array(node.get_children())
	return null
