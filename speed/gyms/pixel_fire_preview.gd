## 独立した炎の編集用。調整値は複製して保持し、明示保存でプリセットへ反映する。
## @tool / Inspector buttons: https://docs.godotengine.org/en/4.6/tutorials/plugins/running_code_in_the_editor.html
@tool
extends Control

const DEFAULT_PRESET := "res://data/visuals/pixel_fire.tres"
const PANEL := preload("res://gyms/pixel_fire_controls.gd")

@export_file("*.tres") var preset_path := DEFAULT_PRESET
@export_tool_button("▶ 炎の制作画面を開く") var open_editor_action = open_editor
@export_tool_button("選択したプリセットを読み込む") var load_action = reload_preset
@export_custom(PROPERTY_HINT_RESOURCE_TYPE, "PixelFireSettings", PROPERTY_USAGE_EDITOR)
var settings: PixelFireSettings:
	set(value):
		if settings != null and settings.changed.is_connected(_changed):
			settings.changed.disconnect(_changed)
		settings = value.duplicate() if value != null else PixelFireSettings.new()
		settings.changed.connect(_changed)
		if is_instance_valid(fire):
			fire.settings = settings
		_changed()
@export_tool_button("調整値を保存") var save_action = save_preset
@export_file("*.tres") var copy_path := "res://data/visuals/pixel_fire_custom.tres"
@export_tool_button("別名で複製保存して切り替える") var copy_action = save_copy
@export_group("再生")
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var playing := true
var stopped := false
var playback_speed := 1.0
## 0は連続燃焼。正の秒数で発生を止め、残った炎を消す。
@export_range(0.0, 3.0, 0.05) var emission_seconds := 0.0
@export var seed_value := 42
@export_tool_button("同じ設定で先頭から再実行") var restart_action = restart
@export_tool_button("停止して1コマ進む") var step_action = step
@export_custom(PROPERTY_HINT_MULTILINE_TEXT, "", PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY)
var status := ""

var fire: PixelFire
var stage: SubViewport
var context_root: Node2D
var context_stage_path := "res://data/stages/stage_4.tres"
var context_target := 0
var preview_zoom := 1.0
var view_pan := Vector2.ZERO
var usage_offset := Vector2.ZERO
var usage_scale := 1.0
var fire_rotation := 0.0
var usage_name := ""
var _context_stage: StageDef
var _context_hash := ""
var _context_items: Array[BackgroundPlacement] = []
var subject_path := ""
var subject_sprite: Sprite2D
var reference_sprites: Array[Sprite2D] = []
var selected_reference := -1 # -1 は炎。参照画像は制作中だけ保持する。
var _dragging := false
var _panning := false
var _subject_dialog: FileDialog
var png_path := "res://data/visuals/pixel_fire_frame.png"
var _export_dialog: ConfirmationDialog
var _export_image: Image
var _export_preview: TextureRect
var _loaded_path := ""
var _source_hash := ""
var _panel: Control
var _status_label: Label
var _view_dirty := true
var dirty := false
# 統合画面では既存の描画と操作部を別々の列へ配置する。
var preview_host: Control
var controls_host: Control
var request_reload: Callable

func open_editor() -> void:
	EditorInterface.play_custom_scene("res://gyms/visual_editor.tscn")

