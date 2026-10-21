## 画像で選び、フィールドへ直接ドラッグできる敵パレット。
extends Button
const ICON := preload("res://gyms/enemy_lab/lab_icon.gd")
var definition: Resource
var picture: Texture2D

func _ready() -> void:
	toggle_mode = true
	custom_minimum_size = Vector2(88, 100)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	var art := ICON.new()
	art.texture = picture
	art.definition = definition
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(art)
	var label := Label.new()
	label.text = definition.display_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.custom_minimum_size.x = 72
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	# 星の数（区分）。ボスと、出現から外した敵・障害物（星0）には出さない
	if definition is EnemyDef and definition.rank > 0:
		var rank := Label.new()
		rank.text = "★%d" % definition.rank
		rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rank.add_theme_font_size_override("font_size", 11)
		rank.add_theme_color_override("font_color", Color("#ffd27a"))
		rank.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(rank)

func _get_drag_data(_position: Vector2):
	var preview := ICON.new()
	preview.texture = picture
	preview.definition = definition
	set_drag_preview(preview)
	return {"lab_enemy": String(definition.id)}
