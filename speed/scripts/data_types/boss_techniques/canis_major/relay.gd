## 光を継ぐ群れの公開値と動作。
@tool
extends BossTechnique

## 予告（秒）
@export_range(0,100000,0.01) var warn := 0.8:
	set(value):
		warn = value
		_values_dirty = true
## 必要な猟犬の数
@export_range(0,100000,1) var min_hounds := 6:
	set(value):
		min_hounds = value
		_values_dirty = true
## 猟犬を送り出す間隔（秒）
@export_range(0,100000,0.01) var interval := 0.25:
	set(value):
		interval = value
		_values_dirty = true
## 猟犬ごとの予告（秒）
@export_range(0,100000,0.01) var each_warn := 0.6:
	set(value):
		each_warn = value
		_values_dirty = true
## 猟犬の炎の長さ
@export_range(0,100000,0.01) var hound_beam_length := 900.0:
	set(value):
		hound_beam_length = value
		_values_dirty = true
## 猟犬の炎の太さ
@export_range(0,100000,0.01) var hound_beam_width := 12.0:
	set(value):
		hound_beam_width = value
		_values_dirty = true
## 猟犬の炎の時間（秒）
@export_range(0,100000,0.01) var hound_beam_time := 0.22:
	set(value):
		hound_beam_time = value
		_values_dirty = true
## 猟犬の炎のダメージ
@export_range(0,100000,0.01) var hound_damage := 10.0:
	set(value):
		hound_damage = value
		_values_dirty = true
## 締めの予告（秒）
@export_range(0,100000,0.01) var final_warn := 1.1:
	set(value):
		final_warn = value
		_values_dirty = true
## 締めの発射前の固定時間（秒）
@export_range(0,100000,0.01) var final_lock := 0.35:
	set(value):
		final_lock = value
		_values_dirty = true
## 締めの旋回（ラジアン毎秒）
@export_range(0,100000,0.01) var final_turn := 6.0:
	set(value):
		final_turn = value
		_values_dirty = true
## 締めの炎の長さ
@export_range(0,100000,0.01) var final_length := 1500.0:
	set(value):
		final_length = value
		_values_dirty = true
## 締めの炎の太さ
@export_range(0,100000,0.01) var final_width := 44.0:
	set(value):
		final_width = value
		_values_dirty = true
## 締めの炎の時間（秒）
@export_range(0,100000,0.01) var final_time := 0.7:
	set(value):
		final_time = value
		_values_dirty = true
## 締めのダメージ
@export_range(0,100000,0.01) var final_damage := 26.0:
	set(value):
		final_damage = value
		_values_dirty = true
## 硬直（秒）
@export_range(0,100000,0.01) var recover := 1.6:
	set(value):
		recover = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 12.0:
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
