## 隕石投射を予兆として使い、実際に向いている口から遮蔽済みの炎を掃く。
extends RefCounted
const MOTION = preload("res://scripts/bosses/draco_attack_motion.gd")
const OCCLUSION = preload("res://scripts/common/beam_occlusion.gd")
const METEOR = preload("res://data/enemies/meteor.tres")
var rocks: Array = []
var destinations := PackedVector2Array()
var mouth := Vector2.ZERO
var rays := PackedFloat32Array()
var fan_angle := 0.0
var reused := false
var axis := 0.0
var base := PackedVector2Array()
var recovering := PackedVector2Array()
func begin(a: BossActor) -> void:
	a.aim=a.aim_target()
	a.direction=(a.aim-a.table.pos[a.body]).normalized()
	if a.direction.is_zero_approx():a.direction=Vector2.RIGHT
	axis=a.direction.angle()
	a.table.facing[a.body]=axis
	base=a.neutral_body_points(a.table.pos[a.body],axis)
	mouth=MOTION.mouth(a)
	for rock: FieldSystem.Rock in a.placed_meteors:
		if a.ctx.enemies.is_same(rock.row,rock.row_id) and a.table.dead[rock.row]==0:rocks.append(rock)
	a.placed_meteors.clear()
	if not rocks.is_empty():
		reused=true
		return
	for j in int(a.rule().rocks):
		var rock := FieldSystem.Rock.new()
		rock.kind=&"belt";rock.lab_manual=true;rock.pos=mouth
		rock.size=float(a.rule().rock_radius)
		var definition: EnemyDef=METEOR.duplicate(true)
		definition.hp=float(a.rule().rock_hp)
		definition.stage_hp=definition.hp
		definition.radius=rock.size;definition.speed=0.0;definition.xp=0.0
		var index: int=a.ctx.field.rocks.size()
		a.ctx.field.rocks.append(rock)
		rock.row=a.ctx.enemies.spawn(definition,mouth,{"meteor_index":index})
		rock.row_id=a.table.id[rock.row]
		rocks.append(rock)
		var side := float(j)-float(int(a.rule().rocks)-1)*0.5
		destinations.append(mouth+a.direction*float(a.rule().rock_distance)+a.direction.orthogonal()*side*float(a.rule().rock_spacing))
func windup(a: BossActor,_dt: float) -> void:
	var progress := MOTION.smooth(a.elapsed/float(a.rule().warn))
	if not reused:
		for j in rocks.size():
			var rock: FieldSystem.Rock=rocks[j]
			if a.ctx.enemies.is_same(rock.row,rock.row_id) and a.table.dead[rock.row]==0:
				rock.pos=mouth.lerp(destinations[j],progress)
				a.table.pos[rock.row]=rock.pos
	if a.technique==&"meteor":return
	var fan := PackedVector2Array()
	var head: Vector2=a.table.pos[a.body]
	for j in 25:
		var angle := axis+lerpf(-float(a.rule().sweep)-float(a.rule().half_angle),float(a.rule().sweep)+float(a.rule().half_angle),j/24.0)
		fan.append(head+Vector2.from_angle(angle)*(float(a.rule().reach)+105.0*a.head_scale))
	a.telegraph_paths.assign([fan,PackedVector2Array([head,fan[0]]),PackedVector2Array([head,fan[-1]])])
	a.telegraph_widths.assign([4.0,4.0,4.0])
func tick(a: BossActor,_dt: float) -> void:
	MOTION.clear_tell(a)
	fan_angle=axis+lerpf(-float(a.rule().sweep),float(a.rule().sweep),clampf(a.elapsed/float(a.rule().active),0.0,1.0))
	a.table.facing[a.body]=fan_angle
	a.body_override=a.neutral_body_points(a.table.pos[a.body],axis)
	mouth=MOTION.mouth(a)
	var blockers := PackedVector3Array()
	for i in a.table.alive.size():
		if a.table.alive[i]!=0 and a.table.dead[i]==0 and a.table.meteor_index[i]>=0:
			var offset: Vector2=a.table.pos[i]-mouth
			blockers.append(Vector3(offset.x,offset.y,a.table.r[i]))
	for body: FieldSystem.Body in a.ctx.field.bodies:
		var offset := body.pos-mouth
		blockers.append(Vector3(offset.x,offset.y,body.r))
	rays.clear()
	var polygon := PackedVector2Array([mouth])
	for j in 65:
		var direction := Vector2.from_angle(fan_angle-float(a.rule().half_angle)+2.0*float(a.rule().half_angle)*j/64.0)
		var reach := OCCLUSION.reach(direction,float(a.rule().reach),blockers)
		rays.append(reach)
		polygon.append(mouth+direction*reach)
	a.attack_points=polygon
	a.combat_trace.evaluate()
	# 点列の隣接扇形そのものを使う。遮蔽の見えている境界を判定も越えない。
	for j in range(1,polygon.size()-1):
		if Geometry2D.is_point_in_polygon(a.run_state.ship_pos,PackedVector2Array([mouth,polygon[j],polygon[j+1]])):
			a.combat_trace.damage(float(a.rule().damage)*a.ctx.cfg.atk_scale,0.0,&"breath",&"draco")
			break
func end(a: BossActor,cancelled: bool) -> void:
	for rock: FieldSystem.Rock in rocks:
		rock.destroyed=true
		if a.ctx.enemies.is_same(rock.row,rock.row_id) and a.table.dead[rock.row]==0:
			a.ctx.enemies.mark_dead(rock.row)
			a.presentation_event.emit({"cue":&"rock_break","pos":rock.pos,"radius":rock.size})
	MOTION.clear_tell(a)
	a.attack_points.clear()
	recovering=a.body_override.duplicate()
	if cancelled:a.reset_pose()
func recover(a: BossActor,_dt: float) -> void:
	var progress := MOTION.smooth(a.elapsed/float(a.rule().recover))
	a.table.facing[a.body]=lerp_angle(axis+float(a.rule().sweep),axis,progress)
	if not recovering.is_empty():MOTION.blend(a,recovering,a.neutral_body_points(a.table.pos[a.body],axis),progress)
