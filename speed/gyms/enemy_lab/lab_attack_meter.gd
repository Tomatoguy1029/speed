extends Control
var session
const KEYS := ["aimed", "homing", "dash", "beam", "zone", "wave", "residue"]
const NAMES := ["lab.message_e25e93d055", "lab.message_bbcc068b7e", "lab.message_437d9cf8d0", "lab.message_421607de84", "lab.message_1133c374e7", "lab.message_f3482a22c0", "lab.message_c04c40391d"]
func _ready() -> void:
	custom_minimum_size = Vector2(280, 155)
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
		var y := float(n) * 19
		draw_string(get_theme_default_font(), Vector2(0, y + 13), tr(NAMES[n]), HORIZONTAL_ALIGNMENT_LEFT, 108, 12)
		for index in mini(10, active + residual):
			var rect := Rect2(112 + index * 12, y + 2, 9, 12)
			draw_rect(rect, Color("#555f6e"), false, 1)
			if index < active: draw_rect(rect.grow(-1), Color("#ffbe76"))
			elif index < active + residual:
				draw_line(rect.position, rect.end, Color("#f98585"), 2)
				draw_line(rect.position + Vector2(0, 5), rect.end - Vector2(0, 5), Color("#f98585"), 2)
		draw_string(ThemeDB.fallback_font, Vector2(238, y + 13), "%d+%d" % [active, residual], HORIZONTAL_ALIGNMENT_LEFT, 80, 11)
	# 今出ている攻撃の重さの合計と、予算
	var used: float = d.used_cost()
	var budget := float(d.settings.budget)
	var y2 := float(KEYS.size()) * 19 + 4
	draw_string(get_theme_default_font(), Vector2(0, y2 + 12), tr("lab.attack.used") % [used, budget], HORIZONTAL_ALIGNMENT_LEFT, 280, 12)
	draw_rect(Rect2(112, y2 + 2, 160, 10), Color("#555f6e"), false, 1)
	draw_rect(Rect2(113, y2 + 3, 158 * clampf(used / maxf(budget, 0.01), 0.0, 1.0), 8), Color("#ffbe76") if used <= budget else Color("#f98585"))
