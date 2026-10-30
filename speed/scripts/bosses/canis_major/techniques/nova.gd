## シリウスの閃光の公開値と動作。
@tool
extends BossTechnique

## 使う猟犬の数
@export_range(0,100000,1) var count := 6:
	set(value):
		count = value
		_values_dirty = true
## 必要な猟犬の数
@export_range(0,100000,1) var min_hounds := 6:
	set(value):
		min_hounds = value
		_values_dirty = true
## 口元から組までの距離
@export_range(0,100000,0.01) var pair_dist := 95.0:
	set(value):
		pair_dist = value
		_values_dirty = true
## 組の中心から左右への距離
@export_range(0,100000,0.01) var pair_side := 14.0:
	set(value):
		pair_side = value
		_values_dirty = true
## 組の持ち場へ向かう最高速
@export_range(0,100000,0.01) var gather_speed := 420.0:
	set(value):
		gather_speed = value
		_values_dirty = true
## 影を作る猟犬の体の半径
@export_range(0,100000,0.01) var body_radius := 12.0:
	set(value):
		body_radius = value
		_values_dirty = true
## 予告（秒）
@export_range(0,100000,0.01) var warn := 1.4:
	set(value):
		warn = value
		_values_dirty = true
## 光の輪の数
@export_range(0,100000,1) var rings := 2:
	set(value):
		rings = value
		_values_dirty = true
## 輪を出す間隔（秒）
@export_range(0,100000,0.01) var ring_gap := 0.35:
	set(value):
		ring_gap = value
		_values_dirty = true
## 輪が広がる速さ
@export_range(0,100000,0.01) var ring_speed := 560.0:
	set(value):
		ring_speed = value
		_values_dirty = true
## 輪の判定の半幅
@export_range(0,100000,0.01) var ring_band := 8.0:
	set(value):
		ring_band = value
		_values_dirty = true
## 輪が消える半径
@export_range(0,100000,0.01) var ring_end := 1400.0:
	set(value):
		ring_end = value
		_values_dirty = true
## ダメージ
@export_range(0,100000,0.01) var damage := 22.0:
	set(value):
		damage = value
		_values_dirty = true
## 光った後に猟犬を戻すまで（秒）
@export_range(0,100000,0.01) var after := 2.4:
	set(value):
		after = value
		_values_dirty = true