func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	margin.visible = controls_host == null
	var split := HSplitContainer.new()
	margin.add_child(split)
	if not Engine.is_editor_hint():
		_panel = PANEL.new()
		_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		(controls_host if controls_host != null else split).add_child(_panel)
	var right := VBoxContainer.new()
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(preview_host if preview_host != null else split).add_child(right)
	var title := Label.new()
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.text = "炎プレビュー"
	title.tooltip_text = "粒子から密度・色面・発光を作る PixelFire"
	right.add_child(title)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.gui_input.connect(_canvas_input)
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(container)
	stage = SubViewport.new()
	stage.size = Vector2i(640, 480)
	stage.disable_3d = true
	stage.world_2d = World2D.new()
	stage.render_target_update_mode = SubViewport.UPDATE_ONCE
	container.add_child(stage)
	var background := ColorRect.new()
	background.color = Color("10141e")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(background)
	context_root = Node2D.new()
	stage.add_child(context_root)
	_subject_dialog = FileDialog.new()
	_subject_dialog.access = FileDialog.ACCESS_RESOURCES
	_subject_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_subject_dialog.filters = PackedStringArray(["*.png ; PNG"])
	_subject_dialog.file_selected.connect(select_subject)
	add_child(_subject_dialog)
	_export_dialog = ConfirmationDialog.new()
	_export_dialog.title = "透明 PNG の書き出し確認"
	_export_dialog.ok_button_text = "この画像を書き出す"
	_export_dialog.confirmed.connect(_write_png)
	var preview_box := Control.new()
	preview_box.custom_minimum_size = Vector2(320, 320)
	var checker := Image.create(320, 320, false, Image.FORMAT_RGBA8)
	for y in 320:
		for x in 320:
			checker.set_pixel(x, y, Color("47505a") if (floori(x / 16.0) + floori(y / 16.0)) % 2 == 0 else Color("303943"))
	var checker_rect := TextureRect.new()
	checker_rect.texture = ImageTexture.create_from_image(checker)
	checker_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_box.add_child(checker_rect)
	_export_preview = TextureRect.new()
	_export_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_export_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_export_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_box.add_child(_export_preview)
	_export_dialog.add_child(preview_box)
	add_child(_export_dialog)
	fire = PixelFire.new()
	fire.manual = true
	stage.add_child(fire)
	stage.size_changed.connect(func(): _view_dirty = true)
	_status_label = Label.new()
	_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	right.add_child(_status_label)
	_status_label.visible = controls_host == null
	settings = PixelFireSettings.new()
	reload_preset()
	select_context(context_stage_path, context_target)
	if is_instance_valid(_panel):
		_panel.bind_preview(self)
	_set_status(status)

func _process(dt: float) -> void:
	if not is_instance_valid(fire) or not is_visible_in_tree():
		return
	# 編集中のシーンだけを進める。非表示タブと停止中は密度場を更新しない。
	if Engine.is_editor_hint() and get_tree().edited_scene_root != self:
		return
	if _view_dirty:
		_view_dirty = false
		_layout_context()
		stage.render_target_update_mode = SubViewport.UPDATE_ONCE
	if playing:
		var before := fire.density_render_count
		fire.advance(dt * playback_speed)
		if fire.density_render_count != before:
			stage.render_target_update_mode = SubViewport.UPDATE_ONCE

func _changed() -> void:
	dirty = true
	_view_dirty = true
	_set_status("未保存の調整値 / 保存先: " + _loaded_path)

func _set_status(value: String) -> void:
	status = value
	if is_instance_valid(_status_label):
		_status_label.text = value
		_status_label.tooltip_text = value

func restart() -> void:
	if not is_instance_valid(fire):
		return
	fire.restart(seed_value, emission_seconds if emission_seconds > 0.0 else -1.0)
	stopped = false
	_view_dirty = true

func step() -> void:
	playing = false
	if is_instance_valid(fire):
		if stopped or fire.finished():
			restart()
		fire.advance(1.0 / maxf(1.0, settings.update_fps))
		_view_dirty = true

func stop() -> void:
	playing = false
	if is_instance_valid(fire):
		fire.restart(seed_value, emission_seconds if emission_seconds > 0.0 else -1.0)
	stopped = true
	_view_dirty = true

func play() -> void:
	if stopped or fire.finished():
		restart()
	playing = true

func pause() -> void:
	playing = false

func set_speed(value: float) -> void:
	playback_speed = value

func preset_paths() -> Array[String]:
	var paths: Array[String] = []
	for name in DirAccess.get_files_at("res://data/visuals"):
		if name.ends_with(".tres"):
			var path := "res://data/visuals/" + name
			if ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) is PixelFireSettings:
				paths.append(path)
	paths.sort()
	return paths

