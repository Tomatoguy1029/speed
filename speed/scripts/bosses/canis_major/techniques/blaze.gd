## 通常入口を切り替えるまで使う互換Runner。
@tool
extends "res://scripts/data_types/boss_techniques/canis_major/blaze.gd"

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/canis_major/technique_runner.gd":
	var values: Dictionary
	var age := 0.0
	var chosen: Array = []
	func kind() -> StringName: return &"blaze"
	func _begin_windup(host: CanisMajorBoss, r: Dictionary, _length: float) -> void:
		manual = true
		values = r
		host.mode = &"windup"
		host.table.vel[host.body] = Vector2.ZERO
		var rows: Array = []
		for i in host.led:
			if host._alive_hound(i) and not host.ring.has(i) and not host.lunging.has(i): rows.append(i)
		rows.sort_custom(func(a,b): return host.table.pos[a].distance_squared_to(host.run_state.ship_pos) < host.table.pos[b].distance_squared_to(host.run_state.ship_pos))
		for k in mini(int(r.count), rows.size()):
			var i := int(rows[k])
			chosen.append({"row": i, "id": host.table.id[i], "at": float(r.ignite_at) + k * float(r.ignite_step), "sent": false, "lit": false})
		host._cue(&"blaze_windup")
	func manual_tick(host: CanisMajorBoss, dt: float) -> void:
		age += dt
		host.table.vel[host.body] = Vector2.ZERO
		if age < float(values.warn) and host._moves[kind()].track_during_warn: host._face(host.run_state.enemy_aim, host.def.turn, dt)
		for item in chosen:
			if not valid_hound(host, item.row, item.id): continue
			if not item.sent and age >= float(item.at) - float(values.ignite_step):
				item.sent = true
				host.sirius_effects.transfers.append({"from": host.mouth(), "row": item.row, "id": item.id, "age": 0.0, "life": values.ignite_step})
			if not item.lit and age >= float(item.at):
				item.lit = true
				host.sirius_effects.ignite(item.row, values)
		if age >= maxf(float(values.warn), float(values.ignite_at) + maxf(0, chosen.size()-1) * float(values.ignite_step)):
			finish(host, float(values.recover))
	func windup_progress(_host: CanisMajorBoss) -> float: return clampf(age / maxf(float(values.warn),0.001),0,1)
	func body_pose(host: CanisMajorBoss) -> Dictionary:
		return {"glow": windup_progress(host) if host.mode == &"windup" else 0.0}
