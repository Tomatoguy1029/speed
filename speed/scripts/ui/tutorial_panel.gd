## 操作練習の説明パネル1枚。実際のランを録画した動く絵と、見出し・説明文を表示する。
extends PanelContainer

const LESSONS := preload("res://scripts/ui/tutorial_lessons.gd")
const STRIP := preload("res://scripts/ui/tutorial_strip.gd")
var _lesson: Dictionary
var _atlas: AtlasTexture
var _strip: HBoxContainer
var _clock := 0.0

## 大きさは戦闘HUDと同じ640×360の原画の寸法で指定し、親が画面へ拡大する。
func _init(lesson: Dictionary, picture_width := 320.0, title_size := 12, body_size := 9) -> void:
	_lesson = lesson
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0a1020")
	style.border_color = Color("2f4466")
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(8.0)
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	var title := Label.new()
	title.text = tr("tutorial.%s.title" % lesson.key)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", title_size)
	column.add_child(title)
	var path: String = LESSONS.clip_path(lesson.key)
	if ResourceLoader.exists(path):
		_atlas = AtlasTexture.new()
		_atlas.atlas = load(path)
		var picture := TextureRect.new()
		picture.texture = _atlas
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_SCALE
		picture.custom_minimum_size = Vector2(picture_width, picture_width * LESSONS.CLIP_SIZE.y / LESSONS.CLIP_SIZE.x)
		picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(picture)
		_show_frame(0)
	if lesson.has("strip"):
		_strip = STRIP.new(body_size, 1.0)
		column.add_child(_strip)
	var body := Label.new()
	body.text = tr("tutorial.%s.body" % lesson.key)
	body.add_theme_font_size_override("font_size", body_size)
	body.add_theme_constant_override("line_spacing", 2)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = picture_width
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(body)

func _show_frame(index: int) -> void:
	var size := Vector2(LESSONS.CLIP_SIZE)
	_atlas.region = Rect2(Vector2(index % LESSONS.CLIP_COLUMNS, index / LESSONS.CLIP_COLUMNS) * size, size)

func _process(delta: float) -> void:
	var frames := int(_lesson.frames)
	_clock = fmod(_clock + delta, frames / LESSONS.CLIP_FPS)
	if _atlas != null:
		_show_frame(mini(frames - 1, int(_clock * LESSONS.CLIP_FPS)))
	if _strip != null:
		var active := -1
		for span: Array in _lesson.strip:
			if _clock >= span[0] and _clock < span[1]:
				active = span[2]
		_strip.set_active(active)
