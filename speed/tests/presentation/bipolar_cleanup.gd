## 実行フレームから消えた双極ビームの描画ノードを残さない。
extends Node
var failed := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failed += 1
		push_error(message)
	else:
		print("[bipolar_cleanup] OK ",message)
func _ready() -> void:
	var layer := Node2D.new()
	var top := Node2D.new()
	add_child(layer)
	add_child(top)
	var visual = preload("res://scripts/render/equipment/bipolar.gd").new()
	visual.setup_frame(layer,top,2.0)
	var state := {"active":false,"origin":Vector2.ZERO,"started":0.0,"pending":[],"beams":[{"id":7,"from":Vector2.ZERO,"to":Vector2(300,0),"age":0.68,"width_scale":1.0}]}
	var ship := {"ship_pos":Vector2(300,0)}
	var view := Rect2(-400,-300,800,600)
	visual.sync_frame(state,ship,0.68,view)
	visual.frame_tick(0.016)
	var first: Node = visual.beams[0].node
	check(visual.beams.size()==1 and not first.is_queued_for_deletion(),"a live beam is visible")
	visual.sync_frame(state,ship,0.68,view)
	visual.frame_tick(0.0)
	check(visual.beams.size()==1 and visual.beams[0].node==first,"paused snapshots preserve one beam without duplication")
	state.beams.append({"id":8,"from":Vector2(0,100),"to":Vector2(300,100),"age":0.1,"width_scale":1.0})
	visual.sync_frame(state,ship,0.69,view)
	check(visual.beams.size()==2,"overlapping beams keep separate nodes")
	var second: Node = visual.beams[1].node
	state.beams.remove_at(0)
	visual.sync_frame(state,ship,0.7,view)
	visual.frame_tick(0.016)
	check(first.is_queued_for_deletion(),"an expired beam queues its drawing node for deletion")
	check(visual.beams.size()==1 and visual.beams[0].node==second,"expiring one beam preserves the other")
	state.beams.clear()
	visual.sync_frame(state,ship,0.8,view)
	visual.frame_tick(0.016)
	check(visual.beams.is_empty() and second.is_queued_for_deletion(),"the final beam disappears when the frame has no beams")
	await get_tree().process_frame
	check(not is_instance_valid(first) and not is_instance_valid(second),"expired mesh nodes leave the scene tree")
	visual.dispose()
	await get_tree().process_frame
	layer.free()
	top.free()
	print("BIPOLAR_CLEANUP_RESULT failed=",failed)
	get_tree().quit(1 if failed else 0)
