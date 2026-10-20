## ステージの進行時刻。リソースのプロパティ名で読み書きし、ゲームのクラスに依存しない。
@tool
extends RefCounted

const BOSS := Color("#75c9ff")
const LIMIT := Color("#ff8f9b")
const SURGE := Color("#efb76b")
var canvas
var defaults: Resource

func _init(owner: Control) -> void:
	canvas = owner
	var path := str(ProjectSettings.get_setting("spawn_timeline/defaults_resource", ""))
	if path != "" and ResourceLoader.exists(path):
		defaults = load(path)

func value(prop: String) -> float:
	var own := _stored(prop)
	if own >= 0.0:
		return own
	if defaults != null and prop in ["boss_time", "surge_start"]:
		return float(defaults.get(prop))
	return -1.0

func _stored(prop: String) -> float:
	var own = canvas.timeline.stage.get(prop)
	return float(own) if own != null else -1.0

func extent() -> float:
	return maxf(maxf(value("boss_time"), value("time_limit")), maxf(value("surge_start"), value("surge_end")))

func _top() -> float:
	return canvas._scroll_y() + canvas.RULER

func _band() -> Rect2:
	var start := value("surge_start")
	var end := value("surge_end")
	if end < 0.0:
		end = canvas._end_time()
	return Rect2(canvas._x(start), _top() + canvas.PHASE_ROW - 17.0 * canvas.ui, maxf(1.0, canvas._x(end) - canvas._x(start)), 14.0 * canvas.ui)

func draw() -> void:
	var ui: float = canvas.ui
	var top := _top()
	var font: Font = canvas.get_theme_default_font()
	var band := _band()
	var shown := band.intersection(Rect2(canvas.GUTTER, top, maxf(0.0, canvas.size.x - canvas.GUTTER), canvas.PHASE_ROW))
	if shown.has_area():
		canvas.draw_rect(shown, Color(SURGE, 0.3))
		canvas.draw_rect(shown, SURGE, false, ui)
		var suffix: String = canvas.clock(value("surge_end")) if value("surge_end") >= 0.0 else "継続"
		canvas.draw_string(font, shown.position + Vector2(5, 11) * ui,
			"強化 %s → %s" % [canvas.clock(value("surge_start")), suffix], HORIZONTAL_ALIGNMENT_LEFT,
			maxf(0.0, shown.size.x - 10 * ui), canvas._fs(10), SURGE)
		for edge in [band.position.x, band.end.x]:
			if edge >= canvas.GUTTER and edge <= canvas.size.x:
				canvas.draw_rect(Rect2(edge - 2 * ui, band.position.y, 4 * ui, band.size.y), SURGE)
	_pin("boss_time", "ボス", BOSS)
	_pin("time_limit", "制限", LIMIT)
	canvas.draw_string(font, Vector2(8 * ui, top + 45 * ui), "右クリック：ピン・強化帯", HORIZONTAL_ALIGNMENT_LEFT, canvas.GUTTER - 12 * ui, canvas._fs(10), Color(1, 1, 1, 0.6))

func _pin(prop: String, label: String, color: Color) -> void:
	var at := value(prop)
	if at < 0.0:
		return
	var x: float = canvas._x(at)
	if x < canvas.GUTTER or x > canvas.size.x:
		return
	var ui: float = canvas.ui
	var top := _top() + _pin_y(prop) * ui
	canvas.draw_line(Vector2(x, top), Vector2(x, canvas.size.y), Color(color, 0.25), ui)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(x - 5 * ui, top - 9 * ui), Vector2(x + 5 * ui, top - 9 * ui), Vector2(x, top)]), color)
	var text := "%s %s" % [label, canvas.clock(at)]
	var font: Font = canvas.get_theme_default_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, canvas._fs(12)).x
	var tx := clampf(x + 8 * ui, canvas.GUTTER, maxf(canvas.GUTTER, canvas.size.x - width - 4 * ui))
	canvas.draw_string(font, Vector2(tx, top - 1 * ui), text, HORIZONTAL_ALIGNMENT_LEFT, width, canvas._fs(12), color)

func _pin_y(prop: String) -> float:
	if prop == "time_limit" and absf(value("boss_time") - value("time_limit")) * canvas.px_per_sec < 100.0 * canvas.ui:
		return 28.0
	return 12.0

