extends "res://tests/runtime/boss_flow_runner.gd"
func exercise() -> void:
	for cost in [3.0,4.0]:
		var f:=fixture({"a":{"cost":cost}},[{"request":"any","cap":4.0,"next":0}],{"stamina":4.0,"partial_rest":1.0,"empty_rest":3.0})
		if f.is_empty():continue
		check(next_action(f)==["a"] and is_equal_approx(state(f).stamina,4.0-cost),"選んだ行動のコストだけスタミナを減らす")
		check(until(f,func(s):return s.rest>0.0),"不足または枯渇で休息へ進む")
		check(state(f).rest<=(1.0 if cost==3.0 else 3.0) and state(f).rest>(0.9 if cost==3.0 else 2.9),"残量に合わせた部分休息/枯渇休息を使う")
		check(until(f,func(s):return s.rest==0.0) and state(f).stamina==4.0,"休息が終わるとスタミナを戻す")
		close(f)
	var f:=fixture({"a":{"gate":{"min":1000000.0}}},[{"request":"any","next":0}],{"stamina":4.0})
	if not f.is_empty():
		advance(f,0.5)
		check(state(f).waiting and state(f).rest==0.0 and state(f).stamina==4.0,"候補が成立しないことだけで休息を始めない")
		close(f)
	done("boss-stamina")