func select_context(path: String, target: int) -> void:
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as StageDef
	if loaded == null:
		_set_status("背景を読み込めません: " + path)
		return
	var old_center := _context_items[context_target].offset if context_target < _context_items.size() else Vector2.ZERO
	var references: Array[Dictionary] = []
	for sprite in reference_sprites:
		if is_instance_valid(sprite):
			references.append({"path": sprite.texture.resource_path, "offset": sprite.position - old_center,
				"rotation": sprite.rotation_degrees, "scale": sprite.scale})
	if path != context_stage_path:
		usage_name = ""
	context_stage_path = path
	_context_stage = loaded
	_context_hash = FileAccess.get_md5(path)
	_context_items = loaded.backgrounds
	context_target = clampi(target, 0, maxi(0, _context_items.size() - 1))
	if context_target < _context_items.size():
		usage_offset = _context_items[context_target].fire_offset
		usage_scale = _context_items[context_target].fire_scale
		if not dirty and not _context_items[context_target].fire_preset_path.is_empty():
			preset_path = _context_items[context_target].fire_preset_path
			reload_preset()
	else:
		usage_offset = Vector2.ZERO
		usage_scale = 1.0
	for child in context_root.get_children():
		child.queue_free()
	reference_sprites.clear()
	for item in _context_items:
		if item.texture == null:
			continue
		var sprite := Sprite2D.new()
		sprite.texture = item.texture
		var used := Rect2(item.texture.get_image().get_used_rect())
		if used.size != Vector2.ZERO:
			sprite.region_enabled = true
			sprite.region_rect = used
		sprite.position = item.offset
		sprite.scale = Vector2.ONE * item.scale
		sprite.rotation_degrees = item.rotation_degrees
		sprite.modulate = item.display_tint()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		context_root.add_child(sprite)
	for reference in references:
		if not _add_reference_sprite(reference.path, false):
			continue
		var sprite: Sprite2D = reference_sprites.back()
		var new_center := _context_items[context_target].offset if context_target < _context_items.size() else Vector2.ZERO
		sprite.position = new_center + reference.offset
		sprite.rotation_degrees = reference.rotation
		sprite.scale = reference.scale
	selected_reference = mini(selected_reference, reference_sprites.size() - 1)
	_view_dirty = true
	_set_status("背景: " + path.get_file().get_basename() + " / 対象 %d" % (context_target + 1))

func choose_subject() -> void:
	_subject_dialog.popup_centered_ratio(0.75)

func select_subject(path: String) -> void:
	if path.is_empty():
		return
	if not path.begins_with("res://") or not path.to_lower().ends_with(".png"):
		_set_status("対象画像にはプロジェクト内の PNG を選択してください。")
		return
	_add_reference_sprite(path, true)
	_view_dirty = true
	if is_instance_valid(_panel):
		_panel.refresh()

func _add_reference_sprite(path: String, select: bool) -> bool:
	var texture := ResourceLoader.load(path) as Texture2D
	if texture == null:
		_set_status("対象画像を読み込めません: " + path)
		return false
	var sprite := Sprite2D.new()
	sprite.name = path.get_file().get_basename()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = _context_items[context_target].offset if context_target < _context_items.size() else Vector2.ZERO
	context_root.add_child(sprite)
	reference_sprites.append(sprite)
	subject_sprite = sprite
	subject_path = path
	if select:
		selected_reference = reference_sprites.size() - 1
		_set_status("参照画像を追加: " + path.get_file())
	return true

func select_edit_item(index: int) -> void:
	selected_reference = index - 1
	if is_instance_valid(_panel):
		_panel.refresh()

func remove_selected_reference() -> void:
	if selected_reference < 0 or selected_reference >= reference_sprites.size():
		return
	reference_sprites[selected_reference].queue_free()
	reference_sprites.remove_at(selected_reference)
	selected_reference = -1
	subject_sprite = reference_sprites.back() if not reference_sprites.is_empty() else null
	subject_path = subject_sprite.texture.resource_path if is_instance_valid(subject_sprite) else ""
	if is_instance_valid(_panel):
		_panel.refresh()

func edit_position() -> Vector2:
	if selected_reference < 0 or selected_reference >= reference_sprites.size():
		return usage_offset
	var center := _context_items[context_target].offset if context_target < _context_items.size() else Vector2.ZERO
	return reference_sprites[selected_reference].position - center

func edit_rotation() -> float:
	return fire_rotation if selected_reference < 0 else reference_sprites[selected_reference].rotation_degrees

func edit_scale() -> float:
	return usage_scale if selected_reference < 0 else reference_sprites[selected_reference].scale.x

func set_edit_position(offset: Vector2) -> void:
	if selected_reference < 0:
		usage_offset = offset
	else:
		var center := _context_items[context_target].offset if context_target < _context_items.size() else Vector2.ZERO
		reference_sprites[selected_reference].position = center + offset
	_view_dirty = true

func set_edit_rotation(degrees: float) -> void:
	if selected_reference < 0:
		fire_rotation = degrees
	else:
		reference_sprites[selected_reference].rotation_degrees = degrees
	_view_dirty = true

