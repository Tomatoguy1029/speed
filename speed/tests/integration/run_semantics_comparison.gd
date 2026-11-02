## 移行比較器が同じ入力の一致と、操作・寿命・停止の差を検出することを確認する。
extends Node
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	var path := "res://tools/compare_runtime.gd"
	if not ResourceLoader.exists(path):
		check(false, "固定入力の比較器が存在する")
	else:
		var compare = load(path).new()
		var spec := {"seed": 932, "empty": true, "config": {"drop_base": 0.0, "drop_max": 0.0}}
		var commands := [
			{"tick": 0, "kind": "spawn", "args": {"type": "drifter", "pos": [500, 0]}},
			{"tick": 0, "kind": "input", "args": {"cursor": [900, 0]}},
			{"tick": 10, "kind": "hitstop", "args": {"seconds": 0.1}},
			{"tick": 20, "kind": "delete", "args": {"id": 1}},
			{"tick": 21, "kind": "spawn", "args": {"type": "drifter", "pos": [500, 0]}}]
		var spawned: Dictionary = await compare.record(self, spec, [commands[0]], 1)
		var first_id: int = spawned.frames[1].enemies[0].id
		commands[3].args.id = first_id
		var first: Dictionary = await compare.record(self, spec, commands, 40)
		var second: Dictionary = await compare.record(self, spec, commands, 40)
		check(compare.difference(first, second).is_empty(), "同じ入力とシードで各更新の結果が一致する")
		check(first.frames[11].world_time == first.frames[10].world_time, "ヒットストップで世界の時計が止まる")
		check(first.frames[1].enemies[0].id == first_id, "削除の対象IDは最初の個体を指す")
		check(first.frames[21].enemies.is_empty(), "削除後の空状態を記録する")
		check(first.frames[22].enemies[0].id != first.frames[1].enemies[0].id, "再利用した行を古い個体と区別する")
		var changed := commands.duplicate(true)
		changed[1].args.cursor = [0, 900]
		var third: Dictionary = await compare.record(self, spec, changed, 40)
		check(not compare.difference(first, third).is_empty(), "入力が変わった結果の差を検出する")
		var corrupted := first.duplicate(true)
		corrupted.frames[5].rng_state = "別の乱数状態"
		check(compare.difference(first, corrupted).contains("rng_state"), "乱数の差を位置と別に指摘する")
	print("[runtime_comparison] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)
