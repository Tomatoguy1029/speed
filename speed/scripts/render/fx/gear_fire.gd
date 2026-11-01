## ギアアップの炎。共通ピクセル炎（PixelFire）を後ろ向きに置き、強さ 0〜1 で炎の量・太さ・長さ・速さを変える。
## 強さ 1 の炎は data/visuals/gear_fire.tres（ビジュアル編集の「炎」で調整できる）。炎の1ドットは試作の1ドット。
class_name GearFire
extends Node2D

const COMPONENTS := preload("res://scripts/render/fx/visual_effect_components.gd")
const SETTINGS := preload("res://data/visuals/gear_fire.tres")
## 強さ 0 のときの、強さ 1 に対する割合
const WEAK := {"birth_rate": 0.25, "particle_size": 0.6, "lifetime": 0.35, "rise_speed": 0.5}
var fire: PixelFire
var _settings: PixelFireSettings
var _power := -1.0
var _full: PixelFireSettings
var _cell := 1.0

## cell は世界での1ドットの長さ。
func setup(cell: float) -> void:
	_cell = cell
	_full = COMPONENTS.fire("trait/fullCharge", SETTINGS)
	_settings = _full.duplicate()
	fire = PixelFire.new()
	fire.manual = true
	fire.settings = _settings
	# 炎の場は1ドット＝pixel_size 単位。上（-Y）へ昇る炎を、機体の後ろへ向ける
	fire.scale = Vector2.ONE * cell / maxf(1.0, _full.pixel_size)
	fire.rotation = -PI * 0.5
	add_child(fire)

## power は 0〜1。on のあいだ炎を出し、外すと残った炎が消えていく。
func set_power(power: float, on: bool) -> void:
	var resolved := COMPONENTS.fire("trait/fullCharge", SETTINGS)
	if resolved != _full:
		_full = resolved
		_settings = _full.duplicate()
		fire.settings = _settings
		fire.scale = Vector2.ONE * _cell / maxf(1.0, _full.pixel_size)
		_power = -1.0
	fire.emitting = on
	if absf(power - _power) < 0.02: return
	_power = power
	for name in WEAK:
		var full: float = _full.get(name)
		_settings.set(name, full * lerpf(WEAK[name], 1.0, power))
	_settings.source_size = _full.source_size * Vector2(lerpf(0.5, 1.0, power), 1.0)

## 向き（機体の向き）に合わせ、dt 秒進める。
func step(dt: float, heading: float) -> void:
	rotation = heading
	fire.advance(dt)
