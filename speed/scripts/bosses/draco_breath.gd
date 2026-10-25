extends RefCounted
const OCCLUSION = preload("res://scripts/common/beam_occlusion.gd")
const METEOR = preload("res://data/enemies/meteor.tres")
var rocks: Array = []
var destinations := PackedVector2Array()
var mouth := Vector2.ZERO
var rays := PackedFloat32Array()
var fan_angle := 0.0
var reused := false
func begin(a: BossActor) -> void:
	mouth = a.table.pos[a.body] + a.direction*100.0
	for rock: FieldSystem.Rock in a.placed_meteors:
		if a.ctx.enemies.is_same(rock.row,rock.row_id) and a.table.dead[rock.row] == 0: rocks.append(rock)
	a.placed_meteors.clear()
	if not rocks.is_empty():
		reused = true
		return
	for j in int(a.rule().rocks):
		var rock := FieldSystem.Rock.new()
		rock.kind = &"belt"
		rock.lab_manual = true
		rock.pos = mouth
		rock.size = float(a.rule().rock_radius)
		var definition: EnemyDef = METEOR.duplicate(true)
		definition.hp = float(a.rule().rock_hp)
		definition.radius = rock.size
		definition.speed = 0.0
		definition.xp = 0.0
		var index := a.ctx.field.rocks.size()
		a.ctx.field.rocks.append(rock)
		rock.row = a.ctx.enemies.spawn(definition,mouth,{"meteor_index":index})
		rock.row_id = a.table.id[rock.row]
		rocks.append(rock)
		var side := float(j)-float(int(a.rule().rocks)-1)*0.5
		destinations.append(mouth+a.direction*float(a.rule().rock_distance)+a.direction.orthogonal()*side*float(a.rule().rock_spacing))
func windup(a: BossActor, _dt: float) -> void:
	if reused: return
	var progress := clampf(a.elapsed/float(a.rule().warn),0.0,1.0)
	for j in rocks.size():
		var rock: FieldSystem.Rock = rocks[j]
		if a.ctx.enemies.is_same(rock.row,rock.row_id) and a.table.dead[rock.row] == 0:
			rock.pos = mouth.lerp(destinations[j],progress)
			a.table.pos[rock.row] = rock.pos
func tick(a: BossActor, _dt: float) -> void:
	var blockers := PackedVector3Array()
	for i in a.table.alive.size():
		if a.table.alive[i] != 0 and a.table.dead[i] == 0 and a.table.meteor_index[i] >= 0:
			var offset: Vector2 = a.table.pos[i]-mouth
			blockers.append(Vector3(offset.x,offset.y,a.table.r[i]))
	for body: FieldSystem.Body in a.ctx.field.bodies:
		var offset := body.pos-mouth
		blockers.append(Vector3(offset.x,offset.y,body.r))
	fan_angle = a.direction.angle()+lerpf(-float(a.rule().sweep),float(a.rule().sweep),clampf(a.elapsed/float(a.rule().active),0.0,1.0))
	rays.clear()
	var polygon := PackedVector2Array([mouth])
	for j in 49:
		var direction := Vector2.from_angle(fan_angle-float(a.rule().half_angle)+2.0*float(a.rule().half_angle)*j/48.0)
		var reach := OCCLUSION.reach(direction,float(a.rule().reach),blockers)
		rays.append(reach)
		polygon.append(mouth+direction*reach)
	a.attack_points = polygon
	var delta: Vector2 = a.run_state.ship_pos-mouth
	var angle := angle_difference(fan_angle,delta.angle())
	if absf(angle) <= float(a.rule().half_angle):
		var index := clampi(int((angle/float(a.rule().half_angle)+1.0)*24.0),0,47)
		if delta.length() < minf(rays[index],rays[index+1]):
			a.ctx.ship.damage(float(a.rule().damage)*a.ctx.cfg.atk_scale,0.0,&"breath",&"draco")
func end(a: BossActor, _cancelled: bool) -> void:
	for rock: FieldSystem.Rock in rocks:
		rock.destroyed = true
		if a.ctx.enemies.is_same(rock.row,rock.row_id) and a.table.dead[rock.row] == 0:
			a.ctx.enemies.mark_dead(rock.row)
			a.presentation_event.emit({"cue":&"rock_break","pos":rock.pos,"radius":rock.size})
	a.attack_points.clear()
