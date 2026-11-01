extends Node
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)

func aligned(actor: MonocerosBoss) -> bool:
	var horn: Sprite2D = actor._presentation.horn
	var lengths: PackedFloat32Array = horn.texture.get_meta("core_lengths")
	var root := actor.to_local(horn.global_position)
	var tip := actor.to_local(horn.to_global(Vector2.DOWN * lengths[horn.frame]))
	return absf(tip.dot((tip - root).normalized()) - actor.horn_length()) < 0.01

func _ready() -> void:
	GameManager.run_stage = 1
	var session := RunManager.create_run()
	add_child(session)
	if session.sim.state == null: await session.started
	session.auto_step = false
	session.sim.bosses.spawn(load("res://data/bosses/monoceros.tres"), Vector2.ZERO)
	var actor := session.sim.bosses.actor as MonocerosBoss
	actor.selection_enabled = false
	actor.mode = &"idle"
	var view = actor._presentation
	check(view.horn.frame == 0, "第一形態は通常の角")
	check(view.horn.texture.normal_texture != null and view.horn.material.get_shader_parameter("use_normal"), "角に法線照明を適用")
	check(aligned(actor), "通常角の先端は既存の判定長と一致")
	actor.phase_pending = true
	actor.sim_tick(0.01, 0.01)
	check(actor.phase == 2 and view.horn.frame > 0 and view.horn.frame < 14, "第二形態に入ると変形を開始")
	actor.sim_tick(0.45, 0.45)
	var halfway: int = view.horn.frame
	check(halfway > 1 and halfway < 14, "変形の途中フレームを表示")
	actor.sim_tick(0.2, 0.0)
	view._process(0.2)
	check(view.horn.frame == halfway, "世界時間の停止中は変形も停止")
	actor.sim_tick(0.55, 0.55)
	check(view.horn.frame == 14 and actor.mode == &"idle", "形態移行の待機時間内に剣へ変形を完了")
	check(aligned(actor), "剣の先端は既存の判定長と一致")
	actor.sim_tick(0.5, 0.5)
	check(view.horn.frame == 14, "第二形態は最終フレームを保持")
	actor.table.facing[actor.body] += 0.8
	actor.presentation_advanced.emit(0.1)
	check(aligned(actor), "頭の旋回後も角の長さを維持")
	actor.technique = &"charge"
	actor.mode = &"active"
	actor.presentation_advanced.emit(0.01)
	check(view.horn.self_modulate.r > 1.0, "角を使う攻撃中は発光")
	actor.mode = &"idle"
	var restored = actor.presentation_scene.instantiate()
	actor.add_child(restored)
	restored.bind_monoceros(actor)
	check(restored.horn.frame == 14, "第二形態の表示を途中から作っても通常角へ戻さない")
	restored.queue_free()
	session.queue_free()
	await get_tree().process_frame
	print("[monoceros-horn] failures=", failed)
	get_tree().quit(1 if failed else 0)
