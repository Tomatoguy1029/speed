## 操作練習の説明パネル1枚。実際のランを録画した動く絵と、見出し・説明文を表示する。
extends PanelContainer

const LESSONS := preload("res://scripts/ui/tutorial_lessons.gd")
const STRIP := preload("res://scripts/ui/tutorial_strip.gd")
var _lesson: Dictionary
var _atlas: AtlasTexture
var _strip: HBoxContainer
var _clock := 0.0

## compact は操作ガイドの一覧用。余白を詰め、手順表示を省く。
func _init(lesson: Dictionary, picture_width := 540.0, title_size := 30, body_size := 19, compact := false) -> void:
	_lesson = lesson
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0a1020")
	style.border_color = Color("2f4466")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10.0 if compact else 22.0)
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8 if compact else 14)
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
	if lesson.has("strip") and not compact:
		_strip = STRIP.new(maxi(12, body_size - 2), maxf(1.0, body_size / 12.0))
		column.add_child(_strip)
	var body := Label.new()
	body.text = tr("tutorial.%s.body" % lesson.key)
	body.add_theme_font_size_override("font_size", body_size)
	body.add_theme_constant_override("line_spacing", 2 if compact else 6)
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
