## 実行画面と2D編集Inspectorで共用する炎の操作部。
@tool
extends ScrollContainer

const LABELS := {
	"emission_shape": "形", "source_size": "発生源", "birth_rate": "発生/秒",
	"lifetime": "寿命", "rise_speed": "上昇", "sway": "横揺れ", "particle_size": "粒半径",
	"capacity": "粒上限", "layer_rates": "発生量", "layer_lifetimes": "寿命比",
	"layer_sizes": "大きさ比", "outer_color": "外炎", "inner_color": "内炎", "core_color": "芯",
	"field_size": "描画域", "density_pixel_size": "密度解像", "merge_threshold": "結合",
	"edge_softness": "縁", "deformation": "変形", "pixel_size": "ドット",
	"update_fps": "更新FPS", "glow_strength": "発光量", "glow_radius": "発光径",
}
const MAIN_KEYS := ["emission_shape", "source_size", "birth_rate", "lifetime", "rise_speed", "sway"]
const PARTICLE_KEYS := ["particle_size", "capacity"]
const LAYER_KEYS := ["layer_rates", "layer_lifetimes", "layer_sizes", "outer_color", "inner_color", "core_color"]
const SHAPE_KEYS := ["field_size", "density_pixel_size", "merge_threshold", "edge_softness", "deformation", "pixel_size", "update_fps", "glow_strength", "glow_radius"]

var preview: Control
var fields := VBoxContainer.new()
var _status: Label
var _expanded := {"scene": false, "particle": false, "layers": false, "shape": false}
var _grids: Array[GridContainer] = []

func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields.add_theme_constant_override("separation", 4)
	add_child(fields)

func _process(_delta: float) -> void:
	_fit_columns()
	if is_instance_valid(preview) and is_instance_valid(_status) and _status.text != preview.status:
		_status.text = preview.status
		_status.tooltip_text = preview.status

func bind_preview(value: Control) -> void:
	preview = value
	refresh()

func _reload() -> void:
	if preview.request_reload.is_valid():
		preview.request_reload.call(preview.reload_preset)
	else:
		preview.reload_preset()

func refresh() -> void:
	if not is_instance_valid(preview) or preview.settings == null:
		return
	for child in fields.get_children():
		fields.remove_child(child)
		child.queue_free()
	_grids.clear()
	var transport := _row(fields)
	_transport_button(transport, "⏮", "同じ設定で先頭から再実行", preview.restart)
	_transport_button(transport, "▶", "再生。停止後や燃焼終了後は先頭から再開", preview.play)
	_transport_button(transport, "⏸", "一時停止。続きから再生できます", preview.pause)
	_transport_button(transport, "⏹", "停止して先頭へ戻す", preview.stop)
	_transport_button(transport, "⏭", "停止して1コマ進む", preview.step)
	var speed := Button.new()
	speed.text = "⏩%sx" % str(preview.playback_speed)
	speed.tooltip_text = "再生速度を1倍・2倍・4倍で切り替え"
	transport.add_child(speed)
	speed.pressed.connect(func():
		preview.set_speed(2.0 if preview.playback_speed == 1.0 else (4.0 if preview.playback_speed == 2.0 else 1.0))
		speed.text = "⏩%sx" % str(preview.playback_speed))
	_status = Label.new()
	_status.text = preview.status
	_status.tooltip_text = preview.status
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	fields.add_child(_status)
	var preset_row := _row(fields)
	var presets := OptionButton.new()
	presets.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	presets.fit_to_longest_item = false
	presets.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	presets.tooltip_text = "保存済みの炎設定を選んで読み込む"
	var paths: Array[String] = preview.preset_paths()
	for i in paths.size():
		presets.add_item(paths[i].get_file().get_basename())
		presets.set_item_metadata(i, paths[i])
		if paths[i] == preview.preset_path:
			presets.selected = i
	presets.item_selected.connect(func(index):
		preview.preset_path = presets.get_item_metadata(index)
		_reload())
	preset_row.add_child(presets)
	_button(preset_row, "読込", "選択した保存済み設定を再読込。未保存の調整は破棄します", _reload)
	var save := _button(preset_row, "保存", "現在の設定パスへ調整値を保存", preview.save_preset)
	save.visible = preview.controls_host == null
	var copy_row := _row(fields)
	var copy := LineEdit.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.text = preview.copy_path
	copy.tooltip_text = "複製先の新しい res://data/visuals/*.tres パス"
	copy.text_changed.connect(func(value): preview.copy_path = value)
	copy_row.add_child(copy)
	_button(copy_row, "複製", "別名で複製保存して切り替える", preview.save_copy)
	var png_row := _row(fields)
	var png := LineEdit.new()
	png.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	png.text = preview.png_path
	png.tooltip_text = "現在の1コマを透明 PNG に出力。設定の .tres 保存とは別です"
	png.text_changed.connect(func(value): preview.png_path = value)
	png_row.add_child(png)
	_button(png_row, "出力確認", "移動・回転・配置倍率・参照絵を除いた実際の PNG を確認してから書き出す", preview.request_png_preview)
	_scene_section()
	var props := _properties()
	_label(fields, "形・動き")
	_property_grid(fields, MAIN_KEYS, props)
	var time_row := _grid(fields)
	_number(time_row, "発生秒", "0=連続。変更後は先頭から再実行", preview.emission_seconds, "0,3,0.05", func(v): preview.emission_seconds = v)
	_number(time_row, "seed", "同じ炎を再現する乱数値。変更後は先頭から再実行", preview.seed_value, "0,99999,1", func(v): preview.seed_value = int(v))
	_property_grid(_section("粒子詳細", "particle"), PARTICLE_KEYS, props)
	_property_grid(_section("炎の層・色", "layers"), LAYER_KEYS, props)
	_property_grid(_section("輪郭・発光", "shape"), SHAPE_KEYS, props)
	_fit_columns()

