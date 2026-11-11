extends Control
signal closed
const DESIGN := Vector2(1280, 720)
const PANEL_SIZE := Vector2(868, 460)
const GOLD := Color("ffd86b")
const CYAN := Color("5fe3ff")
const HERO_DIAGRAM := preload("res://scripts/ui/hero_guide_diagram.gd")
const MAPS := [preload("res://assets/ui/navigation/map_1.svg"), preload("res://assets/ui/navigation/map_2.svg")]
const SHIELD_MASK := preload("res://assets/effects/landmark/shield.png")
const AURA_NOISE := preload("res://assets/effects/build/aura_noise.png")
const SHIELD_PARTS := [preload("res://assets/pixel/shield/scutum_base.png"), preload("res://assets/pixel/shield/scutum_armor.png")]
const AURA_SHADER := preload("res://shaders/landmark_aura_runtime.gdshader")
var hero_guide := false
var canvas: Control
var resume_button: Button
var accept_at := 0

func _ready() -> void:
	theme = preload("res://assets/ui/theme.tres").duplicate()
	theme.default_font = preload("res://assets/ui/aseprite_font.tres")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.025, 0.055, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(dim)
	canvas = Control.new()
	canvas.size = DESIGN
	canvas.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(canvas)
	var panel := Panel.new()
	panel.position = (DESIGN - PANEL_SIZE) * 0.5
	panel.size = PANEL_SIZE
	panel.add_theme_stylebox_override("panel", _style(Color("0a1020"), Color("43617b")))
	canvas.add_child(panel)
	var accent := ColorRect.new()
	accent.position = Vector2(0,0)
	accent.size = Vector2(868, 3)
	accent.color = GOLD
	panel.add_child(accent)
	_build_content(panel)
	resume_button = Button.new()
	resume_button.text = tr("guide.resume")
	resume_button.position = Vector2(524, 378)
	resume_button.size = Vector2(312, 54)
	resume_button.add_theme_font_size_override("font_size", 19)
	resume_button.add_theme_color_override("font_color", Color("071424"))
	resume_button.add_theme_color_override("font_hover_color", Color("071424"))
	resume_button.add_theme_color_override("font_focus_color", Color("071424"))
	resume_button.add_theme_stylebox_override("normal", _style(CYAN, CYAN))
	resume_button.add_theme_stylebox_override("hover", _style(Color("b3f3ff"), Color("b3f3ff")))
	resume_button.add_theme_stylebox_override("focus", _style(Color(0,0,0,0), Color("e7faff"), 2))
	resume_button.pressed.connect(close)
	panel.add_child(resume_button)
	resume_button.focus_mode = Control.FOCUS_NONE
	accept_at = Time.get_ticks_msec() + 500
	resized.connect(_layout)
	_layout()

func _step(panel: Control, index: int, title: String) -> void:
	var x := 32.0 + index * 274.0
	if index == 0:
		var at := Vector2(x + 124, 255)
		var aura := Sprite2D.new()
		aura.texture = SHIELD_MASK
		aura.position = at
		aura.rotation = -0.4
		aura.scale = Vector2.ONE * (96.0/47.0)
		var mat := ShaderMaterial.new()
		mat.shader = AURA_SHADER
		mat.set_shader_parameter("noise_tex", AURA_NOISE)
		mat.set_shader_parameter("linear_colors", false)
		mat.set_shader_parameter("clock", 1.8)
		aura.material = mat
		aura.set_instance_shader_parameter("mask_size", Vector2(111,106))
		panel.add_child(aura)
		for part in SHIELD_PARTS:
			var image := Sprite2D.new()
			image.texture = part
			image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			image.position = at
			image.rotation = -0.4
			image.scale = Vector2.ONE * (96.0/47.0)
			panel.add_child(image)
	else:
		var picture := TextureRect.new()
		picture.texture = MAPS[index - 1]
		picture.position = Vector2(x+34, 182)
		picture.size = Vector2(180, 160)
		picture.mouse_filter = MOUSE_FILTER_IGNORE
		panel.add_child(picture)
	_label(panel, title, Vector2(x, 337), Vector2(248, 28), 20, GOLD, HORIZONTAL_ALIGNMENT_CENTER)

func _label(parent: Control, text: String, at: Vector2, area: Vector2, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = area
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = align
	label.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _style(bg: Color, edge: Color, width := 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = edge
	style.set_border_width_all(width)
	style.set_corner_radius_all(8)
	return style

func _layout() -> void:
	var factor := minf(size.x / DESIGN.x, size.y / DESIGN.y)
	canvas.scale = Vector2.ONE * factor
	canvas.position = (size - DESIGN * factor) * 0.5

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event is InputEventKey and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		if event.keycode == KEY_SPACE and event.pressed and not event.echo:
			close()
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

func close() -> void:
	if not is_visible_in_tree() or Time.get_ticks_msec() < accept_at: return
	closed.emit()


func _hero_step(panel: Control, index: int, title: String) -> void:
	var x := 32.0 + index * 274.0
	var picture = HERO_DIAGRAM.new()
	picture.stage = index
	picture.position = Vector2(x + 34, 182)
	panel.add_child(picture)
	_label(panel, title, Vector2(x, 337), Vector2(248, 28), 20, GOLD, HORIZONTAL_ALIGNMENT_CENTER)

func _build_content(panel: Control) -> void:
	_label(panel, tr("guide.heading"), Vector2(32, 22), Vector2(300, 24), 15, CYAN)
	_label(panel, tr("guide.hero.title") if hero_guide else tr("guide.landmark.title"), Vector2(32, 57), Vector2(804, 47), 32, GOLD)
	_label(panel, tr("guide.hero.desc") if hero_guide else tr("guide.landmark.desc"), Vector2(32, 113), Vector2(804, 68), 21, Color("e7edf7"))
	var line := ColorRect.new()
	line.color = Color("253a54")
	line.position = Vector2(32, 165)
	line.size = Vector2(804, 1)
	panel.add_child(line)
	if hero_guide:
		_hero_step(panel, 0, tr("guide.hero.step1"))
		_hero_step(panel, 1, tr("guide.hero.step2"))
		_hero_step(panel, 2, tr("guide.hero.step3"))
	else:
		_step(panel, 0, tr("guide.landmark.step1"))
		_step(panel, 1, tr("guide.landmark.step2"))
		_step(panel, 2, tr("guide.landmark.step3"))
	for x in [294, 568]:
		_label(panel, "→", Vector2(x-15, 228), Vector2(30, 44), 28, Color("627a90"), HORIZONTAL_ALIGNMENT_CENTER)
