extends "res://scripts/ui/navigation_window.gd"

var constellation_name := "ペルセウス座"
var power_name := "メドゥーサの首"
var description := ""
var effect_label: Label
func _build_content(panel: Control) -> void:
	_label(panel, tr("hud.ult_granted"), Vector2(32,22), Vector2(804,24), 15, CYAN)
	_label(panel, "%s — %s" % [constellation_name,power_name], Vector2(32,57), Vector2(804,47), 32, GOLD)
	var line := ColorRect.new()
	line.color = Color("253a54")
	line.position = Vector2(32,125)
	line.size = Vector2(804,1)
	panel.add_child(line)
	effect_label = _label(panel, description, Vector2(32,162), Vector2(804,190), 23, Color("e7edf7"))
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_label.add_theme_constant_override("line_spacing", 8)
