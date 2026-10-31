## 通常3択と報酬の制作再生で共用するカード。抽選・付与・保存を扱わない。
extends RefCounted

const CARDS := preload("res://assets/ui/combat/combat_ui_boxes.png")
const ICONS := preload("res://scripts/ui/module_icons.gd")

static func apply_art(button: Button, region: Rect2) -> void:
	var texture := AtlasTexture.new()
	texture.atlas = CARDS
	texture.region = region
	var style := StyleBoxTexture.new()
	style.texture = texture
	button.add_theme_stylebox_override("normal", style)
	for state in ["hover", "pressed", "focus", "disabled"]:
		var variant := style.duplicate() as StyleBoxTexture
		variant.modulate_color = Color(0.5, 0.5, 0.5) if state == "disabled" else Color(1.3, 1.3, 1.3)
		button.add_theme_stylebox_override(state, variant)
	button.add_theme_color_override("font_color", Color("#5bc8db"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)

static func create(info: Dictionary, index: int, width: float, font_size: int, definition: Resource, post_max := false) -> Button:
	var button := Button.new()
	button.size = Vector2(width, 193)
	if post_max:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#233c49")
		style.border_color = info.color
		style.set_border_width_all(2)
		button.add_theme_stylebox_override("normal", style)
		var focus_style := style.duplicate() as StyleBoxFlat
		focus_style.border_color = Color("#c0ffff")
		for state in ["focus", "hover", "pressed"]: button.add_theme_stylebox_override(state, focus_style)
	else:
		apply_art(button, Rect2(89, 83, 145, 193))
	for entry in [[Vector2(7, 5), Vector2(width - 14, 23), "%d. %s" % [index + 1, info.tag]],
		[Vector2(7, 34), Vector2(width - 14, 28), info.name],
		[Vector2(7, 65), Vector2(width - 14, 122 if post_max else 57), info.desc]]:
		var label := Label.new()
		label.position = entry[0]
		label.size = entry[1]
		label.text = entry[2]
		label.add_theme_font_size_override("font_size", (17 if entry[0].y == 65 else 13) if post_max else font_size)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.clip_text = true
		label.max_lines_visible = (2 if post_max else 4) if entry[0].y == 65 else 2
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(label)
	add_icon(button, definition, Rect2(48 * width / 145.0, 129, 48 * width / 145.0, 48))
	return button

static func add_icon(parent: Control, definition: Resource, area: Rect2) -> void:
	if definition == null or definition is HeroDef: return
	var texture: Texture2D = ICONS.texture_for(definition)
	if texture == null: return
	var icon := TextureRect.new()
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.position = area.position
	icon.size = area.size
	parent.add_child(icon)