func _fit_columns() -> void:
	var narrow := get_viewport_rect().size.x < 800.0 or (size.x > 0.0 and size.x < 320.0)
	for grid in _grids:
		if is_instance_valid(grid):
			grid.columns = 1 if narrow else 2

func _scene_section() -> void:
	var section := _section("場面・配置", "scene")
	var context_row := _row(section)
	var stages := OptionButton.new()
	stages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stages.fit_to_longest_item = false
	stages.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stages.tooltip_text = "合成確認するステージ"
	for name in DirAccess.get_files_at("res://data/stages"):
		if name.ends_with(".tres"):
			var path := "res://data/stages/" + name
			stages.add_item(name.get_basename())
			stages.set_item_metadata(stages.item_count - 1, path)
			if path == preview.context_stage_path:
				stages.selected = stages.item_count - 1
	stages.item_selected.connect(func(index):
		preview.select_context(stages.get_item_metadata(index), 0)
		refresh())
	context_row.add_child(stages)
	var targets := OptionButton.new()
	targets.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	targets.fit_to_longest_item = false
	targets.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	targets.tooltip_text = "ステージ内の背景配置"
	for i in preview._context_items.size():
		var item: BackgroundPlacement = preview._context_items[i]
		targets.add_item("%d: %s" % [i + 1, item.texture.resource_path.get_file() if item.texture != null else "画像なし"])
	if targets.item_count > 0:
		targets.selected = preview.context_target
	else:
		targets.add_item("背景なし")
		targets.disabled = true
	targets.item_selected.connect(func(index):
		preview.select_context(preview.context_stage_path, index)
		refresh())
	context_row.add_child(targets)
	var subject_row := _row(section)
	var subject := LineEdit.new()
	subject.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subject.placeholder_text = "敵・装甲・normal の PNG"
	subject.tooltip_text = "プロジェクト内の PNG を何枚でも追加。参照絵は炎の設定と出力に含めません"
	subject.text_submitted.connect(preview.select_subject)
	subject_row.add_child(subject)
	_button(subject_row, "追加", "参照 PNG を追加して選択", preview.choose_subject)
	var edit_row := _row(section)
	var selected := OptionButton.new()
	selected.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selected.fit_to_longest_item = false
	selected.add_item("炎")
	for sprite in preview.reference_sprites:
		selected.add_item(sprite.name)
	selected.selected = preview.selected_reference + 1
	selected.tooltip_text = "重なった絵もここから選択。キャンバス上ではクリックで選択、ドラッグで移動"
	selected.item_selected.connect(preview.select_edit_item)
	edit_row.add_child(selected)
	_button(edit_row, "戻す", "選択物の移動・回転・配置倍率を初期値へ戻す", preview.reset_edit_transform)
	var remove := _button(edit_row, "削除", "選択した参照 PNG だけを取り除く", preview.remove_selected_reference)
	remove.disabled = preview.selected_reference < 0
	var place := _grid(section)
	_number(place, "表示", "キャンバスだけのズーム。ホイールでも調整。PNG 出力には反映しません", preview.preview_zoom, "0.1,8,0.1", func(v): preview.preview_zoom = v; preview._view_dirty = true)
	_number(place, "倍率", "選択物の配置倍率。炎の PNG 出力サイズは形の設定で調整", preview.edit_scale(), "0.1,8,0.05", preview.set_edit_scale)
	_number(place, "X", "選択物の表示位置。キャンバス上でドラッグ可能", preview.edit_position().x, "-2048,2048,1", func(v): preview.set_edit_position(Vector2(v, preview.edit_position().y)))
	_number(place, "Y", "選択物の表示位置。キャンバス上でドラッグ可能", preview.edit_position().y, "-2048,2048,1", func(v): preview.set_edit_position(Vector2(preview.edit_position().x, v)))
	_number(place, "回転", "選択物の表示だけの角度。Shift+ホイールでも調整", preview.edit_rotation(), "-360,360,1", preview.set_edit_rotation)
	_number(place, "パンX", "キャンバスの横移動。中ボタンドラッグでも調整", preview.view_pan.x, "-2048,2048,1", func(v): preview.view_pan.x = v; preview._view_dirty = true)
	_number(place, "パンY", "キャンバスの縦移動。中ボタンドラッグでも調整", preview.view_pan.y, "-2048,2048,1", func(v): preview.view_pan.y = v; preview._view_dirty = true)
	_button(section, "選択背景へ配置保存", "保存済みの炎設定と位置・倍率を選択背景へ割り当てる", preview.save_usage)
	var use_row := _row(section)
	var uses := OptionButton.new()
	uses.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	uses.fit_to_longest_item = false
	uses.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	uses.add_item("新しい用途")
	var names: Array[String] = preview.world_usage_names()
	for name in names:
		uses.add_item(name)
		if name == preview.usage_name:
			uses.selected = uses.item_count - 1
	uses.item_selected.connect(func(index):
		if index > 0:
			preview.load_world_usage(names[index - 1])
		else:
			preview.usage_name = "")
	use_row.add_child(uses)
	var use_name := LineEdit.new()
	use_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	use_name.placeholder_text = "用途名"
	use_name.text = preview.usage_name
	use_name.text_changed.connect(func(value): preview.usage_name = value)
	use_row.add_child(use_name)
	_button(section, "固定位置へ配置保存", "用途名でステージ開始地点からの固定位置へ炎を保存", preview.save_world_usage)

