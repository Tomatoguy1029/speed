## 二つのネイティブランの寿命と、無効な更新で状態が壊れないことを確かめる。
extends Node
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	var comparison = load("res://tools/compare_runtime.gd").new()
	var first = comparison.create_native()
	if first == null:
		check(false, "ネイティブランを読み込める")
	else:
		var second = comparison.create_native()
		check(not first.step(0.01), "開始前の更新を拒否する")
		check(first.start(932) and second.start(933), "別々のランを開始する")
		check(not first.start(934), "開始済みのランを再初期化しない")
		var before: Dictionary = first.inspect()
		for delta in [0.0, -1.0, INF, NAN]:
			check(not first.step(delta), "無効な経過時間を拒否する")
		check(first.inspect() == before, "拒否した更新で状態を変えない")
		check(first.step(0.5), "開始したランを更新する")
		check(first.inspect().time == 0.5 and second.inspect().time == 0.0, "ランの時計を共有しない")
		check(first.inspect().rng_state != second.inspect().rng_state, "ランごとの乱数を持つ")
		first.close()
		first.close()
		check(not first.step(0.1) and not first.start(932), "終了後の更新と再開始を拒否する")
		first = null
		check(second.step(0.25) and second.inspect().time == 0.25, "別ランの解放後も更新できる")
		second.close()
	print("[native_runtime] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)
