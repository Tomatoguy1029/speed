## 「クリック › 動かす › クリック」の手順表示。今の段だけを明るくする。
extends HBoxContainer

const MOUSE := preload("res://assets/ui/tutorial/mouse.png")
const DIM := Color(1, 1, 1, 0.3)
var _items: Array[Control] = []
var _icons: Array[TextureRect] = []
var _clock := 0.0
var _active := -1

func _init(font_size := 22, icon_scale := 2.0) -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 14)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 3:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 8)
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := TextureRect.new()
		icon.texture = _frame(0)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.custom_minimum_size = Vector2(11, 16) * icon_scale
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(icon)
		var label := Label.new()
		label.text = tr("tutorial.strip.move" if i == 1 else "tutorial.strip.click")
		label.add_theme_font_size_override("font_size", font_size)
		item.add_child(label)
		add_child(item)
		_items.append(item)
		_icons.append(icon)
		if i < 2:
			var arrow := Label.new()
			arrow.text = "›"
			arrow.add_theme_font_size_override("font_size", font_size)
			arrow.modulate = Color(1, 1, 1, 0.5)
			add_child(arrow)
	set_active(-1)

static func _frame(index: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = MOUSE
	atlas.region = Rect2(index * 11, 0, 11, 16)
	return atlas

## 0：始点のクリック、1：動かす、2：確定のクリック、-1：なし。
func set_active(index: int) -> void:
	_active = index
	for i in 3:
		_items[i].modulate = Color.WHITE if i == index or (index == 2 and i == 1) else DIM

func _process(delta: float) -> void:
	_clock += delta
	var blink := fmod(_clock, 0.7) < 0.4
	for i in 3:
		_icons[i].texture = _frame(1 if i != 1 and i == _active and blink else 0)
