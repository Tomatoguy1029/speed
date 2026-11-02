## 光角の乱舞の公開値と段の進行。
@tool
extends BossTechnique

## 最初に自機を向いて角を光らせる時間（秒）
@export_range(0,100000,0.01) var aim_time := 0.5:
	set(value):
		aim_time = value
		_values_dirty = true

## 最初に自機へ向き直る速さ（度/秒）
@export_range(0,720,0.1,"radians_as_degrees") var aim_turn := 4.991641660703783:
	set(value):
		aim_turn = value
		_values_dirty = true

## 最初の発進の何秒前に向きを固定するか（秒）
@export_range(0,100000,0.01) var aim_lock := 0.15:
	set(value):
		aim_lock = value
		_values_dirty = true

## 突進の回数
@export_range(1,100000,1) var passes := 4:
	set(value):
		passes = value
		_values_dirty = true

## 突進の速さ
@export_range(0,100000,0.01) var speed := 2200.0:
	set(value):
		speed = value
		_values_dirty = true

## 各回の突進で、自機の位置から先へ突き抜ける距離
@export_range(0,100000,0.01) var overshoot := 280.0:
	set(value):
		overshoot = value
		_values_dirty = true

## 1回の突進の最短の距離
@export_range(0,100000,0.01) var min_run := 650.0:
	set(value):
		min_run = value
		_values_dirty = true

## 旋回で向きが変わる速さ（度/秒）。いつも左回り
@export_range(0,720,0.1,"radians_as_degrees") var circle_turn := 3.4033920413889427:
	set(value):
		circle_turn = value
		_values_dirty = true

## 旋回中の移動の速さ
@export_range(0,100000,0.01) var circle_speed := 900.0:
	set(value):
		circle_speed = value
		_values_dirty = true

## この時間旋回しても向きが合わないとき、旋回を小さくする（秒）
@export_range(0,100000,0.01) var circle_late_time := 1.2:
	set(value):
		circle_late_time = value
		_values_dirty = true

## 旋回を小さくしたときの移動の速さ
@export_range(0,100000,0.01) var circle_speed_late := 600.0:
	set(value):
		circle_speed_late = value
		_values_dirty = true

## 旋回に入るときの減速（毎秒あたりの速さの減り方）
@export_range(0,100000,0.01) var circle_decel := 6000.0:
	set(value):
		circle_decel = value
		_values_dirty = true

## 旋回中の加速（毎秒あたりの速さの増え方）
@export_range(0,100000,0.01) var circle_accel := 2200.0:
	set(value):
		circle_accel = value
		_values_dirty = true

## 機首が自機に向いたとみなす角度のずれ（度）
@export_range(0,720,0.1,"radians_as_degrees") var align_angle := 0.059341194567807204:
	set(value):
		align_angle = value
		_values_dirty = true

## 自機がこれより近いときは突っ込まずに旋回を続ける
@export_range(0,100000,0.01) var align_min_distance := 380.0:
	set(value):
		align_min_distance = value
		_values_dirty = true

## 旋回の最短の時間（秒）
@export_range(0,100000,0.01) var align_min_time := 0.25:
	set(value):
		align_min_time = value
		_values_dirty = true

## これだけ旋回しても向きが合わなければ技を終える（秒）
@export_range(0,100000,0.01) var circle_max_time := 3.0:
	set(value):
		circle_max_time = value
		_values_dirty = true

## 旋回中に頭が先に自機を向く最大の角度（度）
@export_range(0,720,0.1,"radians_as_degrees") var head_lead := 0.5061454830783556:
	set(value):
		head_lead = value
		_values_dirty = true

## 機首と自機の向きのずれがこれより小さいと角が光り始める（度）
@export_range(0,720,0.1,"radians_as_degrees") var glow_angle := 1.2042771838760873:
	set(value):
		glow_angle = value
		_values_dirty = true

## 最後に止まって角を掲げる時間（秒）
@export_range(0,100000,0.01) var end_time := 0.5:
	set(value):
		end_time = value
		_values_dirty = true

## 最後に止まるときの速さの減り方（1/秒）
@export_range(0,100000,0.01) var end_decay := 7.0:
	set(value):
		end_decay = value
		_values_dirty = true

## 突進1回のダメージ
@export_range(0,100000,0.01) var damage := 25.0:
	set(value):
		damage = value
		_values_dirty = true

## 角を掲げたあとの隙（秒）
@export_range(0,100000,0.01) var recover := 2.5:
	set(value):
		recover = value
		_values_dirty = true

## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 18.0:
	set(value):
		cd = value
		_values_dirty = true

