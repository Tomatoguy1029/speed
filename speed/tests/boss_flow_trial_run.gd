## 技ノードから指定したボス・技を一度再生し、別の技を抽選しない。
extends SceneTree
var failed := 0
func _initialize() -> void: call_deferred("exercise")
func exercise() -> void:
	var custom = ResourceLoader.load("res://.content/boss_monoceros.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	custom.data.rules.combos.test_combo = {"type": "sequence", "children": [{"type": "action", "id": "charge"}, {"type": "wait", "seconds": 0.1}, {"type": "action", "id": "charge"}]}
	custom.data.rules.costs.test_combo = 3.0
	DirAccess.make_dir_recursive_absolute("res://.content/tests")
	ResourceSaver.save(custom, "res://.content/tests/monoceros_combo_preview.tres")
	for entry in [["hydra", "bite_thrust"], ["monoceros", "kick"], ["monoceros", "test_combo"], ["draco", "bite"]]:
		var trial = load("res://gyms/boss_flow_trial.tscn").instantiate()
		trial.set_meta("preview_request", {"boss": entry[0], "technique": entry[1]})
		trial.set_meta("preview_program", "res://.content/tests/monoceros_combo_preview.tres" if entry[1] == "test_combo" else "res://.content/boss_" + entry[0] + ".tres")
		root.add_child(trial)
		for frame in 20: await process_frame
		var actor = trial.session.run.bosses.actor
		if actor == null or String(actor.def.id) != entry[0]:
			failed += 1
			push_error("指定ボスの実験場を開けません: " + entry[0])
		else:
			trial.session.playing = false
			for step in 600: trial.session.step()
			var chosen: Array = actor.flow_runner.last
			if chosen.size() != 1 or chosen[0].id != entry[1]:
				failed += 1
				push_error("選択技の単独再生になっていません: " + entry[1])
			if entry[1] == "test_combo" and (actor.flow_adapter.custom_run != null or actor.mode != &"idle" or actor.flow_runner.index != 1):
				failed += 1
				push_error("一角獣のカスタムコンボが完了しません")
		trial.queue_free()
		await process_frame
	print("[boss-trial] failures=", failed)
	quit(1 if failed else 0)
