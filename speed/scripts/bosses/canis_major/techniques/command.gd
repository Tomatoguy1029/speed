## 通常入口を切り替えるまで使う互換Runner。
@tool
extends "res://scripts/data_types/boss_techniques/canis_major/command.gd"

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/canis_major/technique_runner.gd":
	var warned: Dictionary = {}

	func _begin_windup(host: CanisMajorBoss, r: Dictionary, length: float) -> void:
		super(host, r, length)
		var hounds = host._hounds()
		if hounds == null: return
		for i in host.led:
			if not host._alive_hound(i) or host.ring.has(i): continue
			warned[i] = host.table.id[i]
			hounds.mark(i, host.run_state.world_time + float(r.warn))

	func _clear_warning(host: CanisMajorBoss) -> void:
		var hounds = host._hounds()
		if hounds != null:
			for i: int in warned:
				if host.table.id[i] == warned[i]: hounds.warning_until.erase(i)
		warned.clear()

	func cancel(host: CanisMajorBoss) -> void:
		_clear_warning(host)
		super(host)

	func kind() -> StringName:
		return &"command"

	func execute(host: CanisMajorBoss) -> void:
		_clear_warning(host)
		var r := host.rule()
		var hounds = host._hounds()
		host._cue(&"command")
		if hounds == null: return
		host.lunging = PackedInt32Array(Array(host.led).filter(func(i): return not host.ring.has(i)))
		var until := host.run_state.world_time + float(r.lunge_time)
		for i in host.lunging:
			var speed_scale := float(r.lunge_speed) / maxf(host.table.speed[i], 1.0)
			var toward := (host.run_state.ship_pos - host.table.pos[i]).normalized()
			hounds.follow(i, host.table.pos[i] + toward * float(r.lunge_speed) * (float(r.lunge_time) + 0.2), until, speed_scale)
			# 加速を待たず、最初から全速で飛び出す。
			host.table.vel[i] = toward * float(r.lunge_speed)

	func _active_tick(host: CanisMajorBoss, _dt: float) -> void:
		var r := host.rule()
		# 号令：飛び出した猟犬に触れたら1回だけ当たる。
		if host.attack_hit: return
		for i in host.lunging:
			if not host._alive_hound(i): continue
			if host._ship_touches(host.table.pos[i], host.table.pos[i], host.table.r[i]):
				host._hit_ship(float(r.damage))
				return

	func body_pose(host: CanisMajorBoss) -> Dictionary:
		return {"shout": host.mode == &"windup"}
