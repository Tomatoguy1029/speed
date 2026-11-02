## 焼き焦がす光の公開値と動作。
@tool
extends BossTechnique

## 炎を撃つ回数
@export_range(0,100000,1) var shots := 3:
	set(value):
		shots = value
		_values_dirty = true
## 次の射撃までの間（秒）
@export_range(0,100000,0.01) var shot_gap := 0.25:
	set(value):
		shot_gap = value
		_values_dirty = true
## 予告（秒）
@export_range(0,100000,0.01) var warn := 0.7:
	set(value):
		warn = value
		_values_dirty = true
## 発射前に向きを固定する時間（秒）
@export_range(0,100000,0.01) var lock := 0.3:
	set(value):
		lock = value
		_values_dirty = true
## 先読みする時間（秒）
@export_range(0,100000,0.01) var lead := 0.3:
	set(value):
		lead = value
		_values_dirty = true
## 照準中の旋回（ラジアン毎秒）
@export_range(0,100000,0.01) var aim_turn := 3.0:
	set(value):
		aim_turn = value
		_values_dirty = true
## 炎の長さ
@export_range(0,100000,0.01) var beam_length := 1300.0:
	set(value):
		beam_length = value
		_values_dirty = true
## 炎の太さ
@export_range(0,100000,0.01) var beam_width := 40.0:
	set(value):
		beam_width = value
		_values_dirty = true
## 炎の時間（秒）
@export_range(0,100000,0.01) var beam_time := 0.35:
	set(value):
		beam_time = value
		_values_dirty = true
## 焼け跡の判定開始（秒）
@export_range(0,100000,0.01) var trail_delay := 0.35:
	set(value):
		trail_delay = value
		_values_dirty = true
## 焼け跡が消える時刻（発射からの秒）
@export_range(0,100000,0.01) var trail_time := 3.2:
	set(value):
		trail_time = value
		_values_dirty = true
## 焼け跡の判定の太さ
@export_range(0,100000,0.01) var trail_width := 18.0:
	set(value):
		trail_width = value
		_values_dirty = true
## 焼け跡のダメージ
@export_range(0,100000,0.01) var trail_damage := 10.0:
	set(value):
		trail_damage = value
		_values_dirty = true
## ダメージ
@export_range(0,100000,0.01) var damage := 20.0:
	set(value):
		damage = value
		_values_dirty = true
## 硬直（秒）
@export_range(0,100000,0.01) var recover := 1.0:
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