func _properties() -> Dictionary:
	var out := {}
	for property in preview.settings.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.usage & PROPERTY_USAGE_EDITOR:
			out[property.name] = property
	return out

func _property_grid(parent: Control, keys: Array, properties: Dictionary) -> void:
	var grid := _grid(parent)
	for key in keys:
		if not properties.has(key):
			continue
		var property: Dictionary = properties[key]
		var current: Variant = preview.settings.get(key)
		var label: String = LABELS.get(key, key)
		if property.hint == PROPERTY_HINT_ENUM:
			var row := _row(grid)
			_label(row, label)
			var choice := OptionButton.new()
			choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for name in ["点", "線", "箱"]:
				choice.add_item(name)
			choice.selected = int(current)
			choice.item_selected.connect(func(index): preview.settings.set(key, index))
			row.add_child(choice)
		elif current is float or current is int:
			_number(grid, label, key, current, property.hint_string, func(v): preview.settings.set(key, int(v) if current is int else v))
		elif current is Color:
			var color_row := _row(grid)
			_label(color_row, label)
			var picker := ColorPickerButton.new()
			picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			picker.color = current
			picker.color_changed.connect(func(v): preview.settings.set(key, v))
			color_row.add_child(picker)
		elif current is Vector2 or current is Vector3:
			for axis in (2 if current is Vector2 else 3):
				var component: String = (["幅", "高"] if current is Vector2 else ["外", "内", "芯"])[axis]
				var hint := "0,4,0.05" if current is Vector3 else "0,1024,1"
				if key == "field_size":
					hint = "32,1024,1" if axis == 0 else "64,1024,1"
				_number(grid, label + component, key, current[axis], hint, func(v):
					var vector: Variant = preview.settings.get(key)
					vector[axis] = v
					preview.settings.set(key, vector))

func _section(title: String, key: String) -> VBoxContainer:
	var head := Button.new()
	head.flat = true
	head.alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.text = ("▾ " if _expanded.get(key, false) else "▸ ") + title
	fields.add_child(head)
	var body := VBoxContainer.new()
	body.visible = bool(_expanded.get(key, false))
	body.add_theme_constant_override("separation", 4)
	fields.add_child(body)
	head.pressed.connect(func():
		_expanded[key] = not bool(_expanded.get(key, false))
		body.visible = _expanded[key]
		head.text = ("▾ " if body.visible else "▸ ") + title)
	return body

func _row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	return row

func _grid(parent: Control) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 1 if get_viewport_rect().size.x < 800.0 else 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	parent.add_child(grid)
	_grids.append(grid)
	return grid

func _label(parent: Control, value: String) -> Label:
	var label := Label.new()
	label.text = value
	parent.add_child(label)
	return label

func _button(parent: Control, value: String, tip: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.tooltip_text = tip
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _transport_button(parent: Control, icon: String, tip: String, action: Callable) -> void:
	var button := _button(parent, icon, tip, action)
	button.custom_minimum_size.x = 31

func _number(parent: Control, label: String, tip: String, value: float, hint: String, action: Callable) -> void:
	var row := _row(parent)
	var name := _label(row, label)
	name.tooltip_text = tip
	var input := SpinBox.new()
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.custom_minimum_size.x = 68
	input.tooltip_text = tip
	var bounds := hint.split(",")
	input.min_value = float(bounds[0]) if bounds.size() > 1 else 0.0
	input.max_value = float(bounds[1]) if bounds.size() > 1 else 1024.0
	input.step = float(bounds[2]) if bounds.size() > 2 else 0.05
	input.value = value
	input.value_changed.connect(action)
	row.add_child(input)
