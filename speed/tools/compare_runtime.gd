## 固定更新の入力列から、移行前後で照合する観測値を作る。
## 実験場の正規初期化を使い、描画と実時間の待ちを結果へ混ぜない。
extends RefCounted
const SESSION := preload("res://gyms/enemy_lab/lab_session.gd")
const FORMAT_VERSION := 1

func record(host: Node, settings: Dictionary, commands: Array, ticks: int) -> Dictionary:
	var lab = SESSION.new()
	host.add_child(lab)
	await lab.reset(settings)
	var frames: Array = [snapshot(lab.run, [], 0)]
	for tick in ticks:
		for command: Dictionary in commands:
			if int(command.tick) != tick:
				continue
			if command.kind == "hitstop":
				lab.run.state.hitstop_enabled = true
				lab.run.state.hitstop = float(command.args.seconds)
			else:
				lab.perform(String(command.kind), command.get("args", {}))
		var event_start: int = lab.events.size()
		lab.step()
		frames.append(snapshot(lab.run, lab.events.slice(event_start), tick + 1))
	lab.free()
	return {"version": FORMAT_VERSION, "dt": SESSION.DT, "frames": frames}

## 個体は格納行ではなくIDで照合する。完全な内部状態の保存とは別の観測値。
func snapshot(run: RunSimulation, events: Array, tick: int) -> Dictionary:
	var state := run.state
	var table := run.enemies.table
	var enemies: Array = []
	for row in table.alive.size():
		if table.alive[row] == 0:
			continue
		enemies.append({"id": table.id[row], "type": String(table.type[row]),
			"pos": vector(table.pos[row]), "vel": vector(table.vel[row]),
			"hp": table.hp[row], "armor": table.armor[row], "dead": table.dead[row],
			"facing": table.facing[row], "radius": table.r[row]})
	enemies.sort_custom(func(a, b): return a.id < b.id)
	return {"tick": tick, "time": state.time, "world_time": state.world_time,
		"phase": int(state.phase), "ship_pos": vector(state.ship_pos),
		"ship_vel": vector(state.ship_vel), "ship_hp": state.ship_hp,
		"kills": state.kills, "xp": state.xp, "xp_gained": state.xp_gained,
		"rng_state": str(state.rng.state), "enemies": enemies, "events": plain(events)}

func vector(value: Vector2) -> Array:
	return [value.x, value.y]

## JSON往復で失われる型を明示的に展開する。乱数の64bit値は上で文字列にする。
func plain(value: Variant) -> Variant:
	if value is Vector2:
		return vector(value)
	if value is Color:
		return [value.r, value.g, value.b, value.a]
	if value is StringName:
		return String(value)
	if value is Dictionary:
		var out := {}
		for key in value:
			out[String(key)] = plain(value[key])
		return out
	if value is Array or value is PackedVector2Array or value is PackedInt32Array or value is PackedFloat32Array:
		var out: Array = []
		for item in value:
			out.append(plain(item))
		return out
	return value

## 最初に食い違う値の場所を返す。数値誤差を一律に捨てない。
func difference(left: Variant, right: Variant, path := "result") -> String:
	if left is Dictionary and right is Dictionary:
		if left.size() != right.size():
			return path + ": 項目数が違う"
		for key in left:
			if not right.has(key):
				return path + "." + str(key) + ": 項目がない"
			var found := difference(left[key], right[key], path + "." + str(key))
			if not found.is_empty(): return found
		return ""
	if left is Array and right is Array:
		if left.size() != right.size(): return path + ": 要素数が違う"
		for i in left.size():
			var found := difference(left[i], right[i], path + "[%d]" % i)
			if not found.is_empty(): return found
		return ""
	return "" if left == right else path + ": %s != %s" % [str(left), str(right)]
