## シミュレーション時間が短くても、描画の実時間が長い回は次の投入量を減らす。
extends Node
var failed := 0

class BudgetWarmup:
	extends "res://scripts/render/shader_warmup.gd"
	var submitted := 0
	func _geometry(_parent: Node, _material: Material, _texture: Texture2D) -> void:
		submitted += 1

func _ready() -> void:
	var scope := ContentResourceScope.new()
	scope.warming = true
	scope.warm_materials.resize(24)
	var warmup := BudgetWarmup.new()
	add_child(warmup)
	warmup.set_process(false)
	warmup._scope = scope
	warmup._batch = 4
	var layer := CanvasLayer.new()
	warmup.add_child(layer)
	warmup._layers.append(layer)
	warmup._process(1.0 / 60.0)
	_check(warmup.submitted == 4, "最初の組を投入する")
	# Godotのdeltaは長い停止を丸めるため、短いdeltaのまま実時間だけ遅らせる。
	OS.delay_msec(150)
	warmup._process(1.0 / 60.0)
	_check(warmup.submitted == 4, "描画待ちのフレームでは次を投入しない")
	warmup._process(1.0 / 60.0)
	_check(warmup.submitted == 6, "実時間が長い組の後は投入量を4から2へ減らす")
	var submitted: int = warmup.submitted
	scope.cancel()
	warmup._process(1.0 / 60.0)
	_check(not scope.warming and warmup.submitted == submitted, "取り消した準備へ新しい素材を投入しない")
	await get_tree().process_frame
	print("[shader_warmup_budget] 失敗=%d" % failed)
	get_tree().quit(1 if failed else 0)

func _check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
	else:
		print("[shader_warmup_budget] ", label)
