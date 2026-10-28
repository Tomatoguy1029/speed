## 星弾の扇の値と動き。
@tool
extends BossTechnique

## 標的の先読み上限
@export_range(0,100000,0.01) var lead_cap := 1200.0
## 予告（秒）
@export_range(0,100000,0.01) var warn := 0.9
## 攻撃の継続時間
@export_range(0,100000,0.01) var active := 0.15
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 0.8
## ダメージ
@export_range(0,100000,0.01) var damage := 18.0
## 当たりの太さ（中心から片側）
@export_range(0,100000,0.01) var width := 9.0
## 弾数
@export_range(0,100000,1) var count := 9
## 薙ぐ角度（度）
@export_range(0,360,0.1,"radians_as_degrees") var arc := 1.134464
## 半径
@export_range(0,100000,0.01) var radius := 260.0
## 矢の速さ
@export_range(0,100000,0.01) var speed := 800.0

## 撃つ弾の見た目
@export var shot_visual: PackedScene = preload("res://scenes/attacks/star_bolt.tscn")

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends BossTechnique.Runner:
	const MOTION = preload("res://scripts/bosses/draco_attack_motion.gd")
	const STAR = preload("res://scripts/attacks/star_bolt.gd")
	const STAR_VISUAL = preload("res://scripts/render/attacks/star_bolt.gd")
	var positions := PackedVector2Array()
	var angles: Array[float] = []
	var fired := false
	var locked := false
	func _arrange(a: BossActor) -> void:
		var p: Dictionary=a.rule()
		var wait := maxf(0.0,float(p.warn)-a.elapsed)
		var predicted: Vector2=a.run_state.ship_pos
		for iteration in 8:
			var travel := maxf(0.0,a.table.pos[a.body].distance_to(predicted)-float(p.radius))/float(p.speed)
			predicted=MOTION.predict(a,wait+travel,float(p.get("lead_cap",1200.0)))
		a.aim=predicted
		a.direction=(a.aim-a.table.pos[a.body]).normalized()
		if a.direction.is_zero_approx():a.direction=Vector2.RIGHT
		a.table.facing[a.body]=a.direction.angle()
		positions.clear();angles.clear();a.telegraph_paths.clear();a.telegraph_widths.clear()
		for j in int(p.count):
			var angle: float = a.direction.angle()+lerpf(-float(p.arc),float(p.arc),float(j)/maxf(1.0,float(p.count)-1.0))
			var at: Vector2=a.table.pos[a.body]+Vector2.from_angle(angle)*float(p.radius)
			angles.append(angle);positions.append(at)
			a.telegraph_paths.append(PackedVector2Array([at,at+Vector2.from_angle(angle)*180.0]))
			a.telegraph_widths.append(float(p.width))
		a.telegraph_points=positions
	func begin(a: BossActor) -> void:
		_arrange(a)
	func windup(a: BossActor,_dt: float) -> void:
		if not locked:
			_arrange(a)
			locked=a.elapsed>=minf(0.25,float(a.rule().warn)*0.35)
			if locked: a.combat_trace.stage("lock")
	func tick(a: BossActor,_dt: float) -> void:
		if fired:return
		fired=true
		for j in positions.size():
			a.ctx.projectiles.emit_attack(&"star_bolt",[positions[j],angles[j],float(a.rule().speed),float(a.rule().damage)*a.ctx.cfg.atk_scale], a.rule().get("shot_visual"))
		MOTION.clear_tell(a)
	func end(a: BossActor,_cancelled: bool) -> void:
		MOTION.clear_tell(a)

	func pose(a: BossActor) -> void:
		a.mouth_open = (1.35 if a.technique == &"inhale" else 1.0) if a.mode == &"active" else 0.8 if a.mode == &"windup" else 0.0
