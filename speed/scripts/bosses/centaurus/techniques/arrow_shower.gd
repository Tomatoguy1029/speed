## ケンタウルス座の技の値と実行処理。
@tool
extends BossTechnique

## 円の置き方
@export_enum("chase", "wall", "path") var pattern := "chase":
	set(value):
		pattern = value
		_values_dirty = true
## 射上げの予告（秒）
@export_range(0, 100000, 0.01) var warn := 0.6:
	set(value):
		warn = value
		_values_dirty = true
## 円が現れてから降り始めるまで（秒）
@export_range(0, 100000, 0.01) var mark_time := 0.8:
	set(value):
		mark_time = value
		_values_dirty = true
## 着弾後、硬直へ移るまでの余韻（秒）。当たりは着弾時だけ
@export_range(0, 100000, 0.01) var rain_time := 0.15:
	set(value):
		rain_time = value
		_values_dirty = true
## 着弾した矢を表示だけ残す時間（秒）
@export_range(0, 100000, 0.01) var linger := 0.6:
	set(value):
		linger = value
		_values_dirty = true
## 円の半径（距離）
@export_range(0, 100000, 0.01) var radius := 44.0:
	set(value):
		radius = value
		_values_dirty = true
## 円の数
@export_range(0, 100000, 1) var count := 10:
	set(value):
		count = value
		_values_dirty = true
## 円の数（第2形態）
@export_range(0, 100000, 1) var count_p2 := 13:
	set(value):
		count_p2 = value
		_values_dirty = true
## 追いかける円を置く間隔（秒）
@export_range(0, 100000, 0.01) var interval := 0.22:
	set(value):
		interval = value
		_values_dirty = true
## 自機の進む先を予測する時間（秒）
@export_range(0, 100000, 0.01) var lead := 0.5:
	set(value):
		lead = value
		_values_dirty = true
## 壁の円どうしの間隔（距離）
@export_range(0, 100000, 0.01) var spacing := 72.0:
	set(value):
		spacing = value
		_values_dirty = true
## 隣の円が現れる時間差（秒）。wallは中心から外、pathは端から順
@export_range(0, 100000, 0.01) var step := 0.1:
	set(value):
		step = value
		_values_dirty = true
## 本体と自機の距離に対する壁の位置の割合
@export_range(0, 100000, 0.01) var wall_ratio := 0.45:
	set(value):
		wall_ratio = value
		_values_dirty = true
## 本体から壁までの最小距離
@export_range(0, 100000, 0.01) var wall_min := 140.0:
	set(value):
		wall_min = value
		_values_dirty = true
## 本体から壁までの最大距離
@export_range(0, 100000, 0.01) var wall_max := 400.0:
	set(value):
		wall_max = value
		_values_dirty = true
## 進む先を塞ぐ位置までの距離
@export_range(0, 100000, 0.01) var ahead := 260.0:
	set(value):
		ahead = value
		_values_dirty = true
## 円のダメージ
@export_range(0, 100000, 0.01) var damage := 14.0:
	set(value):
		damage = value
		_values_dirty = true
## 攻撃後の硬直（秒）
@export_range(0, 100000, 0.01) var recover := 0.8:
	set(value):
		recover = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0, 100000, 0.01) var cd := 5.0:
	set(value):
		cd = value
		_values_dirty = true

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/centaurus/technique_runner.gd":
	var started_at := 0.0
	var marks: Array[Dictionary] = []
	var placed := 0
	var launched := false

	func kind() -> StringName: return &"arrow_shower"

	func _begin_windup(host: CentaurusBoss, _r: Dictionary, _length: float) -> void:
		host.timeline.stop()
		started_at = host.clock
		host.mode = &"windup"
		host._cue(&"telegraph")

	func tick(actor: BossActor, dt: float) -> void:
		var host := actor as CentaurusBoss
		var r := host.rule()
		var elapsed := host.clock - started_at
		host.table.vel[host.body] = Vector2.ZERO
		host._face(host.run_state.ship_pos if host.mode == &"windup" else host.run_state.enemy_aim, host.def.turn, dt)
		if elapsed < float(r.warn): return
		var base := started_at + float(r.warn)
		if not launched:
			launched = true
			host.mode = &"rain"
			host._cue(&"shower_launched")
			if r.pattern == "path":
				var direction := host.run_state.ship_vel.normalized() if host.run_state.ship_vel.length() >= 1.0 else host.run_state.ship_heading
				var center := host.run_state.ship_pos + direction * float(r.ahead)
				for j in int(r.count):
					var offset := (j - (int(r.count) - 1) * 0.5) * host.path_side
					_add_mark(center + direction.orthogonal() * offset * float(r.spacing), base + j * float(r.step))
				host.path_side *= -1.0
			if r.pattern == "wall":
				var at := host.table.pos[host.body]
				var toward := host.run_state.ship_pos - at
				var direction := toward.normalized() if toward.length_squared() > 0.0 else Vector2.from_angle(host.table.facing[host.body])
				var center := at + direction * clampf(toward.length() * float(r.wall_ratio), float(r.wall_min), float(r.wall_max))
				for j in int(r.count):
					var offset := j - (int(r.count) - 1) * 0.5
					_add_mark(center + direction.orthogonal() * offset * float(r.spacing), base + absf(offset) * float(r.step))
		if r.pattern == "chase":
			while placed < int(r.count) and host.clock >= base + placed * float(r.interval):
				_add_mark(host.run_state.ship_pos + host.run_state.ship_vel * float(r.lead), base + placed * float(r.interval))
				placed += 1
		var finished: bool = r.pattern != "chase" or placed >= int(r.count)
		for mark in marks:
			var age := host.clock - float(mark.at)
			if age < 0.0:
				finished = false
				continue
			if not mark.shown:
				mark.shown = true
				host._cue(&"shower_mark", mark.center)
			if age < float(r.mark_time) + float(r.rain_time): finished = false
			if age < float(r.mark_time): continue
			if mark.landed: continue
			mark.landed = true
			host._cue(&"shower_landed", mark.center)
			var reach := float(r.radius) + host.ctx.cfg.ship_radius
			if host.run_state.ship_pos.distance_squared_to(mark.center) <= reach * reach:
				host.ctx.ship.damage(float(r.damage) * host.ctx.cfg.atk_scale, 0.0, &"arrow", &"centaurus")

		if finished:
			marks.clear()
			host.finish_technique()

	func _add_mark(center: Vector2, at: float) -> void:
		marks.append({"center": center, "at": at, "shown": false, "landed": false})
