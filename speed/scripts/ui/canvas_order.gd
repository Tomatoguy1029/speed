## ランの層が増えても、同じViewportの案内・録画表示・暗転を手前に保つ。
extends RefCounted
const WORLDS := &"run_canvas_roots"
const OVERLAYS := &"run_canvas_overlays"
const BASE := &"run_canvas_base"
const ORDER := &"run_canvas_order"

static func world_changed(world: Node, layer: int) -> void:
	world.add_to_group(WORLDS)
	world.set_meta(BASE,layer)
	for overlay: Node in world.get_tree().get_nodes_in_group(OVERLAYS):
		_place(overlay as CanvasLayer,world)

static func register(overlay: CanvasLayer, order: int) -> void:
	overlay.add_to_group(OVERLAYS)
	overlay.set_meta(ORDER,order)
	if not overlay.is_inside_tree():
		var entered := _place_registered.bind(overlay)
		if not overlay.tree_entered.is_connected(entered): overlay.tree_entered.connect(entered,CONNECT_ONE_SHOT)
		return
	_place_registered(overlay)

static func _place_registered(overlay: CanvasLayer) -> void:
	for world: Node in overlay.get_tree().get_nodes_in_group(WORLDS):
		_place(overlay,world)

static func _place(overlay: CanvasLayer, world: Node) -> void:
	if overlay==null or overlay.get_viewport()!=world.get_viewport(): return
	overlay.layer = maxi(overlay.layer,int(world.get_meta(BASE))+int(overlay.get_meta(ORDER)))
