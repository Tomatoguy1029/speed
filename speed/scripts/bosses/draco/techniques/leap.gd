## 飛びかかり噛みつきの値と動き。
@tool
extends BossTechnique

## 標的の先読み上限
@export_range(0,100000,0.01) var lead_cap := 900.0:
	set(value):
		lead_cap = value
		_values_dirty = true
## 予告（秒）
@export_range(0,100000,0.01) var warn := 0.8:
	set(value):
		warn = value
		_values_dirty = true
## 攻撃の継続時間
@export_range(0,100000,0.01) var active := 0.5:
	set(value):
		active = value
		_values_dirty = true
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 1.15:
	set(value):
		recover = value
		_values_dirty = true
## ダメージ
@export_range(0,100000,0.01) var damage := 35.0:
	set(value):
		damage = value
		_values_dirty = true
## 当たりの太さ（中心から片側）
@export_range(0,100000,0.01) var width := 96.0:
	set(value):
		width = value
		_values_dirty = true

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends BossTechnique.Runner:
	func kind() -> StringName: return &"leap"

	const MOTION = preload("res://scripts/bosses/draco_attack_motion.gd")
	const STAGING = preload("res://scripts/bosses/draco_screen_staging.gd")
	var staging: Dictionary
	var origin := Vector2.ZERO
	var destination := Vector2.ZERO
	var takeoff := Vector2.ZERO
	var landed := Vector2.ZERO
	var locked := false
	var positioned := false
	func begin(a: BossActor) -> void:
		var side := -1.0 if a.run_state.rng.randf() < 0.5 else 1.0
		staging=STAGING.begin(a,side,true,-0.3)
		locked=false
	func _lock(a: BossActor) -> void:
		a.aim=MOTION.predict(a,maxf(0.0,float(a.rule().warn)-a.elapsed)+float(a.rule().active),float(a.rule().get("lead_cap",900.0)))
		a.direction=(a.aim-origin).normalized()
		if a.direction.is_zero_approx():a.direction=Vector2.RIGHT
		takeoff=origin-a.direction*70.0
		destination=a.aim-a.direction*105.0*a.head_scale
		a.telegraph_points=PackedVector2Array([a.aim])
		MOTION.line_tell(a,takeoff+a.direction*105.0*a.head_scale,a.aim,float(a.rule().width))
	func windup(a: BossActor,_dt: float) -> void:
		if not STAGING.advance_full(a,staging,_dt): return
		if not positioned:
			origin=a.table.pos[a.body]
			positioned=true
			a.combat_trace.stage("telegraph")
		var setup_time := minf(0.2,float(a.rule().warn)*0.3)
		if not locked:
			_lock(a)
			locked=a.elapsed>=setup_time
			if locked: a.combat_trace.stage("lock")
		a.table.facing[a.body]=lerp_angle(a.table.facing[a.body],a.direction.angle(),clampf(_dt*9.0,0.0,1.0))
		if a.elapsed<setup_time:
			a.table.pos[a.body]=origin
		else:
			a.table.pos[a.body]=origin.lerp(takeoff,MOTION.smooth((a.elapsed-setup_time)/(float(a.rule().warn)-setup_time)))
	func tick(a: BossActor,_dt: float) -> void:
		MOTION.clear_tell(a)
		var before := MOTION.mouth(a)
		var f := MOTION.smooth(a.elapsed/float(a.rule().active))
		a.table.pos[a.body]=takeoff.lerp(destination,f)
		a.hit_segment(PackedVector2Array([before,MOTION.mouth(a)]),float(a.rule().width))
		a.attack_points=PackedVector2Array([before,MOTION.mouth(a)])
	func end(a: BossActor,_cancelled: bool) -> void:
		MOTION.clear_tell(a)
		a.attack_points.clear()
		landed=a.table.pos[a.body]
	func recover(a: BossActor,_dt: float) -> void:
		a.table.pos[a.body]=landed-a.direction*60.0*MOTION.smooth(a.elapsed/float(a.rule().recover))
