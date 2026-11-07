## 原画の導入・初回起動・再視聴・星の順次消灯を確認する。セーブはメモリだけに保持する。
extends Node

class MemorySave:
	extends "res://scripts/managers/save_manager.gd"
	var writes := 0
	func save() -> void:
		writes += 1
		save_changed.emit()
	func _save_settings() -> void:
		pass

var failed := 0
var shots := ""

func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)

func frames() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func shot(filename: String) -> void:
	if shots.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots.path_join(filename + ".png"))

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			shots = arg.trim_prefix("--out=")
	if not shots.is_empty():
		DirAccess.make_dir_recursive_absolute(shots)
	var settings: Dictionary = SaveManager.settings.duplicate(true)
	SaveManager.set_script(MemorySave)
	SaveManager.settings = settings
	SaveManager.data = SaveManager._migrate({"coins": 321, "cleared_stage": 3}, SaveManager.default_data())
	check(not SaveManager.has_seen_intro(), "既存セーブの不足フラグを初期化")
	TranslationServer.set_locale("ja")
	GameManager.boot_request = Callable()
	GameManager.screen = GameManager.Screen.TITLE
	var app: Node = load("res://scenes/app/main.tscn").instantiate()
	add_child(app)
	await frames()
	check(GameManager.screen == GameManager.Screen.INTRO, "未視聴なら起動直後に導入を表示")
	var intro = app._current
	await get_tree().create_timer(0.9).timeout
	check(intro.scene_index == 0 and intro._picture.get_child_count() == 1, "Scene1から開始")
	check(Rect2(Vector2.ZERO, intro.ART_SIZE).encloses(intro.find_child("SkipIntro", true, false).get_rect()), "スキップを画面内に収める")
	check(intro._text.text == tr("intro.scene1.1"), "シナリオの最初の段落を表示")
	await _test_playback(intro)
	await shot("scene1")
	GameManager.back()
	await frames()
	check(GameManager.screen == GameManager.Screen.TITLE and not SaveManager.has_seen_intro(), "途中で戻ると未視聴を維持")
	var replay: Button = app._current.find_child("ReplayIntroButton", true, false)
	check(replay != null and replay.is_visible_in_tree(), "タイトルに再視聴ボタン")
	replay.pressed.emit()
	await frames()
	intro = app._current
	check(intro._auto_play.button_pressed, "選んだ自動再生を再視聴へ引き継ぐ")
	intro._auto_play.button_pressed = false
	intro.scene_fade_seconds = 0.01
	intro.star_fade_seconds = 0.15
	intro.star_gap_seconds = 0.03
	intro.text_hold_seconds = 100.0
	await get_tree().create_timer(0.9).timeout
	for chapter in intro.STORY.SCENES:
		for key in chapter.text:
			intro._text.text = tr(key)
			await get_tree().process_frame
			check(intro._text.get_line_count() * intro._text.get_line_height() <= intro._text.size.y, "文章を表示枠に収める: " + key)
	intro._begin_paragraph()
	intro._text.visible_characters = 0
	intro.advance()
	check(intro._text.visible_characters == intro._text.get_total_character_count(), "最初の決定で全文表示")
	intro.paragraph_index = intro.STORY.SCENES[0].text.size() - 1
	intro._begin_paragraph()
	intro._text.visible_characters = -1
	intro._text.visible_characters = intro._text.get_total_character_count()
	var scene1 = intro._picture
	intro.advance()
	await get_tree().create_timer(0.04).timeout
	check(intro.scene_index == 1 and intro._picture == scene1, "Scene1-2はScene1を保持して重ねる")
	check(intro._picture.get_child_count() == 2, "竜のレイヤーを追加")
	await shot("scene1-2")
	intro._show_scene(5)
	await get_tree().create_timer(0.04).timeout
	check(intro._stars.size() == 3, "Scene5は星を3枚表示")
	var frame: TextureRect = intro._canvas.get_node("ArtFrame")
	check(frame.visible and frame.z_index > intro._picture.z_index, "Scene4以降も共通フレームを絵の上に維持")
	var mask := frame.texture.get_image()
	check(mask.get_pixel(0, 0).a == 1.0 and mask.get_pixel(320, 100).a == 0.0, "原画のoutlineで枠の外を隠す")
	await shot("scene5")
	intro.paragraph_index = intro.STORY.SCENES[5].text.size() - 1
	intro._begin_paragraph()
	intro._text.visible_characters = intro._text.get_total_character_count()
	intro.advance()
	intro.advance()
	await get_tree().create_timer(0.22).timeout
	check(intro.scene_index == 5, "星が全て消えるまでScene5に留まる")
	check(intro._stars[0].modulate.a == 0.0 and intro._stars[2].modulate.a == 1.0, "星は一枚ずつ順に消える")
	await shot("scene5-fading")
	await get_tree().create_timer(0.4).timeout
	check(intro.scene_index == 6 and intro._stars.is_empty(), "星の消灯後はScene6へ進む")
	await shot("scene6")
	intro._show_scene(7)
	await get_tree().create_timer(0.04).timeout
	intro.paragraph_index = intro.STORY.SCENES[7].text.size() - 1
	intro._begin_paragraph()
	intro._text.visible_characters = intro._text.get_total_character_count()
	intro._process(100.0)
	check(GameManager.screen == GameManager.Screen.INTRO and not SaveManager.has_seen_intro(), "手動送りの最終段落も操作するまで終了しない")
	intro.advance()
	await frames()
	check(GameManager.screen == GameManager.Screen.TITLE and SaveManager.has_seen_intro(), "完了で視聴済みを保存してタイトルへ")
	check(SaveManager.writes == 1 and SaveManager.data.coins == 321 and SaveManager.data.cleared_stage == 3, "保存は一度だけ、既存の進行を維持")
	GameManager.replay_intro()
	await frames()
	app._current.find_child("SkipIntro", true, false).pressed.emit()
	await frames()
	check(GameManager.screen == GameManager.Screen.TITLE and SaveManager.writes == 1, "再視聴のスキップで保存を増やさない")
	GameManager.goto(GameManager.Screen.STAGE_SELECT)
	await frames()
	check(GameManager.screen == GameManager.Screen.STAGE_SELECT, "ステージ選択に導入を挟まない")
	app.queue_free()
	await frames()
	GameManager.screen = GameManager.Screen.TITLE
	var second_app: Node = load("res://scenes/app/main.tscn").instantiate()
	add_child(second_app)
	await frames()
	check(GameManager.screen == GameManager.Screen.TITLE, "次回起動は視聴済みならタイトルから")
	second_app.queue_free()
	await frames()
	print("[intro_story] failures=", failed)
	get_tree().quit(1 if failed else 0)

