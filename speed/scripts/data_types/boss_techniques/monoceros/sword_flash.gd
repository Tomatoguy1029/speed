## 光の剣の連撃の公開値と段の進行。
@tool
extends BossTechnique

## 斬る回数
@export_range(1,100000,1) var cuts := 3:
	set(value):
		cuts = value
		_values_dirty = true

## 1回目の溜めの時間（秒）
@export_range(0,100000,0.01) var first_windup := 0.6:
	set(value):
		first_windup = value
		_values_dirty = true

## 2回目からの溜めの時間（秒）
@export_range(0,100000,0.01) var windup := 0.42:
	set(value):
		windup = value
		_values_dirty = true

## 振り抜きの何秒前に向きと狙う位置を固定するか（秒）
@export_range(0,100000,0.01) var lock_time := 0.2:
	set(value):
		lock_time = value
		_values_dirty = true

## 溜め中に自機へ向き直る速さ（度/秒）
@export_range(0,720,0.1,"radians_as_degrees") var aim_turn := 7.993607974134029:
	set(value):
		aim_turn = value
		_values_dirty = true

## 角を引く角度（度）
@export_range(0,720,0.1,"radians_as_degrees") var pull := 0.7853981633974483:
	set(value):
		pull = value
		_values_dirty = true

## 振り抜く時間（秒）
@export_range(0,100000,0.01) var swing_time := 0.1:
	set(value):
		swing_time = value
		_values_dirty = true

## 振り抜きで前へ出る初めの速さ
@export_range(0,100000,0.01) var lunge_speed := 420.0:
	set(value):
		lunge_speed = value
		_values_dirty = true

## 前へ出る速さの減り方（1/秒）
@export_range(0,100000,0.01) var lunge_decay := 10.0:
	set(value):
		lunge_decay = value
		_values_dirty = true

## 斬撃の中心の、本体からの最短の距離
@export_range(0,100000,0.01) var slash_min := 260.0:
	set(value):
		slash_min = value
		_values_dirty = true

## 斬撃の中心の、本体からの最長の距離
@export_range(0,100000,0.01) var slash_max := 700.0:
	set(value):
		slash_max = value
		_values_dirty = true

## 斬撃の線の向き。正面から振る側への角度（度）。90 で真横
@export_range(0,720,0.1,"radians_as_degrees") var slash_angle := 1.2566370614359172:
	set(value):
		slash_angle = value
		_values_dirty = true

## 斬撃の長さ
@export_range(0,100000,0.01) var slash_length := 800.0:
	set(value):
		slash_length = value
		_values_dirty = true

## 斬撃の当たりの太さ
@export_range(0,100000,0.01) var slash_width := 24.0:
	set(value):
		slash_width = value
		_values_dirty = true

## 斬撃が当たる時間（秒）
@export_range(0,100000,0.01) var slash_hit_time := 0.06:
	set(value):
		slash_hit_time = value
		_values_dirty = true

## 1回の斬りと次の溜めの間（秒）
@export_range(0,100000,0.01) var cut_gap := 0.08:
	set(value):
		cut_gap = value
		_values_dirty = true

## 最後に角を正面へ戻す時間（秒）
@export_range(0,100000,0.01) var return_time := 0.3:
	set(value):
		return_time = value
		_values_dirty = true

## 斬撃1回のダメージ
@export_range(0,100000,0.01) var damage := 20.0:
	set(value):
		damage = value
		_values_dirty = true

## 戻したあとの隙（秒）
@export_range(0,100000,0.01) var recover := 1.4:
	set(value):
		recover = value
		_values_dirty = true

## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 7.0:
	set(value):
		cd = value
		_values_dirty = true