func set_edit_scale(value: float) -> void:
	if selected_reference < 0:
		usage_scale = value
	else:
		reference_sprites[selected_reference].scale = Vector2.ONE * value
	_view_dirty = true

func reset_edit_transform() -> void:
	set_edit_position(Vector2.ZERO)
	set_edit_rotation(0.0)
	set_edit_scale(1.0)
	if is_instance_valid(_panel):
		_panel.refresh()

func _layout_context() -> void:
	var center := Vector2.ZERO
	if context_target < _context_items.size():
		center = _context_items[context_target].offset
	context_root.position = Vector2(stage.size) * 0.5 + view_pan - center * preview_zoom
	context_root.scale = Vector2.ONE * preview_zoom
	fire.position = context_root.position + (center + usage_offset) * preview_zoom
	fire.scale = Vector2.ONE * usage_scale * preview_zoom
	fire.rotation_degrees = fire_rotation

func _canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				var direction := 1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
				if event.shift_pressed:
					set_edit_rotation(edit_rotation() + direction * 5.0)
				else:
					preview_zoom = clampf(preview_zoom * (1.1 if direction > 0.0 else 1.0 / 1.1), 0.1, 8.0)
					_view_dirty = true
				if is_instance_valid(_panel): _panel.refresh()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			if event.pressed:
				selected_reference = -1
				for index in range(reference_sprites.size() - 1, -1, -1):
					var sprite := reference_sprites[index]
					if is_instance_valid(sprite) and sprite.get_rect().has_point(sprite.to_local(event.position)):
						selected_reference = index
						break
				if is_instance_valid(_panel): _panel.refresh()
			accept_event()
	elif event is InputEventMouseMotion:
		if _panning:
			view_pan += event.relative
			_view_dirty = true
			accept_event()
		elif _dragging:
			set_edit_position(edit_position() + event.relative / preview_zoom)
			accept_event()

func request_png_preview() -> void:
	if not png_path.begins_with("res://") or not png_path.to_lower().ends_with(".png"):
		_set_status("PNG の保存先にはプロジェクト内の .png パスを指定してください。")
		return
	var output_size := Vector2i(settings.field_size.clamp(Vector2(32, 64), Vector2(1024, 1024)).ceil())
	var was_playing := playing
	playing = false
	var capture := SubViewport.new()
	capture.size = output_size
	capture.transparent_bg = true
	capture.disable_3d = true
	capture.world_2d = World2D.new()
	capture.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(capture)
	var source := PixelFire.new()
	source.manual = true
	source.settings = settings.duplicate(true)
	capture.add_child(source)
	await get_tree().process_frame
	source.position = Vector2(output_size.x * 0.5, output_size.y - 40.0)
	source.particles = fire.particles.duplicate(true)
	source._clock = fire._clock
	source._render_density()
	for frame in 3:
		await RenderingServer.frame_post_draw
	_export_image = capture.get_texture().get_image()
	_export_image.convert(Image.FORMAT_RGBA8)
	# 実行時の加算発光シェーダーは黒の領域にも微量の Alpha を書く。
	# PNG では色が全くない背景だけを完全透明に戻す。
	for y in output_size.y:
		for x in output_size.x:
			var color := _export_image.get_pixel(x, y)
			if color.r == 0.0 and color.g == 0.0 and color.b == 0.0 and color.a < 0.04:
				_export_image.set_pixel(x, y, Color.TRANSPARENT)
	capture.queue_free()
	playing = was_playing
	_export_preview.texture = ImageTexture.create_from_image(_export_image)
	_export_dialog.dialog_text = "%d×%d px / 透明背景 / 現在の1コマ\n参照画像・配置の移動/回転/倍率・表示ズームは含めません。\n%s" % [output_size.x, output_size.y, png_path]
	_export_dialog.popup_centered(Vector2i(440, 430))

func _write_png() -> void:
	if _export_image == null:
		return
	var error := _export_image.save_png(ProjectSettings.globalize_path(png_path))
	if error == OK:
		_set_status("透明 PNG を書き出しました: " + png_path)
		if Engine.is_editor_hint(): EditorInterface.get_resource_filesystem().scan()
	else:
		_set_status("PNG の書き出しに失敗しました: " + error_string(error))

func world_usage_names() -> Array[String]:
	var names: Array[String] = []
	if _context_stage != null:
		for name in _context_stage.fire_uses:
			names.append(str(name))
	names.sort()
	return names

