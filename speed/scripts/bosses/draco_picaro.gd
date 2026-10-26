## 元の敵定義を複製し、個体と生成・攻撃担当の寿命を所有する。
extends RefCounted
const FORM = preload("res://scripts/bosses/draco_form.gd")
var actor: BossActor
var members: Array = []
var _pending: Array = []
var attacking := true
func _init(a: BossActor) -> void:
	actor = a
	actor.ctx.enemies.picaro_spawned.connect(_on_picaro_spawned)
func _on_picaro_spawned(row: int, row_id: int, owner_id: int) -> void:
	if owner_id == actor.body_id: _pending.append({"row": row, "id": row_id})
func spawn_picaro(type: StringName, at: Vector2) -> int:
	var source := actor.ctx.enemies.def_of(type)
	if source == null: return -1
	var copy := source.duplicate(true) as EnemyDef
	copy.params.picaro = true
	copy.params.picaro_owner=actor.body_id
	copy.params.source_type = type
	var row := actor.ctx.enemies.spawn(copy,at)
	actor.table.held[row] = 1
	actor.table.guard[row] = 1.0
	members.append({"row":row,"id":actor.table.id[row],"born":actor.clock,"stars":maxi(1,source.rank),"parts":actor.table.parts[row].duplicate()})
	return row
func alive() -> Array:
	return members.filter(func(m): return actor.ctx.enemies.is_same(m.row,m.id) and actor.table.dead[m.row]==0)
func tick() -> void:
	if not _pending.is_empty():
		var known := {}
		for member: Dictionary in members: known[member.id] = true
		for spawned: Dictionary in _pending:
			var row: int = spawned.row
			if known.has(spawned.id) or not actor.ctx.enemies.is_same(row, spawned.id) or actor.table.dead[row] != 0 or actor.table.parent[row] >= 0: continue
			var definition: EnemyDef = actor.table.def[row]
			members.append({"row": row, "id": spawned.id, "born": actor.clock, "stars": maxi(1, definition.rank), "parts": actor.table.parts[row].duplicate()})
			known[spawned.id] = true
		_pending.clear()
	for member: Dictionary in members:
		if not actor.ctx.enemies.is_same(member.row,member.id) or actor.table.dead[member.row]!=0: _release_parts(member)
	members = alive()
	for m: Dictionary in members:
		var forming: bool = actor.clock-float(m.born)<1.0
		m.parts=actor.table.parts[m.row].duplicate()
		actor.table.held[m.row] = 1 if forming or not attacking else 0
		actor.table.guard[m.row] = 1.0 if forming else 0.0
		if m.has("clone_parts"):
			var points: PackedVector2Array = actor.neutral_body_points(actor.table.pos[m.row],float(m.angle))
			if m.has("unit"): m.unit.points=points
			for j in m.clone_parts.size():
				var part: Dictionary=m.clone_parts[j]
				if actor.ctx.enemies.is_same(part.row,part.id):
					actor.table.pos[part.row]=FORM.sample(points,float(j+1)/float(m.clone_parts.size()))
					actor.table.r[part.row]=actor.body_width*0.5*FORM.taper(float(j+1)/float(m.clone_parts.size()))
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
	_pending.clear()
	for m: Dictionary in members:
		_release_parts(m)
		if actor.ctx.enemies.is_same(m.row,m.id): actor.ctx.enemies.mark_dead(m.row)
	members.clear()

func dispose() -> void:
	clear()
	if actor.ctx.enemies.picaro_spawned.is_connected(_on_picaro_spawned): actor.ctx.enemies.picaro_spawned.disconnect(_on_picaro_spawned)

func _release_parts(member: Dictionary) -> void:
	var normal: PackedInt32Array=member.get("parts",PackedInt32Array())
	for j in range(0,normal.size(),2):
		if actor.ctx.enemies.is_same(normal[j],normal[j+1]): actor.ctx.enemies.mark_dead(normal[j])
	for part: Dictionary in member.get("clone_parts",[]):
		if actor.ctx.enemies.is_same(part.row,part.id): actor.ctx.enemies.mark_dead(part.row)
		if int(actor.clone_damage_rows.get(part.row,{}).get("part_id",-1))==int(part.id): actor.clone_damage_rows.erase(part.row)
	if member.has("visual") and is_instance_valid(member.visual): member.visual.queue_free()
