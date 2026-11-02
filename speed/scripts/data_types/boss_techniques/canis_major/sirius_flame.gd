## シリウスの光の公開値と動作。
@tool
extends BossTechnique

## 予告（秒）
@export_range(0,100000,0.01) var warn := 0.8:
	set(value):
		warn = value
		_values_dirty = true
## 吐き続ける時間（秒）
@export_range(0,100000,0.01) var duration := 2.6:
	set(value):
		duration = value
		_values_dirty = true
## 毎秒出す炎の数
@export_range(0,100000,0.01) var emit_rate := 85.0:
	set(value):
		emit_rate = value
		_values_dirty = true
## 炎を出す広がり（度）
@export_range(0,100000,0.01) var spread := 15.0:
	set(value):
		spread = value
		_values_dirty = true
## 炎の粒の速さ
@export_range(0,100000,0.01) var particle_speed := 1150.0:
	set(value):
		particle_speed = value
		_values_dirty = true
## 炎の減速率（毎秒）
@export_range(0,100000,0.01) var drag := 1.2:
	set(value):
		drag = value
		_values_dirty = true
## 炎の粒の寿命（秒）
@export_range(0,100000,0.01) var life := 0.85:
	set(value):
		life = value
		_values_dirty = true
## 炎の始まりの半径
@export_range(0,100000,0.01) var r_start := 14.0:
	set(value):
		r_start = value
		_values_dirty = true
## 炎の終わりの半径
@export_range(0,100000,0.01) var r_end := 72.0:
	set(value):
		r_end = value
		_values_dirty = true
## 炎の半径に対する判定倍率
@export_range(0,100000,0.01) var hit_scale := 0.75:
	set(value):
		hit_scale = value
		_values_dirty = true
## 吐く間の旋回（ラジアン毎秒）
@export_range(0,100000,0.01) var turn := 1.8:
	set(value):
		turn = value
		_values_dirty = true
## 吐く間に進む速さ
@export_range(0,100000,0.01) var advance := 130.0:
	set(value):
		advance = value
		_values_dirty = true
## 接近を止める距離
@export_range(0,100000,0.01) var advance_until := 220.0:
	set(value):
		advance_until = value
		_values_dirty = true
## ダメージ
@export_range(0,100000,0.01) var damage := 18.0:
	set(value):
		damage = value
		_values_dirty = true
## 硬直（秒）
@export_range(0,100000,0.01) var recover := 1.0:
	set(value):
		recover = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 8.0:
	set(value):
		cd = value
		_values_dirty = true