func load_world_usage(name: String) -> void:
	if _context_stage == null or not _context_stage.fire_uses.has(name):
		return
	usage_name = name
	var use: Dictionary = _context_stage.fire_uses[name]
	var center := _context_items[context_target].offset if context_target < _context_items.size() else Vector2.ZERO
	var offset: Vector2 = use.get("offset", Vector2.ZERO)
	usage_offset = offset - center
	usage_scale = float(use.get("scale", 1.0))
	if not dirty:
		preset_path = str(use.get("preset", ""))
		reload_preset()
	_view_dirty = true
	if is_instance_valid(_panel):
		_panel.refresh()

func save_world_usage() -> void:
	var name := usage_name.strip_edges()
	if name.is_empty() or _context_stage == null or dirty or _loaded_path.is_empty():
		_set_status("用途名を付け、炎設定を保存してから固定位置へ割り当ててください。")
		return
	if FileAccess.get_md5(context_stage_path) != _context_hash or FileAccess.get_md5(_loaded_path) != _source_hash:
		_set_status("設定またはステージが外部で変更されています。再読込してください。")
		return
	var uses: Dictionary = _context_stage.fire_uses.duplicate(true)
	var center := _context_items[context_target].offset if context_target < _context_items.size() else Vector2.ZERO
	uses[name] = {"preset": _loaded_path, "offset": center + usage_offset, "scale": usage_scale}
	var source := FileAccess.get_file_as_string(context_stage_path)
	var line := "fire_uses = " + var_to_str(uses).replace("\n", " ")
	var key_at := source.find("\nfire_uses = ")
	var updated := ""
	if key_at >= 0:
		var end := source.find("\n", key_at + 1)
		if end < 0 or not source.substr(key_at + 1, end - key_at - 1).strip_edges().ends_with("}"):
			_set_status("ステージの用途一覧が複数行のため、保存形式を確認してください。")
			return
		updated = source.substr(0, key_at + 1) + line + source.substr(end)
	else:
		var resource_at := source.find("\n[resource]\n")
		if resource_at < 0:
			_set_status("ステージの Resource 節を特定できません。")
			return
		var script_end := source.find("\n", resource_at + "\n[resource]\n".length())
		if script_end < 0:
			_set_status("ステージのスクリプト行を特定できません。")
			return
		updated = source.substr(0, script_end + 1) + line + "\n" + source.substr(script_end + 1)
	if not _write_stage_text(updated):
		return
	_context_stage.fire_uses = uses
	usage_name = name
	_set_status("固定位置の使用箇所へ保存しました: " + name)
	if is_instance_valid(_panel):
		_panel.refresh()

func _write_stage_text(updated: String) -> bool:
	var absolute := ProjectSettings.globalize_path(context_stage_path)
	var temp := absolute + ".fire-tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		_set_status("使用箇所の一時保存に失敗しました。")
		return false
	file.store_string(updated)
	file.flush()
	file.close()
	var error := DirAccess.rename_absolute(temp, absolute)
	if error != OK:
		DirAccess.remove_absolute(temp)
		_set_status("使用箇所の保存に失敗しました: " + error_string(error))
		return false
	_context_hash = FileAccess.get_md5(context_stage_path)
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()
	return true

