## ステージの資源を列挙し、非同期読み込みを取り消しても参照が残らない。
extends Node
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	check(ContentManager.has_method("prepare_resources"), "資源をまとめて準備できる")
	if ContentManager.has_method("prepare_resources"):
		var fixture: Resource = Resource.new()
		fixture.resource_name = "scope_fixture"
		var path := "/tmp/speed-scope-fixture.tres"
		ResourceSaver.save(fixture, path)
		fixture = null
		var scope: RefCounted = ContentManager.prepare_resources(PackedStringArray([path]), true)
		while not scope.is_ready(): await get_tree().process_frame
		var reference: WeakRef = weakref(scope.resources[path])
		check(reference.get_ref() != null, "準備中は資源を保持する")
		scope.cancel()
		await get_tree().process_frame
		await get_tree().process_frame
		check(reference.get_ref() == null, "取り消しで資源を解放する")
		var abandoned: RefCounted = ContentManager.prepare_resources(PackedStringArray([path]), true)
		abandoned.cancel()
		while ContentManager.pending_resources() > 0: await get_tree().process_frame
		check(abandoned.resources.is_empty(), "読込途中の取り消しも保持を復活させない")
	var probe := RunSession.new()
	check(probe.has_method("start_loading"), "ランの開始前に読み込みを待てる")
	var supports_loading := probe.has_method("start_loading")
	probe.free()
	if supports_loading:
		GameManager.run_stage = 4
		var session := RunManager.create_run()
		add_child(session)
		check(session.sim.state == null, "読込中は戦闘を開始しない")
		session.free()
		while ContentManager.pending_resources() > 0: await get_tree().process_frame
		check(RunManager.current() == null, "読込中に画面を離れてもセッションを解放する")

		var loaded := RunManager.create_run()
		add_child(loaded)
		if loaded.sim.state == null: await loaded.started
		await _check_debug_spawns(loaded, 2)
		await _check_debug_spawns(loaded, 600)
		await _check_debug_spawns(loaded, 600)
		await get_tree().process_frame
		var stage_reference: WeakRef = weakref(loaded.resources.resources["res://data/enemies/aquarius.tres"])
		loaded.free()
		await get_tree().process_frame
		check(stage_reference.get_ref() == null, "ラン終了後にステージ専用の敵定義を解放する")
		GameManager.run_stage = 4
		var switched := RunManager.create_run()
		add_child(switched)
		if switched.sim.state == null: await switched.started
		await _check_debug_spawns(switched, 2)
		switched.free()

	print("[stage_resources] %d failures" % failed)
	get_tree().quit(1 if failed else 0)

func _check_debug_spawns(session: RunSession, amount: int) -> void:
	var run := session.sim
	var before := run.enemies.count()
	run.command(&"debug_spawn_enemies", {"count": amount})
	check(run.enemies.count() >= before + amount, "デバッグ命令で指定数を生成: %d" % amount)
	var scope := session.resources
	for id in ContentManager.enemies:
		var type := StringName(id)
		var skin := run.state.stage.enemy_sprite_path(type).get_file().get_basename()
		var path: String = run.state.stage.resources.look_paths.get(skin,
			run.state.stage.resources.look_paths.get(String(type), ""))
		if not path.is_empty():
			check(scope.resources.has(path), "派生体を含む敵外観をランのScopeに保持: " + String(type))
	await get_tree().process_frame
