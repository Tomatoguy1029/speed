## 遠吠えの値と動き。
@tool
extends BossTechnique

## 囲みへ走る速さの倍率
@export_range(0,100000,0.01) var catch_up := 4.0:
	set(value):
		catch_up = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 15.0:
	set(value):
		cd = value
		_values_dirty = true
## 囲みを狭める時間（秒）
@export_range(0,100000,0.01) var close_time := 2.2:
	set(value):
		close_time = value
		_values_dirty = true
## 薄い所で抜く猟犬の数
@export_range(0,100000,1) var gap_slots := 2:
	set(value):
		gap_slots = value
		_values_dirty = true
## 薄い所の数
@export_range(0,100000,1) var gaps := 2:
	set(value):
		gaps = value
		_values_dirty = true
## 囲みに並ぶ時間（秒）
@export_range(0,100000,0.01) var gather_time := 1.0:
	set(value):
		gather_time = value
		_values_dirty = true
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 1.5:
	set(value):
		recover = value
		_values_dirty = true
## 囲みの終わりの半径
@export_range(0,100000,0.01) var ring_close := 220.0:
	set(value):
		ring_close = value
		_values_dirty = true
## 囲みの猟犬の数
@export_range(0,100000,1) var ring_count := 16:
	set(value):
		ring_count = value
		_values_dirty = true
## 囲みの始めの半径
@export_range(0,100000,0.01) var ring_radius := 800.0:
	set(value):
		ring_radius = value
		_values_dirty = true
## 呼んだ猟犬が出る輪の外の距離
@export_range(0,100000,0.01) var spawn_out := 350.0:
	set(value):
		spawn_out = value
		_values_dirty = true
## 呼び足す猟犬の上限
@export_range(0,100000,1) var summon_max := 10:
	set(value):
		summon_max = value
		_values_dirty = true
## 予告（秒）
@export_range(0,100000,0.01) var warn := 1.2:
	set(value):
		warn = value
		_values_dirty = true

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/canis_major/technique_runner.gd":
	func _form_ring(host: CanisMajorBoss, r: Dictionary) -> void:
		var hounds = host._hounds()
		var hound := host.ctx.enemies.def_of(&"hound")
		host._end_ring()
		host._cue(&"howl")
		host.ring_rule = r
		host.ring_center = host.run_state.ship_pos
		host.ring_started = host.clock
		var gaps := maxi(0, int(r.gaps))
		var gap_slots := maxi(0, int(r.gap_slots))
		var total := int(r.ring_count) + gaps * gap_slots
		if total <= 0: return
		var rng: RandomNumberGenerator = host.run_state.rng
		var offset := rng.randf() * TAU
		var empty := {}
		for g in gaps:
			var start := int(float(g) * total / gaps)
			for k in gap_slots: empty[(start + k) % total] = true
		var angles: Array[float] = []
		for slot in total:
			if not empty.has(slot): angles.append(offset + TAU * slot / total)
		var pool: Array = []
		if hounds != null:
			for i in host.led:
				if host._alive_hound(i) and not host.lunging.has(i): pool.append(i)
		var summoned := 0
		for angle in angles:
			var best := -1
			var best_gap := INF
			for i: int in pool:
				var gap := absf(Geom.angle_diff((host.table.pos[i] - host.ring_center).angle(), angle))
				if gap < best_gap:
					best_gap = gap
					best = i
			if best >= 0:
				pool.erase(best)
				host.ring[best] = [host.table.id[best], angle]
			elif hound != null and summoned < int(r.summon_max):
				var at := host.ring_center + Vector2.from_angle(angle) * (float(r.ring_radius) + float(r.spawn_out))
				var row := host.ctx.enemies.spawn(hound, at, {"hound_pack": -host.body_id, "facing": angle + PI})
				if row >= 0:
					host.ring[row] = [host.table.id[row], angle]
					summoned += 1

	## 猟犬を gather_time かけて半径 ring_radius の輪へ並べ、そこから close_time かけて ring_close まで狭める。
	## 狭め終えると囲みを解き、群れの猟犬は隊形へ、呼んだ猟犬は通常の追跡へ戻る。

	func _ring_tick(host: CanisMajorBoss) -> void:
		if host.ring_started < 0.0: return
		var r := host.ring_rule
		var hounds = host._hounds()
		if host.clock - host.ring_started >= float(r.gather_time) + float(r.close_time) or hounds == null:
			host._end_ring()
			return
		var radius := host.ring_radius()
		var until := host.run_state.world_time + host.FOLLOW_HOLD
		for i: int in host.ring.keys():
			var entry: Array = host.ring[i]
			if host.table.alive[i] == 0 or host.table.dead[i] != 0 or host.table.id[i] != entry[0]:
				host.ring.erase(i)
				continue
			hounds.follow(i, host.ring_center + Vector2.from_angle(float(entry[1])) * radius, until, float(r.catch_up))

	## 今の囲みの半径。囲んでいなければ -1。

	func ring_radius(host: CanisMajorBoss) -> float:
		if host.ring_started < 0.0: return -1.0
		var progress := clampf((host.clock - host.ring_started - float(host.ring_rule.gather_time)) / maxf(float(host.ring_rule.close_time), 0.001), 0.0, 1.0)
		return lerpf(float(host.ring_rule.ring_radius), float(host.ring_rule.ring_close), progress)

	func _end_ring(host: CanisMajorBoss) -> void:
		host.ring.clear()
		host.ring_started = -1.0

	## 撃破で群れを解き、猟犬を通常の群れの追跡へ戻す。

	func kind() -> StringName:
		return &"howl"

	func execute(host: CanisMajorBoss) -> void:
		host._form_ring(host.rule())

	func body_pose(host: CanisMajorBoss) -> Dictionary:
		return {"howl": host.mode == &"windup"}