func save_usage() -> void:
	if _context_stage == null or context_target >= _context_items.size() or dirty or _loaded_path.is_empty():
		_set_status("先に炎の調整値を保存し、背景の対象を選択してください。")
		return
	if FileAccess.get_md5(context_stage_path) != _context_hash:
		_set_status("ステージが外部で変更されています。背景を再読込してください。")
		return
	if FileAccess.get_md5(_loaded_path) != _source_hash or ResourceLoader.load(_loaded_path, "", ResourceLoader.CACHE_MODE_IGNORE) is not PixelFireSettings:
		_set_status("保存済みの炎設定を読み込めません。")
		return
	var source := FileAccess.get_file_as_string(context_stage_path)
	var marker := "\nbackgrounds = "
	var list_at := source.find(marker)
	if list_at < 0:
		_set_status("背景配列が見つからないため保存できません。")
		return
	var list_end := source.find("\n", list_at + marker.length())
	var list_text := source.substr(list_at, list_end - list_at)
	var pattern := RegEx.new()
	pattern.compile('SubResource\\("([^"\\n]+)"\\)')
	var entries := pattern.search_all(list_text)
	if context_target >= entries.size():
		_set_status("背景の順序が変わったため保存できません。再読込してください。")
		return
	var section := '[sub_resource type="Resource" id="%s"]' % entries[context_target].get_string(1)
	var start := source.find(section)
	if start < 0:
		_set_status("対象背景を特定できません。")
		return
	var end := source.find("\n[", start + section.length())
	if end < 0:
		_set_status("対象背景の終端を特定できません。")
		return
	var kept := PackedStringArray()
	for line in source.substr(start, end - start).split("\n"):
		if not line.begins_with("fire_preset_path = ") and not line.begins_with("fire_offset = ") and not line.begins_with("fire_scale = "):
			kept.append(line)
	var insert := '\nfire_preset_path = "%s"' % _loaded_path
	insert += "\nfire_offset = Vector2(%s, %s)" % [str(usage_offset.x), str(usage_offset.y)]
	insert += "\nfire_scale = " + str(usage_scale)
	var updated := source.substr(0, start) + "\n".join(kept).strip_edges(false, true) + insert + "\n" + source.substr(end)
	var absolute := ProjectSettings.globalize_path(context_stage_path)
	var temp := absolute + ".fire-tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		_set_status("使用箇所の一時保存に失敗しました。")
		return
	file.store_string(updated)
	file.flush()
	file.close()
	var error := DirAccess.rename_absolute(temp, absolute)
	if error != OK:
		DirAccess.remove_absolute(temp)
		_set_status("使用箇所の保存に失敗しました: " + error_string(error))
		return
	var item := _context_items[context_target]
	item.fire_preset_path = _loaded_path
	item.fire_offset = usage_offset
	item.fire_scale = usage_scale
	_context_hash = FileAccess.get_md5(context_stage_path)
	_set_status("使用箇所へ保存しました: " + context_stage_path)
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()

func reload_preset() -> void:
	var path := preset_path.simplify_path()
	if not _valid_path(path) or not FileAccess.file_exists(path):
		_set_status("読込先には data/visuals 内の既存 .tres を指定してください。")
		return
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PixelFireSettings
	if loaded == null:
		_set_status("ピクセル炎の設定Resourceを読み込めません。")
		return
	_loaded_path = path
	_source_hash = FileAccess.get_md5(path)
	settings = loaded
	restart()
	notify_property_list_changed()
	if is_instance_valid(_panel):
		_panel.refresh()
	dirty = false
	_set_status("保存値を読み込みました: " + _loaded_path)

func save_preset() -> void:
	if _loaded_path.is_empty() or preset_path.simplify_path() != _loaded_path:
		_set_status("保存前に、選択したプリセットを読み込んでください。")
		return
	if FileAccess.get_md5(_loaded_path) != _source_hash:
		_set_status("保存先が外部で変更されています。再読込してから調整してください。")
		return
	_write_preset(_loaded_path)

func save_copy() -> void:
	var path := copy_path.simplify_path()
	if not _valid_path(path) or FileAccess.file_exists(path):
		_set_status("複製先には data/visuals 内の新しい .tres パスを指定してください。既存ファイルは保護します。")
		return
	if _write_preset(path):
		preset_path = path
		notify_property_list_changed()
		if is_instance_valid(_panel):
			_panel.refresh()

func _valid_path(path: String) -> bool:
	return path.begins_with("res://data/visuals/") and path.ends_with(".tres")

func _write_preset(path: String) -> bool:
	if settings == null:
		return false
	# 書き出すコピーだけにパスを付け、共有キャッシュと調整中Resourceを分離する。
	var error := ResourceSaver.save(settings.duplicate(), path)
	if error != OK:
		_set_status("保存に失敗しました: " + error_string(error))
		return false
	_loaded_path = path
	_source_hash = FileAccess.get_md5(path)
	dirty = false
	_set_status("保存しました: " + path)
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()
	return true

func editing_state() -> Dictionary:
	return {"path": _loaded_path, "dirty_paths": [_loaded_path] if dirty else [], "busy": false, "message": status}

func save_current() -> void:
	save_preset()

func reload_current() -> void:
	preset_path = _loaded_path
	reload_preset()

func set_active(active: bool) -> void:
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	stage.render_target_update_mode = SubViewport.UPDATE_ONCE if active else SubViewport.UPDATE_DISABLED
	if active:
		_view_dirty = true
