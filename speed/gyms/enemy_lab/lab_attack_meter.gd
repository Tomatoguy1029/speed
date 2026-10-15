extends Control
var session
const KEYS := ["aimed", "homing", "dash", "beam", "zone", "wave", "residue"]
func _ready() -> void:
	custom_minimum_size = Vector2(280, 135)
func _draw() -> void:
	if session == null or not is_instance_valid(session.run): return
	var d = session.run.projectiles.director
	for n in KEYS.size():
		var category: String = KEYS[n]
		var active := 0
		var residual := 0
		for group in d.groups.values():
			if category in group.categories:
				if float(group.until) > d.now: active += 1
				else: residual += 1
		var slots := int(d.settings.slots.get(category, 1))
		var y := float(n) * 19
		draw_string(ThemeDB.fallback_font, Vector2(0, y + 13), category, HORIZONTAL_ALIGNMENT_LEFT, 70, 12)
		for index in mini(10, maxi(slots, active + residual)):
			var rect := Rect2(75 + index * 12, y + 2, 9, 12)
			draw_rect(rect, Color("#555f6e"), false, 1)
			if index < active: draw_rect(rect.grow(-1), Color("#ffbe76"))
			elif index < active + residual:
				draw_line(rect.position, rect.end, Color("#f98585"), 2)
				draw_line(rect.position + Vector2(0, 5), rect.end - Vector2(0, 5), Color("#f98585"), 2)
		draw_string(ThemeDB.fallback_font, Vector2(205, y + 13), "%d+%d / %d" % [active, residual, slots], HORIZONTAL_ALIGNMENT_LEFT, 80, 11)
