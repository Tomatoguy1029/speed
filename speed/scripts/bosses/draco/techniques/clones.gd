## 全身複製の値と動き。
@tool
extends BossTechnique

## 予告（秒）
@export_range(0,100000,0.01) var warn := 1.2
## 攻撃の継続時間
@export_range(0,100000,0.01) var active := 7.5
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 1.2
## ダメージ
@export_range(0,100000,0.01) var damage := 28.0
## 当たりの太さ（中心から片側）
@export_range(0,100000,0.01) var width := 50.0
## 複製体のHP
@export_range(0,100000,0.01) var clone_hp := 350.0
## 複製1体の星数（仮）
@export_range(0,100000,1) var clone_stars := 13

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends BossTechnique.Runner:
	const FORM = preload("res://scripts/bosses/draco_form.gd")
	const HYDRA = preload("res://data/bosses/hydra.tres")
	const MOVES = [preload("res://data/bosses/hydra_moves/bite_thrust.tres"),preload("res://data/bosses/hydra_moves/wind_band.tres"),preload("res://data/bosses/hydra_moves/rubble_fan.tres"),preload("res://data/bosses/hydra_moves/beam_fixed.tres"),preload("res://data/bosses/hydra_moves/thunder_drop.tres")]
	var units: Array = []
	var host: Node
	var center := Vector2.ZERO
	var ended := false
	class Host:
		extends Node
		var _time: float:
			get: return actor.clock
		var runners := {}
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
				if move.technique == id: return HYDRA.params.merged(move.values(),true)
			return HYDRA.params
		func tracks_during_warn(_id: StringName) -> bool: return true
		func tick_normal(n: Dictionary, dt: float) -> void:
			if not runners.has(n.mode):
				for move in MOVES:
					if move.technique == n.mode: runners[n.mode] = move.make_runner()
			runners[n.mode].tick_neck(self, n, dt)
		func _head_pos(n: Dictionary) -> Vector2: return n.strike_pos if n.locked else table.pos[n.row]
		func _neck_base(n: Dictionary) -> Vector2: return table.pos[n.row]
		func aim_neck(n: Dictionary, angle: float, _dt: float) -> void: n.angle=angle
		func _cue(_cue: StringName,_attack: StringName,_index: int) -> void: pass
		func head_index(_n: Dictionary) -> int: return 0
		func finish_normal(n: Dictionary) -> void: n.done=true
	func begin(a: BossActor) -> void:
		center = a.aim_target()
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
				# 複製の耐久は技の設定を使う。通常敵の星別HP表へ置き換えない。
				copy.id=&"draco_copy";copy.behavior=&"drift";copy.radius=a.table.r[a.body];copy.hp=float(a.rule().clone_hp);copy.speed=0;copy.rank=0
				row=a.ctx.enemies.spawn(copy,center+Vector2.from_angle(j*TAU/3.0)*650.0)
				a.table.held[row]=1
			var move: Resource = MOVES[order[j]]
			units.append({"row":row,"id":a.table.id[row],"mode":move.technique,"t":0.0,"target":center,"angle":(center-a.table.pos[row]).angle(),"length":100.0,"glow":0.0,"locked":false,"strike_from":Vector2.ZERO,"strike_pos":Vector2.ZERO,"step":0,"sweep":0.0,"emission":{},"done":false,"entry_hit":false,"origin":a.table.pos[row],"index":j,"parts":[],"points":a.neutral_body_points(a.table.pos[row],(center-a.table.pos[row]).angle())})
			if j>0:
				var visual=preload("res://scripts/bosses/draco_clone_visual.gd").new()
				visual.actor=a;visual.unit=units[-1]
				host.add_child(visual)
				units[-1].visual=visual
				for k in a.body_rows.size():
					var part := EnemyDef.new()
					part.params.clone_visual=true
					part.id=&"draco_copy_part";part.behavior=&"drift";part.radius=a.body_width*0.5;part.hp=999999;part.speed=0
					var segment := a.ctx.enemies.spawn(part,a.table.pos[row])
					a.table.held[segment]=1;a.table.parent[segment]=a.body;a.table.parent_id[segment]=a.body_id
					a.clone_damage_rows[segment]={"row":row,"id":a.table.id[row],"part_id":a.table.id[segment]}
					units[-1].parts.append({"row":segment,"id":a.table.id[segment]})
			_sync_shape(a,units[-1])
			a.telegraph_paths.append(PackedVector2Array([a.table.pos[row]+Vector2.from_angle(float(units[-1].angle))*120.0*a.head_scale,center]))
			a.telegraph_widths.append(float(a.rule().width))
	func tick(a: BossActor, dt: float) -> void:
		host.attack_field.tick(dt)
		a.telegraph_paths.clear()
		a.telegraph_widths.clear()
		for unit: Dictionary in units:
			if not a.ctx.enemies.is_same(unit.row,unit.id) or a.table.dead[unit.row]!=0:
				for part: Dictionary in unit.parts:
					if a.ctx.enemies.is_same(part.row,part.id): a.ctx.enemies.mark_dead(part.row)
				continue
			var entry: float = float(unit.index)*0.7
			if a.elapsed<entry:
				a.telegraph_paths.append(PackedVector2Array([a.table.pos[unit.row]+Vector2.from_angle(float(unit.angle))*120.0*a.head_scale,center]))
				a.telegraph_widths.append(float(a.rule().width))
				continue
			var forward := Vector2.from_angle(float(unit.angle))
			var mouth_offset: float = 120.0 * a.head_scale
			var landing := center - forward * mouth_offset
			if a.elapsed<entry+0.5:
				var before: Vector2 = a.table.pos[unit.row] + forward * mouth_offset
				a.table.pos[unit.row]=unit.origin.lerp(landing,clampf((a.elapsed-entry)/0.5,0.0,1.0))
				var after: Vector2 = a.table.pos[unit.row] + forward * mouth_offset
				if not unit.entry_hit: a.combat_trace.evaluate()
				var nearest := Geometry2D.get_closest_point_to_segment(a.run_state.ship_pos,before,after)
				if not unit.entry_hit and nearest.distance_to(a.run_state.ship_pos) <= float(a.rule().width) + a.ctx.cfg.ship_radius:
					unit.entry_hit = a.combat_trace.damage(float(a.rule().damage) * a.ctx.cfg.atk_scale,0.0,&"clone_leap",&"draco")
			elif a.elapsed<entry+0.9:
				a.table.pos[unit.row]=landing.lerp(unit.origin,(a.elapsed-entry-0.5)/0.4)
			elif not unit.done:
				unit.t=float(unit.t)+dt
				host.tick_normal(unit,dt)
				if unit.mode==&"bite_thrust" and unit.locked: a.table.pos[unit.row]=unit.strike_pos
			if a.elapsed>float(a.rule().active)-1.0 and unit.index>0:
				a.table.pos[unit.row]=a.table.pos[unit.row].lerp(a.table.pos[a.body],minf(1.0,dt*5.0))
			_sync_shape(a,unit)
	func end(a: BossActor, cancelled: bool) -> void:
		if ended: return
		ended = true
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
				a.picaro.members.append({"row":unit.row,"id":unit.id,"born":a.clock-2.0,"stars":int(a.rule().get("clone_stars",13)),"clone_parts":unit.parts,"visual":unit.visual,"angle":unit.angle,"unit":unit})
				continue
			if a.ctx.enemies.is_same(unit.row,unit.id): a.ctx.enemies.mark_dead(unit.row)
			for part: Dictionary in unit.parts:
				if a.ctx.enemies.is_same(part.row,part.id): a.ctx.enemies.mark_dead(part.row)
				if int(a.clone_damage_rows.get(part.row,{}).get("part_id",-1))==int(part.id): a.clone_damage_rows.erase(part.row)
		a.attack_points.clear()
		a.telegraph_paths.clear()
		a.telegraph_widths.clear()

	func _sync_shape(a: BossActor, unit: Dictionary) -> void:
		var points: PackedVector2Array = a.neutral_body_points(a.table.pos[unit.row], float(unit.angle))
		unit.points = points
		if unit.index == 0:
			a.table.facing[a.body] = float(unit.angle)
		for k in unit.parts.size():
			var part: Dictionary = unit.parts[k]
			if a.ctx.enemies.is_same(part.row, part.id):
				a.table.pos[part.row] = FORM.sample(points,float(k+1)/float(unit.parts.size()))
				a.table.r[part.row] = a.body_width * 0.5 * FORM.taper(float(k+1)/float(unit.parts.size()))
