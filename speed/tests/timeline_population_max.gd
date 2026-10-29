## 雑魚の最大目標数がタイムラインの表示幅や再読込で変わらないことを確認する。
## godot --headless --path speed --script res://tests/timeline_population_max.gd
extends SceneTree

const Canvas := preload("res://addons/spawn_timeline/timeline_canvas.gd")
var failures := 0

func _initialize() -> void:
	for stage_number in [1, 2, 4, 5]:
		var path := "res://data/stages/stage_%d.tres" % stage_number
		var totals := []
		for width in [1000.0, 1100.0, 1600.0]:
			var stage: StageDef = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
			var canvas := Canvas.new()
			canvas.size = Vector2(width, 700.0)
			var end := stage.time_limit + 30.0
			var all_values := []
			for curve: SpawnCurve in stage.zako_curves:
				all_values.append(canvas._curve_values(curve, end))
			totals.append(roundi(Canvas._max_curve_total(all_values, end)))
			canvas.free()
		_check(totals[0] > 0 and totals[0] == totals[1] and totals[1] == totals[2],
			"%s: %s" % [path, totals])
		print("[timeline_population_max] %s: %s" % [path, totals])
	_check(is_equal_approx(Canvas._max_curve_total([PackedFloat32Array([1.0, 4.0]),
		PackedFloat32Array([4.0, 1.0])], 1.0), 5.0), "曲線を足してから最大を求める")
	_check(is_equal_approx(Canvas._max_curve_total([PackedFloat32Array([2.0, 4.0])], 0.5), 3.0),
		"末尾が秒の途中でも含める")
	print("[timeline_population_max] failures=%d" % failures)
	quit(1 if failures else 0)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
