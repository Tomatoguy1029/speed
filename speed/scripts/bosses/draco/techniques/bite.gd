## 噛みつきの値と動き。
@tool
extends BossTechnique

## 標的の先読み上限
@export_range(0,100000,0.01) var lead_cap := 440.0:
	set(value):
		lead_cap = value
		_values_dirty = true
## 引き戻す時間
@export_range(0,100000,0.01) var retract := 110.0:
	set(value):
		retract = value
		_values_dirty = true
## 予告（秒）
@export_range(0,100000,0.01) var warn := 0.8:
	set(value):
		warn = value
		_values_dirty = true
## 攻撃の継続時間
@export_range(0,100000,0.01) var active := 0.3:
	set(value):
		active = value
		_values_dirty = true
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 0.8:
	set(value):
		recover = value
		_values_dirty = true
## ダメージ
@export_range(0,100000,0.01) var damage := 30.0:
	set(value):
		damage = value
		_values_dirty = true
## 到達距離
@export_range(0,100000,0.01) var reach := 360.0:
	set(value):
		reach = value
		_values_dirty = true
## 当たりの太さ（中心から片側）
@export_range(0,100000,0.01) var width := 96.0:
	set(value):
		width = value
		_values_dirty = true

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends BossTechnique.Runner:
	func kind() -> StringName: return &"bite"

	const MOTION = preload("res://scripts/bosses/draco_attack_motion.gd")
	var origin := Vector2.ZERO
	var retracted := Vector2.ZERO
	var strike := Vector2.ZERO
	var base := PackedVector2Array()
	var landed := PackedVector2Array()
	func begin(a: BossActor) -> void:
		origin=a.table.pos[a.body]
		a.aim=MOTION.predict(a,float(a.rule().warn)+float(a.rule().active)*0.55,float(a.rule().get("lead_cap",440.0)))
		a.direction=(a.aim-origin).normalized()
		if a.direction.is_zero_approx(): a.direction=Vector2.RIGHT
		a.table.facing[a.body]=a.direction.angle()
		base=a.neutral_body_points(origin,a.direction.angle())
		retracted=origin-a.direction*float(a.rule().get("retract",110.0))
		strike=origin+a.direction*float(a.rule().reach)
		MOTION.line_tell(a,origin,strike+a.direction*105.0*a.head_scale,float(a.rule().width))
	func windup(a: BossActor,_dt: float) -> void:
		MOTION.neck_pose(a,base,origin.lerp(retracted,MOTION.smooth(a.elapsed/float(a.rule().warn))))
	func tick(a: BossActor,_dt: float) -> void:
		MOTION.clear_tell(a)
		var before := MOTION.mouth(a)
		var progress := MOTION.smooth(a.elapsed/float(a.rule().active))
		MOTION.neck_pose(a,base,retracted.lerp(strike,progress))
		var after := MOTION.mouth(a)
		a.attack_points=PackedVector2Array([before,after])
		a.hit_segment(a.attack_points,float(a.rule().width))
	func end(a: BossActor,cancelled: bool) -> void:
		MOTION.clear_tell(a)
		a.attack_points.clear()
		landed=a.body_override.duplicate()
		if cancelled:
			a.table.pos[a.body]=origin
			a.reset_pose()
	func recover(a: BossActor,_dt: float) -> void:
		if landed.is_empty():return
		MOTION.blend(a,landed,a.neutral_body_points(origin,a.direction.angle()),a.elapsed/float(a.rule().recover))

	func pose(a: BossActor) -> void:
		a.mouth_open = 1.0 if a.mode == &"active" else 0.8 if a.mode == &"windup" else 0.0
