## 順番の号令の値と動き。
@tool
extends BossTechnique

## 吠える予告（秒）
@export_range(0,100000,0.01) var warn := 0.6:
	set(value):
		warn = value
		_values_dirty = true
## 猟犬を送り出す間隔（秒）
@export_range(0,100000,0.01) var interval := 0.2:
	set(value):
		interval = value
		_values_dirty = true
## 猟犬1体の白い予告（秒）
@export_range(0,100000,0.01) var each_warn := 0.3:
	set(value):
		each_warn = value
		_values_dirty = true
## 猟犬の突進速度
@export_range(0,100000,0.01) var lunge_speed := 1260.0:
	set(value):
		lunge_speed = value
		_values_dirty = true
## 猟犬の突進速度（第2形態）
@export_range(0,100000,0.01) var lunge_speed_p2 := 1500.0:
	set(value):
		lunge_speed_p2 = value
		_values_dirty = true
## 猟犬の突進時間（秒）
@export_range(0,100000,0.01) var lunge_time := 0.55:
	set(value):
		lunge_time = value
		_values_dirty = true
## 発動に必要な猟犬の数
@export_range(0,100000,1) var min_hounds := 5:
	set(value):
		min_hounds = value
		_values_dirty = true
## 猟犬1体のダメージ
@export_range(0,100000,0.01) var damage := 12.0:
	set(value):
		damage = value
		_values_dirty = true
## 攻撃後の硬直（秒）
@export_range(0,100000,0.01) var recover := 0.6:
	set(value):
		recover = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 7.0:
	set(value):
		cd = value
		_values_dirty = true
## 再使用待ち（第2形態・秒）
@export_range(0,100000,0.01) var cd_p2 := 5.0:
	set(value):
		cd_p2 = value
		_values_dirty = true

func make_runner() -> RefCounted:
	return null
