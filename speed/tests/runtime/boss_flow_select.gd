extends "res://tests/runtime/boss_flow_runner.gd"
func diagnostic_selection() -> void:
	var sequences: Array=[]
	for level in [0,1,2]:
		var f:=fixture({"a":{},"b":{},"far":{"gate":{"min":10000.0}},"costly":{"cost":4.0}},[{"request":"any","cap":2.0,"avoid_repeat":true,"weights":{"single":100.0},"next":0}])
		if f.is_empty():continue
		var events: Array=[]
		f.bridge.subscribe("候補診断",func(packet):events.append_array(packet.events);return true)
		check(f.bridge.command("set_recording",{"active":true,"level":level}).ok,"候補診断の詳細度を設定する")
		var sequence: Array=[]
		for i in 4:sequence.append(next_action(f))
		sequences.append(sequence)
		var decisions: Array=events.filter(func(e):return e.type=="boss_decision")
		check(decisions.is_empty() if level<2 else decisions.size()==4,"候補理由は詳細度2の録画だけへ送る")
		if level==2 and not decisions.is_empty():
			var first: Dictionary=decisions[0].payload
			check(first.selected==sequence[0] and first.history.is_empty() and first.cap==2.0 and first.section_spent==0.0,"選択と選択前の区間消費を保持する")
			check(first.candidates.any(func(a):return a.id=="far" and not a.eligible and "distance_below_min" in a.reasons),"距離条件の不成立理由を保持する")
			check(first.candidates.any(func(a):return a.id=="costly" and not a.eligible and "section_cap" in a.reasons),"区間の消費上限を候補理由として保持する")
			check(first.selection.has("category_draw") and first.selection.has("groups_after_repeat") and first.selection.has("variant_draw"),"実際の抽選値と反復回避後の候補を保持する")
		close(f)
	check(sequences.size()==3 and sequences[0]==sequences[1] and sequences[1]==sequences[2],"診断の詳細度で同じseedの選択結果を変えない")

func exercise() -> void:
	diagnostic_selection()
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
	f=fixture({"a":{"gate":{"min":10000.0}},"b":{}},[{"request":"any","weights":{"single":100.0},"avoid_repeat":false,"next":0}],{"bias":{"a":20.0,"b":1.0}})
	if not f.is_empty():check(next_action(f)==["b"],"低い重みでも唯一の候補なら使える");close(f)
	done("boss-select")
