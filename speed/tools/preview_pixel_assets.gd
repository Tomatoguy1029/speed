## 戦闘状態を作らず、ドット素材と隕石の損傷コマを表示する。
## --capture は .godot/pixel-preview.png へ描画を保存する。
extends Control
var _grid: GridContainer
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	_grid = GridContainer.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)
	for id in ["splitter","splitling","missile"]:
		_add_asset(load("res://data/enemies/%s.tres" % id).display_name,load("res://assets/pixel/%s.png" % id))
	for item in [["機体","airship"],["月","moon"],["惑星","planet"]]:
		_add_asset(item[0],load("res://assets/pixel/%s.png" % item[1]))
	for variant in 2:
		var texture: Texture2D = load("res://assets/pixel/%s_spritesheet.png" % ("meteor" if variant==0 else "meteor2"))
		for damage in 3:
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			var side := texture.get_height()
			atlas.region = Rect2(side*damage,0,side,side)
			_add_asset("隕石%d・損傷%d" % [variant+1,damage],atlas)
	resized.connect(_layout_assets)
	_layout_assets()
	if "--capture" in OS.get_cmdline_user_args():
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var error := get_viewport().get_texture().get_image().save_png("res://.godot/pixel-preview.png")
		if error!=OK: push_error("素材の画像を保存できませんでした")
		get_tree().quit(0 if error==OK else 1)
func _add_asset(title: String, texture: Texture2D) -> void:
	var cell := VBoxContainer.new()
	cell.custom_minimum_size = Vector2(180,180)
	_grid.add_child(cell)
	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(label)
	var picture := TextureRect.new()
	picture.texture = texture
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size = Vector2(160,140)
	picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cell.add_child(picture)
func _layout_assets() -> void:
	_grid.columns = maxi(1,int(size.x/190.0))
