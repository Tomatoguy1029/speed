## 追い立てと狙撃の公開値と動作。
@tool
extends BossTechnique

## 最後の猟犬の発進から構えまで（秒）
@export_range(0,100000,0.01) var gap := 0.1:
	set(value):
		gap = value
		_values_dirty = true
## 狙撃の予告（秒）
@export_range(0,100000,0.01) var aim_warn := 1.1:
	set(value):
		aim_warn = value
		_values_dirty = true
## 狙撃の発射前の固定時間（秒）
@export_range(0,100000,0.01) var aim_lock := 0.55:
	set(value):
		aim_lock = value
		_values_dirty = true
## 狙撃の先読み（秒）
@export_range(0,100000,0.01) var aim_lead := 0.35:
	set(value):
		aim_lead = value
		_values_dirty = true
## 照準中の旋回（ラジアン毎秒）
@export_range(0,100000,0.01) var aim_turn := 2.6:
	set(value):
		aim_turn = value
		_values_dirty = true
## 炎の長さ
@export_range(0,100000,0.01) var beam_length := 1500.0:
	set(value):
		beam_length = value
		_values_dirty = true
## 炎の太さ
@export_range(0,100000,0.01) var beam_width := 44.0:
	set(value):
		beam_width = value
		_values_dirty = true
## 炎の時間（秒）
@export_range(0,100000,0.01) var beam_time := 0.7:
	set(value):
		beam_time = value
		_values_dirty = true
## ダメージ
@export_range(0,100000,0.01) var damage := 26.0:
	set(value):
		damage = value
		_values_dirty = true
## 硬直（秒）
@export_range(0,100000,0.01) var recover := 1.6:
	set(value):
		recover = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 10.0:
	set(value):
		cd = value
		_values_dirty = true

## 放射粒の物理寿命。表示用の炎の寿命と独立して、弾速と到達範囲を保つ。
@export_range(0.1, 2.5, 0.05) var beam_particle_life := 0.65:
	set(value):
		beam_particle_life = value
		_values_dirty = true

## 放射するピクセル炎。ビジュアル編集の「炎」で調整する。
@export var flame_settings: PixelFireSettings = preload("res://data/visuals/canis_fire_jet.tres"):
	set(value):
		flame_settings = value
		_values_dirty = true
