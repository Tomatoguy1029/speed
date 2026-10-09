## 図鑑（仕様書 14.3）。モジュール（武器・特性・伝説のモジュール）のすべてを並べる。
## 一度も手に入れたことがないものはシルエット（名前を伏せた表示）にする。
extends UiScreen

const SECTIONS := [["武器", "weapons"], ["特性", "traits"], ["伝説のモジュール", "legendary_modules"]]

var _detail: Label

func _ready() -> void:
	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(list)
	%Content.add_child(list_scroll)
	_detail = Label.new()
	_detail.custom_minimum_size = Vector2(420, 0)
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.text = "モジュールを選ぶと詳細を表示する"
	%Content.add_child(_detail)
	var known := 0
	var total := 0
	for section in SECTIONS:
		var heading := Label.new()
		heading.text = section[0]
		heading.add_theme_font_size_override("font_size", 28)
		list.add_child(heading)
		var grid := GridContainer.new()
		grid.columns = 3
		list.add_child(grid)
		var table: Dictionary = ConfigManager.get(section[1])
		for def in ConfigManager.sorted(table):
			total += 1
			var has := SaveManager.is_module_known(def.id)
			known += 1 if has else 0
			var b := Button.new()
			b.custom_minimum_size = Vector2(220, 48)
			b.text = def.display_name if has else "？？？"
			if not has:
				b.modulate = Color(0.25, 0.25, 0.3)
			b.pressed.connect(_show.bind(def, has))
			grid.add_child(b)
	%Heading.text = "図鑑　（%d / %d）" % [known, total]
	super()

func _show(def: Resource, has: bool) -> void:
	if not has:
		_detail.text = "まだ手に入れていない"
		return
	var text: String = def.display_name
	if "id" in def:
		text += "\n" + String(def.id)
	if "description" in def and def.description != "":
		text += "\n\n" + def.description
	_detail.text = text
