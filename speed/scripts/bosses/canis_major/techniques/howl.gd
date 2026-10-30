## 遠吠えの値と動き。
@tool
extends BossTechnique

## 囲みへ走る速さの倍率
@export_range(0,100000,0.01) var catch_up := 5.6:
	set(value):
		catch_up = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 15.0:
	set(value):
		cd = value
		_values_dirty = true
## 囲みを狭める時間（秒）
@export_range(0,100000,0.01) var close_time := 1.0:
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
@export_range(0,100000,0.01) var ring_close := 330.0:
	set(value):
		ring_close = value
		_values_dirty = true
## 囲みの猟犬の数
@export_range(0,100000,1) var ring_count := 16:
	set(value):
		ring_count = value
		_values_dirty = true
## 囲みの始めの半径
@export_range(0,100000,0.01) var ring_radius := 560.0:
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

## 輪の中心が自機を追う時間（秒）
@export_range(0,100000,0.01) var follow_time := 2.0:
	set(value):
		follow_time = value
		_values_dirty = true
## 輪の中心の追従率（毎秒）
@export_range(0,100000,0.01) var follow_rate := 4.0:
	set(value):
		follow_rate = value
		_values_dirty = true
## 輪から飛び出す間隔（秒）
@export_range(0,100000,0.01) var seq_interval := 0.12:
	set(value):
		seq_interval = value
		_values_dirty = true
## 猟犬1体の白い予告（秒）
@export_range(0,100000,0.01) var seq_warn := 0.3:
	set(value):
		seq_warn = value
		_values_dirty = true
## 猟犬の突進速度
@export_range(0,100000,0.01) var lunge_speed := 1260.0:
	set(value):
		lunge_speed = value
		_values_dirty = true
## 猟犬の突進時間（秒）
@export_range(0,100000,0.01) var lunge_time := 0.55:
	set(value):
		lunge_time = value
		_values_dirty = true
## 猟犬1体のダメージ
@export_range(0,100000,0.01) var damage := 12.0:
	set(value):
		damage = value
		_values_dirty = true
## 最後の発進から囲み終了まで（秒）
@export_range(0,100000,0.01) var tail := 0.8:
	set(value):
		tail = value
		_values_dirty = true

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/canis_major/technique_runner.gd":
	var started := 0.0
	var formed := false
	var ring_tick_at := 0.0

	func _begin_windup(host: CanisMajorBoss, _r: Dictionary, _length: float) -> void:
		manual = true
		started = host.clock
		host.mode = &"windup"
		host.table.vel[host.body] = Vector2.ZERO
		host._cue(&"telegraph")

	func manual_tick(host: CanisMajorBoss, dt: float) -> void:
		var r := host.rule()
		host.table.vel[host.body] = Vector2.ZERO
		if not formed:
			host._face(host.run_state.enemy_aim, host.def.turn, dt)
			if host.clock - started < float(r.warn): return
			formed = true
			host.mode = &"active"
			_form_ring(host, r)
			ring_tick_at = host.clock
			var rows: Array = host.ring.keys()
			rows.sort_custom(func(a, b): return float(host.ring[a][1]) < float(host.ring[b][1]))
			if host.run_state.rng.randi_range(0, 1) == 1: rows.reverse()
			if not rows.is_empty():
				var first := host.run_state.rng.randi_range(0, rows.size() - 1)
				rows = rows.slice(first) + rows.slice(0, first)
			begin_sequence(host, rows, host.clock + float(r.follow_time), float(r.seq_interval), float(r.seq_warn))
		tick_sequence(host, r, "howl")
		tick_lunges(host)
		if host.clock >= last_launch + float(r.tail):
			cancel(host)
			finish(host, float(r.recover))

	func cancel(host: CanisMajorBoss) -> void:
		super(host)
		_end_ring(host)

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
	## 輪の中心の追従が終わると順に突進し、戻る個体の指示を解除する。

	func _ring_tick(host: CanisMajorBoss) -> void:
		if host.ring_started < 0.0: return
		var r := host.ring_rule
		var hounds = host._hounds()
		if hounds == null:
			host._end_ring()
			return
		var follow_dt := maxf(0.0, minf(host.clock, host.ring_started + float(r.follow_time)) - ring_tick_at)
		ring_tick_at = host.clock
		host.ring_center += (host.run_state.ship_pos - host.ring_center) * (1.0 - exp(-float(r.follow_rate) * follow_dt))
		var radius := host.ring_radius()
		var until := host.run_state.world_time + host.FOLLOW_HOLD
		for i: int in host.ring.keys():
			var entry: Array = host.ring[i]
			if host.table.alive[i] == 0 or host.table.dead[i] != 0 or host.table.id[i] != entry[0]:
				host.ring.erase(i)
				continue
			hounds.quiet(i, until)
			hounds.follow(i, host.ring_center + Vector2.from_angle(float(entry[1])) * radius, until, float(r.catch_up))

	## 今の囲みの半径。囲んでいなければ -1。

	func ring_radius(host: CanisMajorBoss) -> float:
		if host.ring_started < 0.0: return -1.0
		var progress := clampf((host.clock - host.ring_started - float(host.ring_rule.gather_time)) / maxf(float(host.ring_rule.close_time), 0.001), 0.0, 1.0)
		return lerpf(float(host.ring_rule.ring_radius), float(host.ring_rule.ring_close), progress)

	func _end_ring(host: CanisMajorBoss) -> void:
		var hounds = host._hounds()
		for i: int in host.ring:
			if hounds != null and host.table.id[i] == host.ring[i][0]: hounds.release_order(i)
		host.ring.clear()
		host.ring_started = -1.0

	## 撃破で群れを解き、猟犬を通常の群れの追跡へ戻す。

	func kind() -> StringName:
		return &"howl"

	func execute(host: CanisMajorBoss) -> void:
		host._form_ring(host.rule())

	func windup_progress(host: CanisMajorBoss) -> float:
		return clampf((host.clock - started) / maxf(float(host.rule().warn), 0.001), 0, 1)

	func body_pose(host: CanisMajorBoss) -> Dictionary:
		return {"howl": host.mode == &"windup"}
