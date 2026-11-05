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
	await shot("scene1")
	GameManager.back()
	await frames()
	check(GameManager.screen == GameManager.Screen.TITLE and not SaveManager.has_seen_intro(), "途中で戻ると未視聴を維持")
	var replay: Button = app._current.find_child("ReplayIntroButton", true, false)
	check(replay != null and replay.is_visible_in_tree(), "タイトルに再視聴ボタン")
	replay.pressed.emit()
	await frames()
	intro = app._current
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
