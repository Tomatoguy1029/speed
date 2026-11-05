## 選択先と原画の黄色枠、右窓の二層の位置を確認する。
extends Node
var failed := 0

class SilentAudio:
	extends "res://scripts/managers/audio_manager.gd"
	func play(_name: StringName, _volume_db := 0.0, _pitch := 1.0) -> void:
		pass

func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)

func _ready() -> void:
	AudioManager.set_script(SilentAudio)
	var map := Control.new()
	map.set_script(load("res://scripts/ui/constellation_map.gd"))
	add_child(map)
	map.set_transition(1.0)
	map.navigation_enabled = false
	var saved_progress: int = SaveManager.data.cleared_stage
	for cleared in range(6):
		SaveManager.data.cleared_stage = cleared
		map.focus_selection()
		for i in map._stars.size():
			check(map._stars[i].visible == (i <= cleared), "進行に応じて次の星座だけを解放する")
		check(map._final_stage.visible == (cleared >= 4), "第4ステージクリア後に最終ステージを表示する")
		check(map._page_button.visible == (cleared >= 4), "The down arrow follows final stage availability")
		for phase in map.STAR_PHASES.size():
			var layer: TextureRect = map._star_phases[phase]
			check(layer.visible == (phase <= cleared), "クリア進行%dで星レイヤー%dの表示を切り替える" % [cleared, phase + 1])
			check(layer.texture == map.STAR_PHASES[phase] and layer.position == Vector2.ZERO, "星を原画の位置に重ねる")
	SaveManager.data.cleared_stage = 0
	map.focus_selection()
	map.select_constellation(3)
	check(map._selected == 0 and map._nearest_visible_star(180.0) == 0 and map._horizontal_neighbor(1) == 0, "未解放ステージを直接指定・ドラッグ・キー操作で選べない")
	map._debug_unlock.button_pressed = true
	check(map._final_stage.visible and not map._star_phases[1].visible, "デバッグ全開放では進行の星を増やさない")
	var selection: Rect2 = map.SELECTION_RECT
	check(map._selection_frame.position == selection.position and map._selection_frame.size == selection.size, "黄色枠はDecorationsの原寸位置")
	check(map._preview.position == Vector2.ZERO and map._preview_stars.position == Vector2.ZERO, "絵と星の原点を一致させる")
	check(map._preview.size == Vector2(640,360) and map._preview_stars.size == Vector2(640,360), "右窓の絵を再拡大しない")
	var window := Rect2(447,83,143,92)
	for i in 4:
		map.select_constellation(i)
		await get_tree().create_timer(0.7).timeout
		var star: TextureButton = map._stars[i]
		var center: Vector2 = star.position + star.size * star.scale * 0.5
		check(center.is_equal_approx(selection.get_center()), "選択されたアイコンが黄色枠の中心に来る")
		var used := star.texture_normal.get_image().get_used_rect()
		check(selection.encloses(Rect2(star.position + Vector2(used.position) * star.scale, Vector2(used.size) * star.scale)), "アイコン%dの描画部分が黄色枠に収まる" % i)
		check(map._preview.texture == map.PREVIEW_ART[i] and map._preview_stars.texture == map.PREVIEW_STARS[i], "選択したステージの絵と星を切り替える")
		for texture: Texture2D in [map._preview.texture, map._preview_stars.texture]:
			check(window.encloses(Rect2(texture.get_image().get_used_rect())), "右窓の原画が窓の内側に収まる")
	map._page_button.pressed.emit()
	check(not map._selection_frame.visible and map._preview.texture == null and map._preview_stars.texture == null, "円外の最終ステージでは四星座の選択表示を消す")
	await get_tree().create_timer(0.7).timeout
	check(map._selected == 4 and map._map_content.position.y == -map.DRAGON_SCROLL, "The down arrow scrolls to the final stage")
	check(map._dragon_frame.visible and map._dragon_preview.visible and map._page_arrow.flip_v, "The final stage displays its artwork and return arrow")
	map._page_button.pressed.emit()
	await get_tree().create_timer(0.7).timeout
	check(map._selected == 3 and map._map_content.position.y == 0.0, "The up arrow restores the previous constellation")
	map._page_button.pressed.emit()
	map._debug_unlock.button_pressed = false
	check(map._selected == 0 and not map._final_stage.visible and not map._stars[1].visible, "全開放を解除して通常進行に戻す")
	check(SaveManager.data.cleared_stage == 0, "デバッグ全開放で進行を書き換えない")
	SaveManager.data.cleared_stage = saved_progress
	map.queue_free()
	await get_tree().process_frame
	print("[selection_art] failures=", failed)
	get_tree().quit(1 if failed else 0)
