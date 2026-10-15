## 出現・攻撃・被弾・撃破をレーンに分けて表示する。
extends Control
var session
signal seek_requested(tick: int)
const LANES := [["lab.message_26fa279ba2", [&"lab_spawn", &"boss_spawn"]], ["lab.message_63d8f43c5b", [&"attack_start", &"shoot"]], ["lab.message_1c155a99a1", [&"hurt", &"crash", &"ship_hit", &"damage", &"bounce"]], ["lab.message_c3775f8a58", [&"kill", &"boss_defeated"]]]
func _ready() -> void:
	custom_minimum_size.y = 65
	mouse_filter = Control.MOUSE_FILTER_STOP
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		seek_requested.emit(roundi(clampf((event.position.x - 50) / maxf(1, size.x - 50), 0, 1) * session.furthest))
func _draw() -> void:
	if session == null:
		return
	for n in LANES.size():
		var y := float(n) * 16
		draw_string(ThemeDB.fallback_font, Vector2(0, y + 12), tr(LANES[n][0]), HORIZONTAL_ALIGNMENT_LEFT, 46, 11)
		draw_line(Vector2(50, y + 15), Vector2(size.x, y + 15), Color("#243248"))
		for event in session.events:
			if event.get("type") in LANES[n][1]:
				var x := 50 + float(event.tick) / maxf(1, session.furthest) * (size.x - 50)
				draw_rect(Rect2(x, y + 2, 3, 10), [Color.SKY_BLUE, Color.ORANGE, Color.SALMON, Color.LIGHT_GREEN][n])
	var starts := {}
	for event in session.events:
		if event.get("type") == &"attack_start": starts[int(event.token)] = int(event.tick)
		elif event.get("type") == &"attack_end" and starts.has(int(event.token)):
			var x := 50 + float(starts[int(event.token)]) / maxf(1, session.furthest) * (size.x - 50)
			var end := 50 + float(event.tick) / maxf(1, session.furthest) * (size.x - 50)
			draw_rect(Rect2(x, 21, maxf(2, end - x), 5), Color(1, 0.65, 0.35, 0.55))
			starts.erase(int(event.token))
	for start in starts.values():
		var x := 50 + float(start) / maxf(1, session.furthest) * (size.x - 50)
		var end := 50 + float(session.tick) / maxf(1, session.furthest) * (size.x - 50)
		draw_rect(Rect2(x, 21, maxf(2, end - x), 5), Color(1, 0.65, 0.35, 0.55))
	var cursor := 50 + float(session.tick) / maxf(1, session.furthest) * (size.x - 50)
	draw_line(Vector2(cursor, 0), Vector2(cursor, size.y), Color.WHITE, 1.5)
