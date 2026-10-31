## 描画は本番と共用し、通常・経路描画・波紋を同時に試色する。
extends Node2D
const GAUGE := preload("res://scripts/ui/boost_gauge_visual.gd")
const SETTINGS := preload("res://data/visuals/effect_settings.tres")
var preview_paused := false
var _clock := 0.0
func _process(dt: float) -> void:
	preview_step(0.0 if preview_paused else dt)
func preview_restart() -> void:
	_clock = 0.0
	queue_redraw()
func preview_step(dt: float) -> void:
	_clock += dt
	queue_redraw()
func _draw() -> void:
	var style := GAUGE.style_for(SETTINGS.values_for(GAUGE.KEY))
	var phase := fmod(_clock, 3.0) / 3.0
	var amount := phase * 1.5
	GAUGE.draw(self, Vector2(-75, 0), amount, 1.5, 0.25, false, amount >= 0.25, maxf(0.0, 1.0 - absf(phase - 0.666667) * 30.0), -1.0, style, 7.0)
	GAUGE.draw(self, Vector2.ZERO, (1.0 - phase) * 1.5, 1.5, 0.25, true, true, 0.0, -1.0, style, 7.0)
	GAUGE.draw(self, Vector2(75, 0), 1.5, 1.5, 0.25, false, true, 0.0, phase, style, 7.0)
	var font := ThemeDB.fallback_font
	for item in [[Vector2(-89, 46), "通常"], [Vector2(-18, 46), "経路描画"], [Vector2(52, 46), "使用可能の波紋"]]:
		draw_string(font, item[0], item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
