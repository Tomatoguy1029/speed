## クリップ優先度だけの確認。通常実行で伝播・待機順、--editorで実際のInspectorとUndo/Redoを確認する。
## godot --headless --path speed --script res://tests/clip_attack_priority.gd
## godot --headless --editor --path speed --script res://tests/clip_attack_priority.gd
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
	check(checks == (5 if Engine.is_editor_hint() else 16), "All targeted checks completed")
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
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	root.add_child(lab)
	await lab.reset({"seed": 932, "empty": true, "stage": 4})
	var em = lab.run.enemies
	var stage := StageDef.new()
	stage.enemy_attack_priorities = {"aquarius": 9.0, "telescope": 5.0}
	lab.run.state.stage = stage
	var aquarius: int = em.spawn(em.def_of(&"aquarius"), Vector2.ZERO)
	check(em.table.attack_priority[aquarius] == 9.0, "Non-clip spawn uses StageDef priority")
	var data := {"layouts": [{"weight": 1.0, "markers": [
		{"type": &"aquarius", "pos": Vector2.ZERO, "rot": 0.0},
		{"type": &"telescope", "pos": Vector2(100, 0), "rot": 0.0}]}],
		"entries": [{"weight": 1.0, "pos": Vector2.ZERO, "rot": 0.0}]}
	var rows: PackedInt32Array = em.spawn_formation(data, 0, 0, [], -1.0, 0.0)
	check(em.table.attack_priority[rows[0]] == 0.0 and em.table.attack_priority[rows[2]] == 0.0,
		"Explicit clip zero overrides both StageDef types")
	rows = em.spawn_formation(data, 0, 0, [], 2.0, 1.0)
	check(em.table.attack_priority[rows[0]] == 1.0 and em.table.attack_priority[rows[2]] == 1.0,
		"Clip priority reaches every type with shared override")
	check(em.table.attack_value[rows[0]] == 2.0, "Priority preserves shared attack cost")
	var part: int = em.spawn_part(rows[0], em.def_of(&"telescope"), Vector2.ZERO)
	check(em.table.attack_priority[part] == 1.0, "Derived part keeps source priority over its type default")
	var ruler: int = em.spawn(em.def_of(&"ruler"), Vector2.ZERO, {"attack_priority": 1.0})
	em._split_ruler(ruler)
	var halves: PackedInt32Array = em.beh_rows[EnemyTable.Beh.RULER]
	check(halves.size() == 2 and em.table.attack_priority[halves[1]] == 1.0, "Ruler split keeps priority")
	# 実際のクリップ出現経路。時刻・配置・数はfixtureのまま使う。
	clip.formations = [load("res://data/formations/aquarius_solo.tscn")]
	clip.types = [&"aquarius"]
	clip.length = 10.0
	stage.clips = [clip]
	lab.run.state.time = 0.0
	em._tick_clips()
	var groups: Array = em._clip_groups[0]
	var spawned: PackedInt32Array = groups[0]
	check(em.table.attack_priority[spawned[0]] == 1.0, "Ticked clip propagates Inspector value")
	var d = load("res://scripts/encounters/attack_director.gd").new()
	d.projectiles = lab.run.projectiles
	d.configure({"enabled": true, "budget": 4.0, "jitter": 0.0})
	d.formation_mode = true
	lab.run.projectiles.director = d
	# 同じ0・同時刻は登録順。owner名や群れの有無で順位を変えない。
	d.queue("formation:99", ["beam"], rows[0], em.table.id[rows[0]], 0.0)
	d.queue("1", ["beam"], rows[2], em.table.id[rows[2]], 0.0)
	check(d._next_owner() == "formation:99", "Equal zero uses registration order across owner kinds")
	d.waiting.clear()
	d.queue("1", ["beam"], rows[2], em.table.id[rows[2]], 0.0)
	d.queue("formation:99", ["beam"], rows[0], em.table.id[rows[0]], 0.0)
	check(d._next_owner() == "1", "Reversed registration reverses tied order")
	d.waiting.clear()
	# 画面外のみずがめ座1と画面内のぼうえんきょう座0を本番の許可経路へ通す。
	var high: int = spawned[0]
	var low: int = em.spawn(em.def_of(&"telescope"), Vector2.ZERO, {"attack_priority": 0.0})
	em.table.pos[high] = Vector2(10000, 0)
	em.table.fire_t[high] = 0.0
	d.configure({"enabled": true, "budget": 0.0, "jitter": 0.0})
	em._lab_admit(low, 0.01)
	em._lab_admit(high, 0.01)
	check(d.waiting[em._lab_owner(low)].priority == 0.0 and d.waiting[em._lab_owner(high)].priority == 1.0,
		"Runtime request has exact configured priorities without view bonus")
	d.settings.budget = 4.0
	check(d._next_owner() == em._lab_owner(high), "Aquarius one precedes newly waiting zero")
	d.waiting.clear()
	d.now = 0.0
	d.queue("older", ["beam"], low, em.table.id[low], 0.0)
	d.now = 6.0
	d.queue("newer", ["beam"], high, em.table.id[high], 1.0)
	check(d._next_owner() == "older", "Existing wait-time fairness remains")
	lab.queue_free()
	await process_frame

func _editor_checks() -> void:
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	# 初回スキャン後に初期化されるエディタープラグインの接続まで待つ。
	for frame in 5:
		await process_frame
	var stage := StageDef.new()
	var clip := SpawnClip.new()
	stage.clips = [clip]
	ResourceSaver.save(stage, SAVE)
	stage = ResourceLoader.load(SAVE, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	clip = stage.clips[0]
	EditorInterface.inspect_object(stage)
	for frame in 3:
		await process_frame
	EditorInterface.inspect_object(clip)
	await process_frame
	var field: EditorProperty
	var stack: Array[Node] = [EditorInterface.get_inspector()]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is EditorProperty and node.get_edited_object() == clip and node.get_edited_property() == &"attack_priority":
			field = node
		stack.append_array(node.get_children())
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
