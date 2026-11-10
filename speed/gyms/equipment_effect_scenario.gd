## 装備の実戦プレビュー。編集画面と実行時エラー検査で同じ発動手順を使う。
extends RefCounted
const GemKind := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS.GemKind
const PASSIVE_KEYS := ["trait/quickCharge","trait/capacity","trait/critRate","trait/speed","trait/attack","trait/pickup","trait/length","trait/glideDuration","trait/bigSwing","trait/multiShot"]

static func play(session, key: String, use_sample_weapon := true, heading := Vector2.RIGHT) -> bool:
	if session.bridge==null: return false
	var run: RefCounted = session.run
	var origin: Vector2 = run.state.ship_pos
	var is_trait := key.begins_with("trait/")
	var id := &""
	for entry: ContentEntry in ContentManager.catalog.table(&"traits" if is_trait else &"weapons").values():
		if String(entry.code_id)==key.get_slice("/",1): id = entry.id
	if id==&"" or not (run.state.traits if is_trait else run.state.weapons).has(id): return false
	if use_sample_weapon and key in ["trait/multiShot","trait/fullBurst","trait/duplicator","trait/attack"]:
		session.perform("loadout",{"kind":"weapon","id":"W01","level":5})
	if use_sample_weapon and key=="trait/bigSwing": session.perform("loadout",{"kind":"weapon","id":"W29","level":5})
	var targets := PackedInt64Array()
	for pos in [Vector2(230,0),Vector2(360,30),Vector2(520,-30),Vector2(790,0),Vector2(900,100),Vector2(-180,0)]:
		var row := spawn(session,origin+pos.rotated(heading.angle()))
		if row<0: return false
		targets.append(run.enemies.table.id[row])
	if key=="weapon/sonic":
		for i in 8:
			for side in [-1.0,1.0]: spawn(session,origin+Vector2(230.0+i*70.0,80.0*side).rotated(heading.angle()))
	if key=="weapon/mines":
		for offset in [Vector2(990,90),Vector2(1050,160),Vector2(1100,40)]: spawn(session,origin+offset.rotated(heading.angle()))
	if key=="trait/pickup":
		for pos in [Vector2(80,80),Vector2(160,80),Vector2(230,80)]:
			if not session.perform("command",{"name":"dev_drop_crystal","args":{"position":origin+pos.rotated(heading.angle()),"kind":GemKind.Low}}): return false
	if not session.perform("command",{"name":"dev_edit","args":{"kind":"equipment_preview","payload":{"id":String(id),"heading":heading,"targets":targets}}}): return false
	if key in ["trait/killSonic","trait/rampage"]:
		var seeded := {"done":false,"bridge":weakref(session.bridge)}
		seeded.callback = _seed_trait_conditions.bind(weakref(session),String(id),seeded)
		session.changed.connect(seeded.callback,CONNECT_DEFERRED)
	var points: Array = []
	for point in [Vector2.ZERO,Vector2(600,0),Vector2(900,100)]:
		var world: Vector2 = origin+point.rotated(heading.angle())
		points.append([world.x,world.y])
	return session.perform("route",{"points":points,"draw_seconds":0.3})

static func _seed_trait_conditions(reference: WeakRef, id: String, seeded: Dictionary) -> void:
	var session = reference.get_ref()
	if session==null: return
	if session.bridge!=seeded.bridge.get_ref() or seeded.done:
		if session.changed.is_connected(seeded.callback): session.changed.disconnect(seeded.callback)
		return
	if not session.run.state.tracing: return
	seeded.done = true
	if session.changed.is_connected(seeded.callback): session.changed.disconnect(seeded.callback)
	session.perform("command",{"name":"dev_edit","args":{"kind":"equipment_seed","payload":{"id":id}}})

static func spawn(session, pos: Vector2) -> int:
	if not session.perform("spawn",{"type":"splitling","pos":[pos.x,pos.y]}): return -1
	return session.selected
