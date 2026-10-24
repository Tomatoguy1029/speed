## F6用の操作部。編集画面はプレビューのInspectorで同じ設定と操作を使う。
extends ScrollContainer

const LABELS := {
	"emission_shape": "発生源の形", "source_size": "発生源の幅・高さ", "birth_rate": "発生数 / 秒",
	"lifetime": "基準の寿命", "rise_speed": "上昇速度", "sway": "横揺れ", "particle_size": "粒の半径",
	"capacity": "粒数の上限", "layer_rates": "外炎・内炎・芯の発生量", "layer_lifetimes": "各層の寿命倍率",
	"layer_sizes": "各層の大きさ倍率", "outer_color": "外炎の色", "inner_color": "内炎の色", "core_color": "芯の色",
	"field_size": "描画領域の幅・高さ", "density_pixel_size": "密度場の解像度倍率", "merge_threshold": "密度の結合境界",
	"edge_softness": "境界の柔らかさ", "deformation": "輪郭の変形", "pixel_size": "ドットの大きさ",
	"update_fps": "更新コマ数 / 秒", "glow_strength": "発光の強さ", "glow_radius": "発光の広がり",
}

var preview: Control
var fields := VBoxContainer.new()

func _ready() -> void:
	custom_minimum_size.x = 350
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(fields)

func bind_preview(value: Control) -> void:
	preview = value
	refresh()

func refresh() -> void:
	if not is_instance_valid(preview) or preview.settings == null:
		return
	for child in fields.get_children():
		fields.remove_child(child)
		child.queue_free()
	_label("ピクセル炎の調整")
	var path := LineEdit.new()
	path.text = preview.preset_path
	path.text_changed.connect(func(text): preview.preset_path = text)
	fields.add_child(path)
	_button("保存値を読み込む / 未保存値を破棄", preview.reload_preset)
	_button("調整値を保存", preview.save_preset)
	var copy := LineEdit.new()
	copy.text = preview.copy_path
	copy.text_changed.connect(func(text): preview.copy_path = text)
	fields.add_child(copy)
	_button("別名で複製保存して切り替える", preview.save_copy)
	var play := CheckButton.new()
	play.text = "再生"
	play.button_pressed = preview.playing
	play.toggled.connect(func(value): preview.playing = value)
	fields.add_child(play)
	_button("停止して1コマ進む", func(): preview.step(); play.button_pressed = false)
	_button("同じ設定で先頭から再実行", preview.restart)
	_number("発生時間 / 0=連続・変更後は再実行", preview.emission_seconds, "0,3,0.05", func(value): preview.emission_seconds = value)
	_number("乱数seed / 変更後は再実行", preview.seed_value, "0,99999,1", func(value): preview.seed_value = int(value))
	for property in preview.settings.get_property_list():
		var key: String = property.name
		if property.usage & PROPERTY_USAGE_GROUP and key != "Resource":
			_label(key)
		if not property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE or not property.usage & PROPERTY_USAGE_EDITOR:
			continue
		var current: Variant = preview.settings.get(key)
		var label: String = LABELS.get(key, key)
		if property.hint == PROPERTY_HINT_ENUM:
			_label(label)
			var choice := OptionButton.new()
			for text in ["点", "線", "箱"]:
				choice.add_item(text)
			choice.selected = int(current)
			choice.item_selected.connect(func(index): preview.settings.set(key, index))
			fields.add_child(choice)
		elif current is float or current is int:
			_number(label, current, property.hint_string, func(value): preview.settings.set(key, value))
		elif current is Color:
			_label(label)
			var picker := ColorPickerButton.new()
			picker.color = current
			picker.color_changed.connect(func(value): preview.settings.set(key, value))
			fields.add_child(picker)
		elif current is Vector2 or current is Vector3:
			for axis in (2 if current is Vector2 else 3):
				var component: String = (["幅", "高さ"] if current is Vector2 else ["外炎", "内炎", "芯"])[axis]
				var hint := "0,4,0.05" if current is Vector3 else "0,1024,1"
				if key == "field_size":
					hint = "32,1024,1" if axis == 0 else "64,1024,1"
				_number(label + " / " + component, current[axis], hint, func(value):
					var vector: Variant = preview.settings.get(key)
					vector[axis] = value
					preview.settings.set(key, vector))

func _label(text: String) -> void:
	var label := Label.new()
	label.text = text
	fields.add_child(label)

func _button(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	fields.add_child(button)

func _number(text: String, value: float, hint: String, action: Callable) -> void:
	_label(text)
	var input := SpinBox.new()
	var bounds := hint.split(",")
	input.min_value = float(bounds[0]) if bounds.size() > 1 else 0.0
	input.max_value = float(bounds[1]) if bounds.size() > 1 else 1024.0
	input.step = float(bounds[2]) if bounds.size() > 2 else 0.05
	input.value = value
	input.value_changed.connect(action)
	fields.add_child(input)
