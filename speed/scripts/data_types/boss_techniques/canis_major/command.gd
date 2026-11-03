## 号令の編集値。
@tool
extends BossTechnique

## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 7.0:
	set(value):
		cd = value
		_values_dirty = true
## 再使用待ち（秒）（第2形態）
@export_range(0,100000,0.01) var cd_p2 := 5.0:
	set(value):
		cd_p2 = value
		_values_dirty = true
## ダメージ
@export_range(0,100000,0.01) var damage := 12.0:
	set(value):
		damage = value
		_values_dirty = true
## 猟犬が飛び出す速さ
@export_range(0,100000,0.01) var lunge_speed := 1260.0:
	set(value):
		lunge_speed = value
		_values_dirty = true
## 猟犬が飛び出す速さ（第2形態）
@export_range(0,100000,0.01) var lunge_speed_p2 := 1500.0:
	set(value):
		lunge_speed_p2 = value
		_values_dirty = true
## 猟犬が飛び出す時間（秒）
@export_range(0,100000,0.01) var lunge_time := 0.55:
	set(value):
		lunge_time = value
		_values_dirty = true
## 号令に要る猟犬の数
@export_range(0,100000,1) var min_hounds := 3:
	set(value):
		min_hounds = value
		_values_dirty = true
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 0.6:
	set(value):
		recover = value
		_values_dirty = true
## 予告（秒）
@export_range(0,100000,0.01) var warn := 0.6:
	set(value):
		warn = value
		_values_dirty = true

