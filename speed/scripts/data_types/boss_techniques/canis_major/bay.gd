## 吠え立ての値と動き。
@tool
extends BossTechnique

## 吠える予告（秒）
@export_range(0,100000,0.01) var warn := 0.7:
	set(value):
		warn = value
		_values_dirty = true
## 囲みに参加する猟犬の数
@export_range(0,100000,1) var count := 8:
	set(value):
		count = value
		_values_dirty = true
## 発動に必要な猟犬の数
@export_range(0,100000,1) var min_hounds := 6:
	set(value):
		min_hounds = value
		_values_dirty = true
## 囲み開始から飛びかかりまで（秒）
@export_range(0,100000,0.01) var pounce_at := 3.2:
	set(value):
		pounce_at = value
		_values_dirty = true
## 本体が接近を止める距離
@export_range(0,100000,0.01) var approach_stop := 380.0:
	set(value):
		approach_stop = value
		_values_dirty = true
## 囲みが回る角速度（ラジアン毎秒）
@export_range(0,100000,0.01) var orbit := 0.35:
	set(value):
		orbit = value
		_values_dirty = true
## 正面側の半径
@export_range(0,100000,0.01) var r_front := 320.0:
	set(value):
		r_front = value
		_values_dirty = true
## 横側の半径
@export_range(0,100000,0.01) var r_side := 250.0:
	set(value):
		r_side = value
		_values_dirty = true
## 背後側の半径
@export_range(0,100000,0.01) var r_back := 200.0:
	set(value):
		r_back = value
		_values_dirty = true
## 正面とみなす角度（度）
@export_range(0,100000,0.01) var front_angle := 60.0:
	set(value):
		front_angle = value
		_values_dirty = true
## 背後とみなす角度（度）
@export_range(0,100000,0.01) var back_angle := 99.0:
	set(value):
		back_angle = value
		_values_dirty = true
## 持ち場の揺れ幅
@export_range(0,100000,0.01) var wobble := 20.0:
	set(value):
		wobble = value
		_values_dirty = true
## 追従の最高速
@export_range(0,100000,0.01) var max_speed := 360.0:
	set(value):
		max_speed = value
		_values_dirty = true
## 低速時の旋回（ラジアン毎秒）
@export_range(0,100000,0.01) var turn_fast := 6.0:
	set(value):
		turn_fast = value
		_values_dirty = true
## 高速時の旋回（ラジアン毎秒）
@export_range(0,100000,0.01) var turn_slow := 3.2:
	set(value):
		turn_slow = value
		_values_dirty = true
## 旋回速度を切り替える速さ
@export_range(0,100000,0.01) var turn_switch := 220.0:
	set(value):
		turn_switch = value
		_values_dirty = true
## 加速の上限（距離毎秒二乗）
@export_range(0,100000,0.01) var accel := 650.0:
	set(value):
		accel = value
		_values_dirty = true
## 減速の上限（距離毎秒二乗）
@export_range(0,100000,0.01) var decel := 900.0:
	set(value):
		decel = value
		_values_dirty = true
## 到着とみなす距離
@export_range(0,100000,0.01) var arrive := 35.0:
	set(value):
		arrive = value
		_values_dirty = true
## 停止時の旋回（ラジアン毎秒）
@export_range(0,100000,0.01) var face_turn := 5.0:
	set(value):
		face_turn = value
		_values_dirty = true
## 吠える間隔の最小（秒）
@export_range(0,100000,0.01) var bark_min := 0.5:
	set(value):
		bark_min = value
		_values_dirty = true
## 吠える間隔の最大（秒）
@export_range(0,100000,0.01) var bark_max := 0.9:
	set(value):
		bark_max = value
		_values_dirty = true
## 同時に噛みに行ける数
@export_range(0,100000,1) var nip_max := 2:
	set(value):
		nip_max = value
		_values_dirty = true
## 噛みつく予告（秒）
@export_range(0,100000,0.01) var nip_warn := 0.3:
	set(value):
		nip_warn = value
		_values_dirty = true
## 噛みに行く速さ
@export_range(0,100000,0.01) var nip_speed := 720.0:
	set(value):
		nip_speed = value
		_values_dirty = true
## 噛みに行く時間（秒）
@export_range(0,100000,0.01) var nip_time := 0.25:
	set(value):
		nip_time = value
		_values_dirty = true
## 噛んだ直後の速さ
@export_range(0,100000,0.01) var nip_after_speed := 260.0:
	set(value):
		nip_after_speed = value
		_values_dirty = true
## 次に噛むまで（秒）
@export_range(0,100000,0.01) var nip_cd := 1.2:
	set(value):
		nip_cd = value
		_values_dirty = true
## 噛みつきダメージ
@export_range(0,100000,0.01) var nip_damage := 10.0:
	set(value):
		nip_damage = value
		_values_dirty = true
## 硬直は飛びかかりの値を使う
@export_range(0,100000,0.01) var recover := 0.0:
	set(value):
		recover = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 13.0:
	set(value):
		cd = value
		_values_dirty = true
