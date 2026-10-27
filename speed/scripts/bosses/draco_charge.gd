## 頭の星を集め、画面外の入口から固定した進路を貫く。歯先の掃引が予告と一致する。
extends RefCounted
const MOTION = preload("res://scripts/bosses/draco_attack_motion.gd")
const STAGING = preload("res://scripts/bosses/draco_screen_staging.gd")
var staging: Dictionary
var origin := Vector2.ZERO
var destination := Vector2.ZERO
var positioned := false
var locked := false
var settled := Vector2.ZERO
func begin(a: BossActor) -> void:
	var side := -1.0 if a.run_state.rng.randf() < 0.5 else 1.0
	staging=STAGING.begin(a,side,false)
	locked=false
func _lock(a: BossActor) -> void:
	var remaining := maxf(0.0,float(a.rule().warn)-a.elapsed)
	var predicted: Vector2=a.run_state.ship_pos
	var offset: float=105.0*a.head_scale
	var overshoot: float=float(a.rule().get("overshoot",260.0))
	for iteration in 3:
		var distance := origin.distance_to(predicted)
		var fraction := clampf((distance-offset)/maxf(1.0,distance+overshoot),0.0,1.0)
		predicted=MOTION.predict(a,remaining+float(a.rule().active)*fraction,float(a.rule().get("lead_cap",900.0)))
	a.aim=predicted
	a.direction=(a.aim-origin).normalized()
	if a.direction.is_zero_approx():a.direction=Vector2.RIGHT
	a.table.facing[a.body]=a.direction.angle()
	destination=a.aim+a.direction*float(a.rule().get("overshoot",260.0))
	MOTION.line_tell(a,origin+a.direction*105.0*a.head_scale,destination+a.direction*105.0*a.head_scale,float(a.rule().width))
func windup(a: BossActor,_dt: float) -> void:
	if not STAGING.advance_full(a,staging,_dt): return
	if not positioned:
		origin = a.table.pos[a.body]
		positioned = true
		_lock(a)
		a.combat_trace.stage("telegraph")
	var setup_time := minf(0.2,float(a.rule().warn)*0.3)
	if not locked:
		_lock(a)
		locked=a.elapsed>=setup_time
		if locked: a.combat_trace.stage("lock")
func tick(a: BossActor,_dt: float) -> void:
	MOTION.clear_tell(a)
	var before := MOTION.mouth(a)
	var f := clampf(a.elapsed/float(a.rule().active),0.0,1.0)
	a.table.pos[a.body]=origin.lerp(destination,f)
	var after := MOTION.mouth(a)
	a.hit_segment(PackedVector2Array([before,after]),float(a.rule().width))
	a.attack_points=PackedVector2Array([before,after])
func end(a: BossActor,_cancelled: bool) -> void:
	MOTION.clear_tell(a)
	a.attack_points.clear()
	settled=a.table.pos[a.body]
func recover(a: BossActor,_dt: float) -> void:
	# 減速の余韻だけを残し、別の位置へ瞬間移動して戻さない。
	a.table.pos[a.body]=settled+a.direction*45.0*MOTION.smooth(a.elapsed/float(a.rule().recover))
