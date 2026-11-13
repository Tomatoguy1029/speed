## 原画の雷と分身の枠を、図鑑の並びに依存せず正しい武器へ割り当てる。
extends Node
func _ready() -> void:
	var icons := preload("res://scripts/ui/module_icons.gd")
	var definition := WeaponDef.new()
	for pair in [[&"W17",8],[&"W27",7],[&"W01",0]]:
		definition.id = pair[0]
		var texture := icons.texture_for(definition) as AtlasTexture
		assert(texture.atlas == icons.TEXTURE)
		assert(texture.region == Rect2(pair[1]*47,0,47,47))
	assert(icons.IDS[7] == "W17" and icons.IDS[8] == "W27")
	print("MODULE_ICON_SLOTS_OK: lightning, mirage, unrelated weapon, catalog order")
	get_tree().quit()
