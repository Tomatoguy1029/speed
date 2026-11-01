## 本番HUDの配置・素材を継承し、ゲージの編集値と確認状態だけを渡す。
extends "res://scripts/ui/hud.gd"

var preview_values: Dictionary = {}
var preview_mode := 0
var preview_clock := 0.0
var preview_cursor := Vector2.ZERO
var follow_cursor := false
var preview_paused := false
var reward_preview := false

func _input(_event: InputEvent) -> void:
	pass

func _unhandled_input(_event: InputEvent) -> void:
	pass

func _exit_tree() -> void:
	# 独立プレビューの破棄で、別ランの音声状態を変更しない。
	pass

func _process(delta: float) -> void:
	# 戦闘・メニュー・音声の更新を実行せず、本番の表示だけ更新する。
	_layout_art()
	_refresh_loadout_icons()
	_sync_combat_art_visibility()
	if not preview_paused:
		_ring_pulse_t = maxf(0.0, _ring_pulse_t - delta)
		_ring_flash_t = maxf(0.0, _ring_flash_t - delta)
	queue_redraw()

func _draw_gauge_ring() -> void:
	if reward_preview:
		super._draw_gauge_ring()
		return
	var s := run.state
	var cursor := get_viewport().get_mouse_position() if follow_cursor else preview_cursor
	var at := cursor + Vector2(26, 26)
	var amount := s.gauge_amount()
	var usable := amount >= run.cfg.draw_min_charge
	if preview_mode == 5:
		var charging := not s.drawing and not s.tracing
		if usable and not _ring_usable and charging: _ring_pulse_t = RING_PULSE_TIME
		if charging and _lap_filled(_ring_amount, amount, s.stats.capacity):
			_ring_flash_t = RING_FLASH_TIME
			_ring_flash_max = RING_FLASH_TIME
		_ring_usable = usable
		_ring_amount = amount
	if s.drawing:
		amount = s.draw_gauge * (1.0 - s.draw_length / maxf(1.0, s.draw_limit))
	var pulse := fmod(preview_clock, RING_PULSE_TIME) / RING_PULSE_TIME if preview_mode == 3 else -1.0
	var flash := 1.0 - fmod(preview_clock, RING_FLASH_TIME) / RING_FLASH_TIME if preview_mode == 4 else 0.0
	if preview_mode == 5:
		pulse = 1.0 - _ring_pulse_t / RING_PULSE_TIME if _ring_pulse_t > 0.0 else -1.0
		flash = _ring_flash_t / _ring_flash_max if _ring_flash_t > 0.0 else 0.0
	var style := BOOST_GAUGE.style_for(preview_values)
	BOOST_GAUGE.draw(self, at, amount, s.stats.capacity, run.cfg.draw_min_charge,
		s.drawing, usable, flash, pulse, style, RING_GAP)
