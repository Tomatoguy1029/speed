## 実験場の配色、余白と見慣れた操作アイコン。
extends RefCounted

const INK := Color("#e2eaf4")
const MUTED := Color("#9daec3")
const ACCENT := Color("#7de2cf")
const SURFACE := Color("#152131")
static var _icons: Dictionary = {}

static func icon(kind: String) -> Texture2D:
	if _icons.has(kind): return _icons[kind]
	var shapes := {
		"play": '<path d="m8 5 11 7-11 7Z" fill="#e2eaf4"/>',
		"pause": '<path d="M8 5v14M16 5v14" stroke-width="4"/>',
		"step": '<path d="m5 6 9 6-9 6Z"/><path d="M18 5v14"/>',
		"start": '<path d="M5 5v14m14-13-9 6 9 6Z"/>',
		"back": '<path d="m14 5-7 7 7 7M7 12h14"/>',
		"undo": '<path d="M9 5 4 10l5 5M4 10h10a6 6 0 0 1 0 12" transform="translate(0 -2)"/>',
		"redo": '<path d="m15 5 5 5-5 5m5-5H10a6 6 0 0 0 0 12" transform="translate(0 -2)"/>',
		"close": '<path d="m6 6 12 12M18 6 6 18"/>',
		"plus": '<path d="M12 5v14M5 12h14"/>',
		"pointer": '<path d="m5 3 14 10-7 1-3 7Z"/>',
		"pencil": '<path d="m4 20 1-6L16 3l5 5L10 19Zm10-15 5 5"/>',
		"trash": '<path d="M3 6h18M9 6V3h6v3M6 6l1 15h10l1-15M10 10v7m4-7v7"/>',
		"eye": '<path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12Z"/><circle cx="12" cy="12" r="3"/>',
		"save": '<path d="M4 3h13l4 4v14H3V3Zm3 0v6h9V3M7 21v-8h10v8"/>',
		"search": '<circle cx="10" cy="10" r="6"/><path d="m15 15 6 6"/>',
		"settings": '<path d="M4 6h16M4 12h16M4 18h16"/><path d="M8 3v6m8 0v6M10 15v6" stroke-width="4"/>',
		"dice": '<rect x="3" y="3" width="18" height="18" rx="3"/><path d="M7 7h.1M17 7h.1M12 12h.1M7 17h.1M17 17h.1" stroke-width="3"/>',
		"ruler": '<path d="m3 16 13-13 5 5L8 21Zm5-5 3 3m0-6 3 3m0-6 3 3"/>',
		"clock": '<circle cx="12" cy="12" r="9"/><path d="M12 6v6l4 3"/>',
		"help": '<circle cx="12" cy="12" r="9"/><path d="M9 8a3 3 0 1 1 5 3c-2 1-2 2-2 3m0 3h.1"/>',
		"more": '<path d="M5 12h.1m7 0h.1m7 0h.1" stroke-width="4"/>',
		"chevron": '<path d="m6 9 6 6 6-6"/>',
		"chevron_right": '<path d="m9 6 6 6-6 6"/>',
		"grid": '<rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/>',
		"focus": '<path d="M3 9V3h6m6 0h6v6m0 6v6h-6m-6 0H3v-6"/><circle cx="12" cy="12" r="3"/>',
	}
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><g fill="none" stroke="#e2eaf4" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">%s</g></svg>' % shapes.get(kind, "")
	var pixels := Image.new()
	pixels.load_svg_from_string(svg)
	_icons[kind] = ImageTexture.create_from_image(pixels)
	return _icons[kind]

static func style(color: Color, border := Color.TRANSPARENT, padding := 8) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding
	box.content_margin_bottom = padding
	return box

static func theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 14
	for kind in ["Label", "Button", "LineEdit", "SpinBox", "CheckButton", "OptionButton"]:
		result.set_color("font_color", kind, INK)
	for kind in ["Button", "OptionButton"]:
		result.set_stylebox("normal", kind, style(Color("#1c2b3e")))
		result.set_stylebox("hover", kind, style(Color("#293e54"), MUTED))
		result.set_stylebox("pressed", kind, style(Color("#264b49"), ACCENT))
		result.set_stylebox("focus", kind, style(Color.TRANSPARENT, ACCENT))
		result.set_constant("h_separation", kind, 8)
		result.set_constant("icon_max_width", kind, 20)
	result.set_stylebox("panel", "PanelContainer", style(SURFACE))
	result.set_stylebox("normal", "LineEdit", style(Color("#0d1725"), Color("#30435b")))
	result.set_stylebox("focus", "LineEdit", style(Color("#0d1725"), ACCENT))
	result.set_stylebox("panel", "TabContainer", style(SURFACE, Color.TRANSPARENT, 12))
	result.set_constant("separation", "VBoxContainer", 8)
	result.set_constant("separation", "HBoxContainer", 8)
	return result

static func button(parent: Node, title: String, action: Callable, glyph := "", icon_only := false) -> Button:
	var control := Button.new()
	control.text = "" if icon_only else title
	control.tooltip_text = title
	control.custom_minimum_size = Vector2(36, 36)
	if not glyph.is_empty(): control.icon = icon(glyph)
	control.pressed.connect(action)
	parent.add_child(control)
	return control

static func fold(parent: Node, title: String, open := false) -> VBoxContainer:
	var group := VBoxContainer.new()
	parent.add_child(group)
	var toggle := button(group, title, func(): pass, "chevron" if open else "chevron_right")
	toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle.toggle_mode = true
	toggle.button_pressed = open
	var content := VBoxContainer.new()
	content.visible = open
	group.add_child(content)
	toggle.toggled.connect(func(on): content.visible = on; toggle.icon = icon("chevron" if on else "chevron_right"))
	return content
