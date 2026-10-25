## 描画パス内の固定値共有は、半径・ライブ編集・Sessionの所有権を変えない。
extends Node
var passed := 0
var failed := 0
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)
func legacy_radius(view: RunPresentation, type: StringName, radius: float) -> float:
	var def := view.run.enemies.def_of(type)
	if def != null: radius /= def.visual_value("collision_scale", 1.0)
	var look := view.look_of(type)
	if look == null or look.size_from_collision: return radius
	return maxf(look.base.get_width(), look.base.get_height()) * 0.5 * radius / maxf(def.radius if def != null else radius, 0.001)
func _ready() -> void:
	var session := RunManager.create_session(self, {"lab":true,"seed":401,"stage_index":4},true)
	session.auto_step = false
	var view: RunPresentation = session.view.get_node("RunPresentation")
	for type in [&"biter",&"bomber",&"splitter",&"splitling",&"crab"]:
		view._drawing_enemies = true
		for radius in [0.0,0.001,13.0,26.0,99.73]:
			var expected := legacy_radius(view,type,radius)
			var actual := view.enemy_sprite_radius(type,radius)
			check(PackedFloat64Array([actual]).to_byte_array() == PackedFloat64Array([expected]).to_byte_array(),
				"元の半径計算とビット一致: %s %s" % [type,radius])
		check(view._enemy_sprite_metrics.size()==1,"同じ種類は1パスで1組の数値を共有")
		for value in view._enemy_sprite_metrics[type]: check(typeof(value)==TYPE_FLOAT,"共有値は数値だけでResourceを所有しない")
		view._drawing_enemies = false
		view._enemy_sprite_metrics.clear()
	var system := session.sim.enemies
	var original := system.def_of(&"biter")
	var changed: EnemyDef = original.duplicate(true)
	changed.visual_settings["collision_scale"] = 1.7
	changed.radius = original.radius * 2.0
	system.definitions[&"biter"] = changed
	check(view.enemy_sprite_radius(&"biter",26.0)==legacy_radius(view,&"biter",26.0),"描画外の問い合わせは現在のラン専用定義を即座に読む")
	view._drawing_enemies = true
	check(view.enemy_sprite_radius(&"biter",26.0)==legacy_radius(view,&"biter",26.0),"次のパスは変更済みの定義と衝突倍率を使う")
	view._drawing_enemies = false
	view._enemy_sprite_metrics.clear()
	var look := view.look_of(&"biter")
	var old_size_from_collision := look.size_from_collision
	look.size_from_collision = not old_size_from_collision
	view._drawing_enemies = true
	check(view.enemy_sprite_radius(&"biter",26.0)==legacy_radius(view,&"biter",26.0),"同じ外観Resourceの編集も次のパスへ反映")
	view._drawing_enemies = false
	view._enemy_sprite_metrics.clear()
	look.size_from_collision = old_size_from_collision
	var weak: WeakRef = weakref(changed)
	system.definitions[&"biter"] = original
	changed = null
	check(weak.get_ref()==null,"共有数値は差替前のラン専用EnemyDefを保持しない")
	system.spawn(original,session.sim.state.ship_pos+Vector2(80,0))
	for frame in 3:
		await get_tree().process_frame
		if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
	check(not view._drawing_enemies and view._enemy_sprite_metrics.is_empty(),"実描画の終了後はパス内の共有値を破棄する")
	session.free()
	await get_tree().process_frame
	var next := RunManager.create_session(self,{"lab":true,"seed":401,"stage_index":1},true)
	next.auto_step = false
	var next_view: RunPresentation = next.view.get_node("RunPresentation")
	check(next_view._enemy_sprite_metrics.is_empty() and next_view.enemy_sprite_radius(&"biter",26.0)==legacy_radius(next_view,&"biter",26.0),"次のランに前の種類別数値を持ち越さない")
	next.free()
	await get_tree().process_frame
	print("[enemy_sprite_metrics] passed=%d failed=%d" % [passed,failed])
	get_tree().quit(1 if failed else 0)
