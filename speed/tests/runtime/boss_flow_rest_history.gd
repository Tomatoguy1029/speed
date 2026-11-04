extends "res://tests/runtime/boss_flow_runner.gd"
func exercise() -> void:
	var f:=fixture({"a":{"category":"major","cost":2.0},"b":{"category":"major","cost":2.0}},[{"request":"any","cap":2.0,"weights":{"major":100.0},"next":0}],{"stamina":2.0,"empty_rest":0.01})
	if f.is_empty():done("boss_flow_rest_history");return
	var previous: Array=[]
	for i in 32:
		var selected:=next_action(f)
		check(selected.size()==1 and selected!=previous,"休息を挟んでも直前の技を避ける")
		previous=selected
	close(f)
	f=fixture({"a":{"category":"major","cost":2.0}},[{"request":"any","cap":2.0,"weights":{"major":100.0},"next":0}],{"stamina":2.0,"empty_rest":0.01})
	if not f.is_empty():
		for i in 4:check(next_action(f)==["a"],"唯一の候補は休息後も使える")
		close(f)
	done("boss_flow_rest_history")