func hit(p: Vector2) -> Dictionary:
	var y: float = (p.y - _top()) / canvas.ui
	if p.x < canvas.GUTTER:
		return {}
	for prop in ["time_limit", "boss_time"]:
		if value(prop) >= 0.0 and absf(p.x - canvas._x(value(prop))) <= canvas.HANDLE * 1.5 and absf(y - _pin_y(prop) + 4.0) <= 9.0:
			return {"kind": "clock", "field": prop}
	var band := _band()
	if p.y >= band.position.y:
		if absf(p.x - band.position.x) <= canvas.HANDLE:
			return {"kind": "clock", "field": "surge_start"}
		if absf(p.x - band.end.x) <= canvas.HANDLE:
			return {"kind": "clock", "field": "surge_end"}
		if band.has_point(p):
			return {"kind": "clock", "field": "surge"}
	return {}

func begin(h: Dictionary, p: Vector2) -> Dictionary:
	var props: Array = ["surge_start", "surge_end"] if h.field == "surge" else [h.field]
	var before := {}
	for prop in props:
		before[prop] = _stored(prop)
	return {"kind": "clock", "field": h.field, "target": canvas.timeline.stage, "props": props, "before": before,
		"t0": canvas._t(p.x), "start": value("surge_start"), "end": value("surge_end")}

func move(drag: Dictionary, time: float, snap: float) -> void:
	var stage: Resource = drag.target
	match drag.field:
		"surge":
			var delta := maxf(-float(drag.start), snappedf(time - float(drag.t0), snap))
			stage.set("surge_start", float(drag.start) + delta)
			if float(drag.end) >= 0.0:
				stage.set("surge_end", float(drag.end) + delta)
		"surge_start":
			stage.set("surge_start", clampf(snappedf(time, snap), 0.0, value("surge_end") if value("surge_end") >= 0.0 else 1e9))
		"surge_end":
			stage.set("surge_end", maxf(value("surge_start"), snappedf(time, snap)))
		_:
			stage.set(drag.field, maxf(0.0, snappedf(time, snap)))

func edit(field: String, at: Vector2) -> void:
	var band := field.begins_with("surge")
	var text: String
	if band:
		var end: String = canvas.clock(value("surge_end")) if value("surge_end") >= 0.0 else "-"
		text = "%s %s" % [canvas.clock(value("surge_start")), end]
	else:
		text = canvas.clock(value(field) if value(field) >= 0.0 else maxf(0.0, canvas._t(at.x)))
	canvas._open_editor(text, Rect2(Vector2(maxf(canvas.GUTTER, at.x - 80 * canvas.ui), _top()), Vector2(230, 30) * canvas.ui),
		func(input: String) -> void:
			var parts := input.strip_edges().replace("　", " ").split(" ", false)
			if parts.is_empty():
				return
			var start := _seconds(parts[0])
			if start < 0.0:
				return
			var changes := []
			if band:
				if parts.size() != 2:
					return
				var end := -1.0 if parts[1] == "-" else _seconds(parts[1])
				if parts[1] != "-" and end < start:
					return
				_change(changes, "surge_start", start)
				_change(changes, "surge_end", end)
			else:
				_change(changes, field, start)
			if not changes.is_empty():
				canvas.timeline.commit("ステージの進行時刻を変える", changes),
		"開始 終了（m:ss）／継続は -" if band else "時刻（m:ss または秒）")

static func _seconds(text: String) -> float:
	var parts := text.split(":")
	if parts.size() == 1:
		return float(text) if text.is_valid_float() and is_finite(float(text)) else -1.0
	if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_float():
		var secs := float(parts[1])
		var total := float(parts[0]) * 60.0 + secs
		return total if secs >= 0.0 and secs < 60.0 and is_finite(total) else -1.0
	return -1.0

func _change(changes: Array, prop: String, after: float) -> void:
	var stage: Resource = canvas.timeline.stage
	var before := _stored(prop)
	if before != after:
		changes.append([stage, prop, before, after])
		stage.set(prop, after)

func menu(at: Vector2) -> void:
	var popup := PopupMenu.new()
	canvas.add_child(popup)
	for text in ["ボスの出現時刻を入力", "制限時間を入力", "強化区間を入力", "制限時間を解除", "強化を継続にする", "ボス・強化開始を共通設定に戻す"]:
		popup.add_item(text)
	popup.id_pressed.connect(func(id: int) -> void:
		if id < 3:
			edit(["boss_time", "time_limit", "surge"][id], at)
			return
		var changes := []
		if id == 3:
			_change(changes, "time_limit", -1.0)
		elif id == 4:
			_change(changes, "surge_end", -1.0)
		else:
			_change(changes, "boss_time", -1.0)
			_change(changes, "surge_start", -1.0)
			_change(changes, "surge_end", -1.0)
		if not changes.is_empty():
			canvas.timeline.commit("ステージの進行時刻を変える", changes))
	popup.popup_hide.connect(popup.queue_free)
	popup.popup(Rect2i(Vector2i(canvas.get_screen_position() + at), Vector2i.ZERO))