## 実入力と長い経過時間で、全文表示・待機・次送り・途中切替を区別する。
func _test_playback(intro: Control) -> void:
	intro.set_process(false)
	check(not SaveManager.default_settings().intro_auto_advance, "初期設定は手動送り")
	intro._auto_play.button_pressed = false
	intro._begin_paragraph()
	var auto_button: Button = intro._auto_play
	check(Rect2(Vector2.ZERO, intro.ART_SIZE).encloses(auto_button.get_rect()), "自動再生の切替を画面内に収める")
	check(not auto_button.get_rect().intersects(intro._next.get_rect()), "自動再生と次へを重ねない")
	await frames()
	var picture_point: Vector2 = intro._canvas.get_global_transform_with_canvas() * Vector2(320, 180)
	_click_at(picture_point)
	check(intro.paragraph_index == 0 and intro._text.visible_characters == intro._text.get_total_character_count(), "画面の1クリックで全文だけを表示")
	intro._process(100.0)
	check(intro.paragraph_index == 0, "全文表示後は長く待っても手動では進まない")
	_click_at(picture_point)
	check(intro.paragraph_index == 1 and intro._text.visible_characters == 0, "次のクリックで次段落を先頭から表示")
	intro._process(100.0)
	intro._process(100.0)
	check(intro.paragraph_index == 1, "自然に全文を表示した場合も手動では進まない")
	var before: String = intro._text.text
	_click_at(auto_button.get_global_rect().get_center())
	check(auto_button.button_pressed and SaveManager.settings.intro_auto_advance, "切替ボタンの実クリックで自動再生を保存")
	check(intro._text.text == before and intro.paragraph_index == 1, "切替クリックが次送りへ漏れない")
	intro._process(intro.text_hold_seconds - 0.01)
	check(intro.paragraph_index == 1, "自動再生を入れても待ち時間前には進まない")
	intro._process(0.02)
	check(intro.paragraph_index == 2, "自動再生は待ち時間の後に進む")
	intro._process(0.05)
	var shown: int = intro._text.visible_characters
	_click_at(auto_button.get_global_rect().get_center())
	check(not auto_button.button_pressed and intro._text.visible_characters == shown, "文字表示途中で手動へ切り替えても文章を飛ばさない")
	_click_at(intro._next.get_global_rect().get_center())
	check(intro.paragraph_index == 2 and intro._text.visible_characters == intro._text.get_total_character_count(), "全文表示ボタンも1クリックで全文だけを表示")
	intro._process(100.0)
	check(intro.scene_index == 0 and intro.paragraph_index == 2, "場面末尾の全文表示後も停止")
	intro._auto_play.button_pressed = true
	intro._process(intro.text_hold_seconds * 0.75)
	intro._auto_play.button_pressed = false
	intro._process(100.0)
	check(intro.scene_index == 0, "自動再生の待ち時間中に手動へ切り替えると止まる")
	intro.paragraph_index = 0
	intro._begin_paragraph()
	intro._next.release_focus()
	var touch := InputEventScreenTouch.new()
	touch.position = picture_point
	touch.pressed = true
	get_viewport().push_input(touch, true)
	touch.pressed = false
	get_viewport().push_input(touch, true)
	check(intro.paragraph_index == 0 and intro._text.visible_characters == intro._text.get_total_character_count(), "タップでも全文表示と次送りを分ける")
	for down in [true, false]:
		var accept := InputEventAction.new()
		accept.action = &"ui_accept"
		accept.pressed = down
		get_viewport().push_input(accept, true)
	check(intro.paragraph_index == 1, "決定キーで次の段落へ進む")
	intro.paragraph_index = 0
	intro._begin_paragraph()
	intro._auto_play.button_pressed = true
	intro.set_process(true)

func _click_at(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.pressed = down
		get_viewport().push_input(event, true)
