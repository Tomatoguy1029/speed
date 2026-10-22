## 1つのランの寿命の持ち主（設計書 4.3）。RunManager が作り、消えるとランも終わる。
##
## シミュレーション（RunSimulation）と、任意の表示（scenes/run/run.tscn）を持つ。
## 表示のない試行は表示を作らず、ボスの役者は見えないノードの下に置く。
class_name RunSession
extends Node

const VIEW_PATH := "res://scenes/run/run.tscn"

## RunManager が振る番号。破棄したあとの命令を見分ける
var id := 0
var sim := RunSimulation.new()
## 表示（表示のない試行では null）
var view: Node
## 固定更新を自分で進めるか。実験場は自分の時計で sim を進める
var auto_step := true

## 木に入ったあとに呼ぶ。表示を作る場合は、シミュレーションを組み立ててから表示を木に入れる。
func start(options: Dictionary, with_view: bool) -> void:
	sim.options = options
	sim.view_size_source = func(): return get_viewport().get_visible_rect().size
	if with_view:
		view = load(VIEW_PATH).instantiate()
		for path in ["RunPresentation", "Hud/HudRoot", "Hud/DebugPanel", "Hud/PerfOverlay"]:
			view.get_node(path).run = sim
		if options.get("lab", false):
			# 実験場の調整は実験場のパネルで行う。本番の調整パネル・性能表示は使わない
			view.get_node("Hud/DebugPanel").free()
			view.get_node("Hud/PerfOverlay").free()
		sim.input = view.get_node("World/InputRouter")
		sim.actor_parent = view.get_node("World")
	else:
		var actors := Node2D.new()
		actors.name = "Actors"
		actors.visible = false
		add_child(actors)
		sim.actor_parent = actors
	sim.setup()
	if view != null:
		add_child(view)

func _physics_process(delta: float) -> void:
	if auto_step:
		sim.physics_step(delta)

func _process(_delta: float) -> void:
	sim.flush_events()

## 実験場はチェックポイントのために木から外して持つので、片付けは消えるときに行う。
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# 記録の終了と役者の退出は、シミュレーションの参照が使える間に済ませる。
		if is_inside_tree():
			get_parent().remove_child(self)
		sim.dispose()
		if is_instance_valid(RunManager):
			RunManager.unregister(self)