## 硬直（秒）
@export_range(0,100000,0.01) var recover := 1.6:
	set(value):
		recover = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 16.0:
	set(value):
		cd = value
		_values_dirty = true

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/canis_major/technique_runner.gd":
	var values: Dictionary
	var started := 0.0
	var pairs: Array = []
	var shadows: Array = []
	var ring_hit: Array = []
	var flashed := false
	var released := false
	func kind() -> StringName: return &"nova"
	func _begin_windup(host: CanisMajorBoss, r: Dictionary, _length: float) -> void:
		manual = true
		values = r
		started = host.clock
		host.mode = &"windup"
		host.table.vel[host.body] = Vector2.ZERO
		var rows := shuffled_pack(host).filter(func(i): return not host.lunging.has(i))
		rows = rows.slice(0,int(r.count))
		var base := (host.run_state.ship_pos-host.table.pos[host.body]).angle() + deg_to_rad(60.0 + host.run_state.rng.randf_range(-17.0,17.0))
		for k in rows.size():
			var i := int(rows[k])
			pairs.append({"row": i, "id": host.table.id[i], "group": k/2, "angle": base + (k/2) * TAU/3.0, "side": 1.0 if k%2==0 else -1.0})
			host.lunging.append(i)
		for k in int(r.rings): ring_hit.append(false)
		host.sirius_effects.nova = self
		host._cue(&"nova_windup")
	func manual_tick(host: CanisMajorBoss, dt: float) -> void:
		host.table.vel[host.body] = Vector2.ZERO
		var age := host.clock-started
		if age < float(values.warn) and host._moves[kind()].track_during_warn: host._face(host.run_state.enemy_aim,host.def.turn,dt)
		if age >= float(values.warn)+float(values.after):
			release_pairs(host)
			finish(host,float(values.recover))
	func update_effect(host: CanisMajorBoss) -> void:
		var age := host.clock-started
		var cfg: Dictionary = host._rules[&"bay"].duplicate()
		cfg.max_speed = values.gather_speed
		for member in pairs:
			var i := int(member.row)
			if not valid_hound(host,i,member.id): continue
			if not released:
				var u := Vector2.from_angle(float(member.angle))
				var goal := host.mouth() + u*float(values.pair_dist) + u.orthogonal()*float(values.pair_side)*float(member.side)
				host._hounds().steer_follow(i,goal,host.mouth()+u*1000.0,host.run_state.world_time+host.FOLLOW_HOLD,cfg)
				host.sirius_effects.tint_hound(i,host.run_state.world_time+host.FOLLOW_HOLD,host.SIRIUS_COLOR)
		update_shadows(host)
		if age < float(values.warn): return
		if not flashed:
			flashed = true
			host.mode = &"active"
			host._cue(&"nova_flash")
		for k in ring_hit.size():
			var elapsed := age-float(values.warn)-k*float(values.ring_gap)
			if elapsed < 0.0: continue
			var radius := 30.0+float(values.ring_speed)*elapsed
			if radius > float(values.ring_end) or ring_hit[k]: continue
			var distance := host.run_state.ship_pos.distance_to(host.mouth())
			if absf(distance-radius) <= float(values.ring_band)+host.ctx.cfg.ship_radius and not in_shadow(host,host.run_state.ship_pos,host.ctx.cfg.ship_radius):
				ring_hit[k] = true
				host.ctx.ship.damage(float(values.damage)*host.ctx.cfg.atk_scale,0.0,&"nova",&"canis_major")
	func update_shadows(host: CanisMajorBoss) -> void:
		shadows.clear()
		var source := host.mouth()
		for group in 3:
			var members := pairs.filter(func(m): return int(m.group)==group and valid_hound(host,m.row,m.id))
			if members.is_empty(): continue
			var reference := (host.table.pos[members[0].row]-source).angle()
			var lo := INF
			var hi := -INF
			var near := INF
			for member in members:
				var to := host.table.pos[member.row]-source
				var d := to.length()
				var radius := float(values.body_radius)
				var half := asin(minf(1.0,radius/maxf(radius+1.0,d)))
				var angle := Geom.angle_diff(to.angle(),reference)
				lo = minf(lo,angle-half)
				hi = maxf(hi,angle+half)
				near = minf(near,d)
			shadows.append({"angle": reference+(lo+hi)*0.5,"half": (hi-lo)*0.5,"near": near})
	func in_shadow(host: CanisMajorBoss, point: Vector2, radius: float) -> bool:
		var to := point-host.mouth()
		var d := to.length()
		var margin := asin(minf(1.0,radius/maxf(d,0.001)))
		for shadow in shadows:
			if d > float(shadow.near) and absf(Geom.angle_diff(to.angle(),float(shadow.angle))) <= float(shadow.half)-margin: return true
		return false
	func release_pairs(host: CanisMajorBoss) -> void:
		if released: return
		released = true
		for member in pairs:
			if valid_hound(host,member.row,member.id): host._hounds().release_order(member.row)
			host.lunging.erase(member.row)
	func cancel(host: CanisMajorBoss) -> void:
		release_pairs(host)
		if host.sirius_effects.nova == self: host.sirius_effects.nova = null
	func finished(host: CanisMajorBoss) -> bool:
		return host.clock-started > float(values.warn) + maxf(0,int(values.rings)-1)*float(values.ring_gap) + (float(values.ring_end)-30.0)/maxf(float(values.ring_speed),0.001)
	func windup_progress(host: CanisMajorBoss) -> float: return clampf((host.clock-started)/maxf(float(values.warn),0.001),0,1)
	func body_pose(host: CanisMajorBoss) -> Dictionary:
		var age := host.clock-started
		var glow := windup_progress(host) if age < float(values.warn) else maxf(0.0,1.0-(age-float(values.warn))/maxf(float(values.after),0.001))
		return {"glow": glow}
