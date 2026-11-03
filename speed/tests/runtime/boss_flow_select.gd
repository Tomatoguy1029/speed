extends "res://tests/runtime/boss_flow_runner.gd"
func exercise() -> void:
	var f:=fixture({"a":{},"c":{"category":"combo"}},[{"request":"any","weights":{"single":100.0,"combo":0.0},"probability_rules":[{"previous":"single","weights":{"single":0.0,"combo":100.0}}],"next":0}])
	if f.is_empty():done("boss-select");return
	check(next_action(f)==["a"] and next_action(f)==["c"],"直前の分類に応じて次の分類の割合を切り替える")
	close(f)
	f=fixture({"a":{}},[{"request":"any","weights":{"single":1.0,"combo":99.0},"next":0}])
	if not f.is_empty():check(next_action(f)==["a"],"候補のない分類の割合を残る候補へ配る");close(f)
	var actions={"a":{"exclusive":false},"b":{"exclusive":false}}
	for mode in ["parallel","disabled","forbidden","exclusive"]:
		var section={"request":"any","cap":2.0,"weights":{"parallel":100.0},"next":0}
		if mode=="forbidden":section.forbidden=[["a","b"]]
		var candidates: Dictionary=actions.duplicate(true)
		if mode=="exclusive":candidates.b.exclusive=true
		f=fixture(candidates,[section],{"parallel":mode!="disabled"})
		if f.is_empty():continue
		advance(f,0.1)
		check(state(f).last.size()==(2 if mode=="parallel" else 0),"同時選択の許可・禁止ペア・排他を守る: "+mode)
		close(f)
	f=fixture(actions,[{"request":"any","weights":{"single":100.0},"avoid_repeat":true,"next":0}])
	if not f.is_empty():
		var first:=next_action(f)
		check(first.size()==1 and next_action(f)!=first,"別の候補があるときは直前の技を避ける")
		close(f)
	f=fixture({"a":{}},[{"request":"any","weights":{"single":100.0},"avoid_repeat":true,"next":0}])
	if not f.is_empty():
		check(next_action(f)==["a"] and next_action(f)==["a"],"唯一の候補を連発回避で失わない")
		close(f)
	f=fixture(actions,[{"request":"any","weights":{"single":100.0},"avoid_repeat":false,"next":0}],{"bias":{"a":20.0,"b":1.0}})
	if not f.is_empty():
		var count:=0
		for i in 200:
			if next_action(f)==["a"]:count+=1
		check(count>170 and count<200,"重みは別の候補を禁止せず選ばれやすさだけを変える")
		close(f)
	f=fixture({"b":{}},[{"request":"any","weights":{"single":100.0},"avoid_repeat":false,"next":0}],{"bias":{"a":20.0,"b":1.0}})
	if not f.is_empty():check(next_action(f)==["b"],"低い重みでも唯一の候補なら使える");close(f)
	done("boss-select")
