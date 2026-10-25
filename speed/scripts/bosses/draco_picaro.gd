## 元の敵定義を複製し、個体と生成・攻撃担当の寿命を所有する。
extends RefCounted
var actor: BossActor
var members: Array = []
var attacking := true
func _init(a: BossActor) -> void: actor = a
func spawn_picaro(type: StringName, at: Vector2) -> int:
	var source := actor.ctx.enemies.def_of(type)
	if source == null: return -1
	var copy := source.duplicate(true) as EnemyDef
	copy.id = StringName("picaro_"+String(type))
	copy.params.picaro = true
	copy.params.source_type = type
	var row := actor.ctx.enemies.spawn(copy,at)
	actor.table.held[row] = 1
	actor.table.guard[row] = 1.0
	members.append({"row":row,"id":actor.table.id[row],"born":actor.clock,"stars":maxi(1,source.rank)})
	return row
func alive() -> Array:
	return members.filter(func(m): return actor.ctx.enemies.is_same(m.row,m.id) and actor.table.dead[m.row]==0)
func tick() -> void:
	members = alive()
	for m: Dictionary in members:
		var forming: bool = actor.clock-float(m.born)<1.0
		actor.table.held[m.row] = 1 if forming or not attacking else 0
		actor.table.guard[m.row] = 1.0 if forming else 0.0
		var parts: PackedInt32Array = actor.table.parts[m.row]
		for j in range(0,parts.size(),2):
			if actor.ctx.enemies.is_same(parts[j],parts[j+1]): actor.table.held[parts[j]] = actor.table.held[m.row]
func pause(cancel: bool) -> void:
	attacking = false
	for m: Dictionary in alive():
		var rows := [int(m.row)]
		var parts: PackedInt32Array = actor.table.parts[m.row]
		for j in range(0,parts.size(),2):
			if actor.ctx.enemies.is_same(parts[j],parts[j+1]): rows.append(parts[j])
		for row: int in rows:
			actor.table.held[row] = 1
			if cancel:
				actor.table.mode[row] = EnemyTable.Mode.MOVE
				actor.table.vel[row] = Vector2.ZERO
				for h in actor.ctx.projectiles.hazard_alive.size():
					if actor.ctx.projectiles.owns_hazard(h,row,actor.table.id[row]): actor.ctx.projectiles.release_hazard(h)
func clear() -> void:
	for m: Dictionary in alive(): actor.ctx.enemies.mark_dead(m.row)
	members.clear()
