## 角の衝撃波の値と、溜め・2回の振り抜き・戻し。
@tool
extends BossTechnique

## 最初に首を引いて溜める時間（秒）
@export_range(0,100000,0.01) var windup := 0.7:
	set(value):
		windup = value
		_values_dirty = true

## 溜め中に自機へ向き直る速さ（度/秒）
@export_range(0,360,0.1,"radians_as_degrees") var windup_turn := 2.007128639793479:
	set(value):
		windup_turn = value
		_values_dirty = true

## 首を引く角度（度）
@export_range(0,360,0.1,"radians_as_degrees") var pull := 1.3962634015954636:
	set(value):
		pull = value
		_values_dirty = true

## 1回の振り抜きの時間（秒）
@export_range(0,100000,0.01) var swing_time := 0.36:
	set(value):
		swing_time = value
		_values_dirty = true

## 振り抜き中に自機へ向き直る速さ（度/秒）
@export_range(0,360,0.1,"radians_as_degrees") var swing_turn := 1.5009831567151235:
	set(value):
		swing_turn = value
		_values_dirty = true

## 衝撃波を放つ向き。正面から振る側へずらす角度（度）
@export_range(0,360,0.1,"radians_as_degrees") var release_offset := 0.4363323129985824:
	set(value):
		release_offset = value
		_values_dirty = true

## 1発目と2発目の間の溜め直しの時間（秒）
@export_range(0,100000,0.01) var recharge := 0.45:
	set(value):
		recharge = value
		_values_dirty = true

## 2発目のあと正面へ戻す時間（秒）
@export_range(0,100000,0.01) var return_time := 0.4:
	set(value):
		return_time = value
		_values_dirty = true

## 衝撃波が広がる速さ
@export_range(0,100000,0.01) var wave_speed := 600.0:
	set(value):
		wave_speed = value
		_values_dirty = true

## 衝撃波が出る半径（本体の中心から）
@export_range(0,100000,0.01) var wave_start := 120.0:
	set(value):
		wave_start = value
		_values_dirty = true

## 衝撃波が消える半径
@export_range(0,100000,0.01) var wave_max := 1000.0:
	set(value):
		wave_max = value
		_values_dirty = true

## 衝撃波の弧の半分の角度（度）
@export_range(0,360,0.1,"radians_as_degrees") var wave_half_angle := 0.6108652381980153:
	set(value):
		wave_half_angle = value
		_values_dirty = true

## 衝撃波の帯の太さ。当たりの太さでもある
@export_range(0,100000,0.01) var wave_width := 20.0:
	set(value):
		wave_width = value
		_values_dirty = true

## 衝撃波1つのダメージ
@export_range(0,100000,0.01) var damage := 15.0:
	set(value):
		damage = value
		_values_dirty = true

## 戻したあとの隙（秒）
@export_range(0,100000,0.01) var recover := 0.9:
	set(value):
		recover = value
		_values_dirty = true

## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 6.0:
	set(value):
		cd = value
		_values_dirty = true

