extends Node
var failed:=0
func check(ok: bool,label: String)->void:
	print("[hydra-grid] ","PASS " if ok else "FAIL ",label)
	if not ok:failed+=1
func _ready()->void:
	var script=load("res://scripts/bosses/hydra_grid.gd")
	check(script!=null,"grid planner exists")
	if script!=null:
		var p: Dictionary=ConfigManager.bosses[&"hydra"].params
		var rect:=Rect2(-640,-360,1280,720)
		check(script.region(Vector2.ZERO,rect)==&"center" and script.region(Vector2(550,0),rect)==&"right" and script.region(Vector2(-550,0),rect)==&"left" and script.region(Vector2(0,-300),rect)==&"up" and script.region(Vector2(0,300),rect)==&"down","five view regions are distinct")
		for size in [Vector2(1280,720),Vector2(720,1280),Vector2(1024,768)]:
			var area:=Rect2(-size*0.5,size)
			var plan: Dictionary=script.build(area,Vector2.ZERO,8,p,26.0,1000.0)
			check(not plan.is_empty(),"provisional path fits "+str(size))
			if not plan.is_empty():
				check(script.path_clear(plan.path,plan.beams,26.0+float(p.beam_width)*0.5),"one stroke passes all intact finite beams")
				check(plan.path[-1].distance_to(plan.bearer)<0.001,"path ends at compass bearer")
		check(script.build(rect,Vector2.ZERO,1,p,26.0,1000.0).is_empty(),"insufficient survivors cannot form grid")
		check(script.build(rect,Vector2.ZERO,8,p,26.0,100.0).is_empty(),"route longer than drawing budget is rejected")
	get_tree().quit(1 if failed else 0)
