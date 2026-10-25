## 専用の頭担当を全身の竜へ載せ、Hydraの技と攻撃形状を共用する。
extends RefCounted
const NORMALS = preload("res://scripts/bosses/hydra_normals.gd")
const HYDRA = preload("res://data/bosses/hydra.tres")
const MOVES = [preload("res://data/bosses/hydra_moves/bite_thrust.tres"),preload("res://data/bosses/hydra_moves/wind_band.tres"),preload("res://data/bosses/hydra_moves/rubble_fan.tres"),preload("res://data/bosses/hydra_moves/beam_fixed.tres"),preload("res://data/bosses/hydra_moves/thunder_drop.tres")]
var units: Array = []
var host: Node
var center := Vector2.ZERO
class Host:
	extends Node
	var _time: float:
		get: return actor.clock
	var actor: BossActor
	var ctx: RunContext
	var run_state: RunState
	var table: EnemyTable
	var def: BossDef
	var attack_field: Node2D
	var energy_shader: Shader = preload("res://shaders/hydra_energy.gdshader")
	var tornado_scene: PackedScene = preload("res://scenes/bosses/hydra_tornado.tscn")
	func move_params(id: StringName) -> Dictionary:
		for move in MOVES:
			if move.technique == id: return HYDRA.params.merged(move.parameters,true)
		return HYDRA.params
	func _head_pos(n: Dictionary) -> Vector2: return n.strike_pos if n.locked else table.pos[n.row]
	func _neck_base(n: Dictionary) -> Vector2: return table.pos[n.row]
	func aim_neck(n: Dictionary, angle: float, _dt: float) -> void: n.angle=angle
	func _cue(_cue: StringName,_attack: StringName,_index: int) -> void: pass
	func head_index(_n: Dictionary) -> int: return 0
	func finish_normal(n: Dictionary) -> void: n.done=true
func begin(a: BossActor) -> void:
	center = a.aim
	host = Host.new()
	host.actor=a;host.ctx=a.ctx;host.run_state=a.run_state;host.table=a.table;host.def=HYDRA
	a.add_child(host)
	host.attack_field=preload("res://scripts/bosses/hydra_attack_field.gd").new()
	host.add_child(host.attack_field)
	host.attack_field.bind(host)
	var order: Array = [0,1,2,3,4]
	for j in range(order.size()-1,0,-1):
		var k := a.run_state.rng.randi_range(0,j)
		var swap: int=order[j];order[j]=order[k];order[k]=swap
	for j in 3:
		var row: int = a.body
		if j>0:
			var copy := EnemyDef.new()
			copy.params.clone_visual=true
			copy.id=&"draco_copy";copy.behavior=&"drift";copy.radius=90.0;copy.hp=float(a.rule().clone_hp);copy.speed=0;copy.rank=1
			row=a.ctx.enemies.spawn(copy,center+Vector2.from_angle(j*TAU/3.0)*650.0)
			a.table.held[row]=1
		var move: Resource = MOVES[order[j]]
		units.append({"row":row,"id":a.table.id[row],"mode":move.technique,"t":0.0,"target":a.aim,"angle":(a.aim-a.table.pos[row]).angle(),"length":100.0,"glow":0.0,"locked":false,"strike_from":Vector2.ZERO,"strike_pos":Vector2.ZERO,"step":0,"sweep":0.0,"emission":{},"done":false,"origin":a.table.pos[row],"index":j,"parts":[]})
		if j>0:
			var visual=preload("res://scripts/bosses/draco_clone_visual.gd").new()
			visual.actor=a;visual.unit=units[-1]
			host.add_child(visual)
			units[-1].visual=visual
			for k in 12:
				var part := EnemyDef.new()
				part.params.clone_visual=true
				part.id=&"draco_copy_part";part.behavior=&"drift";part.radius=35;part.hp=999999;part.speed=0
				var segment := a.ctx.enemies.spawn(part,a.table.pos[row])
				a.table.held[segment]=1;a.table.parent[segment]=a.body;a.table.parent_id[segment]=a.body_id
				a.clone_damage_rows[segment]={"row":row,"id":a.table.id[row],"part_id":a.table.id[segment]}
				units[-1].parts.append({"row":segment,"id":a.table.id[segment]})
func tick(a: BossActor, dt: float) -> void:
	host.attack_field.tick(dt)
	for unit: Dictionary in units:
		if not a.ctx.enemies.is_same(unit.row,unit.id) or a.table.dead[unit.row]!=0:
			for part: Dictionary in unit.parts:
				if a.ctx.enemies.is_same(part.row,part.id): a.ctx.enemies.mark_dead(part.row)
			continue
		var entry: float = float(unit.index)*0.7
		if a.elapsed<entry: continue
		if a.elapsed<entry+0.5:
			a.table.pos[unit.row]=unit.origin.lerp(center,clampf((a.elapsed-entry)/0.5,0.0,1.0))
			var point: Vector2 = a.table.pos[unit.row]
			a.hit_segment(PackedVector2Array([point,point+Vector2.from_angle(unit.angle)*120.0]),60.0)
		elif a.elapsed<entry+0.9:
			a.table.pos[unit.row]=center.lerp(unit.origin,(a.elapsed-entry-0.5)/0.4)
		elif not unit.done:
			unit.t=float(unit.t)+dt
			NORMALS.tick(host,unit,dt)
		for k in unit.parts.size():
			var part: Dictionary=unit.parts[k]
			if a.ctx.enemies.is_same(part.row,part.id): a.table.pos[part.row]=a.table.pos[unit.row]+Vector2(-(k+1)*45.0,sin((k+1)*0.7-a.clock)*55.0).rotated(unit.angle)
		if a.elapsed>float(a.rule().active)-1.0 and unit.index>0:
			a.table.pos[unit.row]=a.table.pos[unit.row].lerp(a.table.pos[a.body],minf(1.0,dt*5.0))
func end(a: BossActor, cancelled: bool) -> void:
	if host != null:
		for effect: Dictionary in host.attack_field.effects:
			if not effect.persistent: effect.life=0.0
		if not host.attack_field.effects.any(func(e):return e.persistent):
			host.attack_field.clear_effects()
			host.queue_free()
		else: a.retained_fields.append(host)
	for unit: Dictionary in units:
		if unit.index==0: continue
		if cancelled and a.ctx.enemies.is_same(unit.row,unit.id) and a.table.dead[unit.row]==0:
			unit.visual.reparent(a._presentation)
			a.picaro.members.append({"row":unit.row,"id":unit.id,"born":a.clock-2.0,"stars":int(a.rule().get("clone_stars",13)),"clone_parts":unit.parts,"visual":unit.visual,"angle":unit.angle})
			continue
		if a.ctx.enemies.is_same(unit.row,unit.id): a.ctx.enemies.mark_dead(unit.row)
		for part: Dictionary in unit.parts:
			if a.ctx.enemies.is_same(part.row,part.id): a.ctx.enemies.mark_dead(part.row)
			if int(a.clone_damage_rows.get(part.row,{}).get("part_id",-1))==int(part.id): a.clone_damage_rows.erase(part.row)
	a.attack_points.clear()
