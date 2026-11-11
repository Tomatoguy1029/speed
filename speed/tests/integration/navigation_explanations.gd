## 初回案内とULT説明を本物のラン境界・入力で確認する。保存はメモリだけ。
extends "res://tests/integration/hero_guidance.gd"
class MemorySave extends "res://scripts/managers/save_manager.gd":
	var writes := 0
	func save() -> void:
		writes += 1
var hud: Control
var run: RefCounted
var guides: Node

func frames() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func tap(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	get_viewport().push_input(event, true)
	event = InputEventKey.new()
	event.keycode = code
	event.pressed = false
	get_viewport().push_input(event, true)

func advance_run() -> void:
	for i in 20:
		var result: Dictionary = run.step(1.0 / 120.0, run.pack_intent(Intent.new()), {"logical_size": Vector2(1280,720)})
		if not result.ok:
			_check(false, "ランの更新: %s" % result)
			return

func _ready() -> void:
	var settings: Dictionary = SaveManager.settings.duplicate(true)
	SaveManager.set_script(MemorySave)
	SaveManager.settings = settings
	SaveManager.data = SaveManager.default_data()
	var migrated: Dictionary = SaveManager._migrate({"intro_seen":true}, SaveManager.default_data())
	_check(not migrated.landmark_guide_seen and not migrated.hero_guide_seen, "旧セーブは案内未表示として復元する")
	run = _cpp_fixture()
	var hero: Dictionary = _cpp_tick(run)
	var carriers: PackedInt64Array = hero.carriers.duplicate()
	hud = load("res://scripts/ui/hud.gd").new()
	hud.bridge = run
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(hud)
	guides = hud.get_node("NavigationGuides")
	run.collect_frame()
	_check(run.command("dev_kill", {"entity_id":carriers[0],"cause":"shot"}).ok, "実際の初回目印回収")
	await frames()
	_check(guides.window != null and not guides.window.hero_guide, "初回回収で目印の説明が開く")
	if guides.window == null:
		get_tree().quit(1)
		return
	var before: float = run.read_frame().value.ui.run_time
	advance_run()
	_check(is_equal_approx(run.read_frame().value.ui.run_time,before), "説明中は戦闘時計が止まる")
	await get_tree().create_timer(0.55).timeout
	tap(KEY_ENTER)
	_check(guides.window != null, "Enterは説明を進めない")
	tap(KEY_SPACE)
	await frames()
	_check(guides.window == null, "Spaceで説明を閉じる")
	advance_run()
	_check(run.read_frame().value.ui.run_time > before, "閉じた後に戦闘時計が再開する")
	_check(run.command("dev_kill", {"entity_id":carriers[1],"cause":"shot"}).ok, "2体目の回収で星座発見")
	advance_run()
	await frames()
	_check(guides.window != null and guides.window.hero_guide, "発見時は星座の解放説明が開く")
	await get_tree().create_timer(0.55).timeout
	tap(KEY_SPACE)
	await frames()
	var restored: Dictionary = SaveManager._migrate(SaveManager.data.duplicate(true),SaveManager.default_data())
	_check(restored.landmark_guide_seen and restored.hero_guide_seen, "2種類の表示済み状態が保存・復元される")
	guides._receive({"ui":run.read_frame().value.ui,"events":[{"type":"landmark"},{"type":"hero_discovered"}]})
	await frames()
	_check(guides.window == null and guides.pending.is_empty(), "表示済みの説明は繰り返さない")
	# 設定等と重なる初回発見は、既存のオーバーレイが閉じるまで待つ。
	SaveManager.data.hero_guide_seen = false
	var cover := Control.new()
	hud.add_child(cover)
	hud.show_menu_overlay(cover)
	guides._receive({"ui":run.read_frame().value.ui,"events":[{"type":"hero_discovered"}]})
	await frames()
	_check(guides.window == null and not guides.pending.is_empty(), "ほかの画面に説明を重ねない")
	hud.close_menu_overlay(cover)
	cover.queue_free()
	await frames()
	_check(guides.window != null, "ほかの画面を閉じると保留中の説明を開く")
	await get_tree().create_timer(0.55).timeout
	tap(KEY_SPACE)
	await frames()
	# 実際の星座解放から獲得演出・説明へ進み、全4種類を共通UIで表示する。
	hero = run.read_frame().value.ui.hero
	hud._rewards.ult_acquire_seconds = 0.01
	for i in range(0,hero.links.size(),2):
		run.command("dev_hero_pass", {"from":hero.stars[hero.links[i]],"to":hero.stars[hero.links[i+1]],"dash":i})
	await get_tree().create_timer(0.1).timeout
	_check(hud._rewards._ult_details != null, "実際の星座解放後にULT説明を開く")
	for id in [&"perseus", &"leo", &"gemini", &"hercules"]:
		if id != &"perseus":
			hud._rewards.enqueue_ult({"type":&"hero_freed", "id":id})
			await get_tree().create_timer(0.1).timeout
		var details: Control = hud._rewards._ult_details
		_check(details != null, "%sの説明を表示" % id)
		if details == null: continue
		var panel: Control = details.canvas.get_child(0)
		_check(panel.size == Vector2(868,460) and panel.position + panel.size/2 == Vector2(640,360), "全説明の寸法と中央位置を統一")
		_check(details.effect_label.size.y<=190 and details.effect_label.horizontal_alignment==HORIZONTAL_ALIGNMENT_LEFT, "効果説明は左揃えで枠内に収まる")
		hud._rewards._process(10.0)
		_check(hud._rewards.is_active(), "ULT説明は時間で消えない")
		await get_tree().create_timer(0.55).timeout
		tap(KEY_SPACE)
		await frames()
		_check(not hud._rewards.is_active(), "SpaceでULT説明を閉じる")
	advance_run()
	_check(not run.read_frame().value.ui.presentation_frozen, "報酬表示を閉じた後に停止を解除")
	hud.queue_free()
	await frames()
	run.dispose()
	print("[navigation-explanations] failures=", failed)
	get_tree().quit(1 if failed else 0)
