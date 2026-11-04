## 死亡時の値だけを0.5秒保持する。元の敵・戦闘判定へ参照を残さない。
extends Node
const MASKS := "res://assets/effects/elite_death/masks.tres"
const DISPLAY := preload("res://scripts/render/run_enemy_frame.gd")
var _scope: ContentResourceScope
var _entries: Dictionary
var _masks: Dictionary
var _life := 0.5
var _active: Array[Dictionary] = []
var _displays: Dictionary = {}
var _clock := -1.0

func setup(scope: ContentResourceScope, entries: Dictionary) -> void:
	clear()
	_scope = scope
	_entries = entries
	var baked: Resource = scope.resources.get(MASKS)
	_masks = baked.get_meta("masks",{}) if baked != null else {}
	_life = baked.get_meta("lifetime",0.5) if baked != null else 0.5

func clear() -> void:
	_active.clear()
	_clock = -1.0
	for display: Node in _displays.values(): display.queue_free()
	_displays.clear()

func add_event(event: Dictionary, now: float, view: Rect2) -> void:
	if not event.has("death_visual"): return
	var pose: Dictionary = event.death_visual
	var entry: Dictionary = _entries.get(pose.visual_id,{})
	if entry.get("role",-1)!=6: return
	var look: EnemyLook = _scope.resources.get(entry.path)
	if look == null or not _masks.has(look.source_path): return
	var age := maxf(0.0,now-float(event.get("world_t",now)))
	if age>=_life: return
	# 画面外でも0.5秒以内に入る船体は保持。破片ごとのCPU更新はしない。
	var swept := view.grow(float(pose.radius)*2.0+pose.velocity.length()*_life)
	if not swept.has_point(event.pos): return
	if not _displays.has(pose.visual_id):
		var display := DISPLAY.new()
		add_child(display)
		display.setup(_scope,entry,_masks)
		_displays[pose.visual_id] = display
	var item := pose.duplicate()
	item.id = event.id
	item.origin = event.pos
	item.born = now-age
	_active.append(item)

func step(now: float, view: Rect2, brightness: float = 1.0) -> void:
	if _clock>=0.0 and now<_clock:
		_active.clear()
	_clock = now
	var rows := {}
	for display in _displays.values(): display.begin(); display.set_death_brightness(brightness)
	for i in range(_active.size()-1,-1,-1):
		var item := _active[i]
		var age := now-float(item.born)
		if age>=_life or age<0.0:
			_active.remove_at(i)
			continue
		var position: Vector2 = item.origin+item.velocity*age
		if not view.grow(item.radius*2.0).has_point(position): continue
		if not rows.has(item.visual_id):
			rows[item.visual_id] = {"ids":PackedInt64Array(),"transforms":PackedFloat32Array(),"colors":PackedColorArray(),"ruler_sides":PackedInt32Array(),"pump":PackedFloat32Array(),
				"biter":{"modes":PackedInt32Array(),"charges":PackedFloat32Array(),"timers":PackedFloat32Array(),"rests":PackedFloat32Array()}}
		var row: Dictionary = rows[item.visual_id]
		row.ids.append(item.id)
		var x := Vector2.from_angle(item.angle)*float(item.radius)
		row.transforms.append_array(PackedFloat32Array([x.x,x.y,-x.y,x.x,position.x,position.y]))
		row.colors.append(Color(0,0,0,age/_life))
		row.ruler_sides.append(item.ruler_side)
		row.biter.modes.append(item.mode)
		row.biter.charges.append(item.charge)
		row.biter.timers.append(item.timer)
		row.biter.rests.append(item.rest)
		if item.pump_scale>0.0:
			row.pump.append_array(PackedFloat32Array([position.x,position.y,item.angle,item.pump_scale,item.pump_full,item.pump_stored,item.born,0,0]))
	for id in rows: _displays[id].apply_frame(rows[id])
	for display in _displays.values(): display.end()
