## 遠吠えの値と動き。
@tool
extends BossTechnique

## 囲みへ走る速さの倍率
@export_range(0,100000,0.01) var catch_up := 5.6:
	set(value):
		catch_up = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 15.0:
	set(value):
		cd = value
		_values_dirty = true
## 囲みを狭める時間（秒）
@export_range(0,100000,0.01) var close_time := 1.0:
	set(value):
		close_time = value
		_values_dirty = true
## 薄い所で抜く猟犬の数
@export_range(0,100000,1) var gap_slots := 2:
	set(value):
		gap_slots = value
		_values_dirty = true
## 薄い所の数
@export_range(0,100000,1) var gaps := 2:
	set(value):
		gaps = value
		_values_dirty = true
## 囲みに並ぶ時間（秒）
@export_range(0,100000,0.01) var gather_time := 1.0:
	set(value):
		gather_time = value
		_values_dirty = true
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 1.5:
	set(value):
		recover = value
		_values_dirty = true
## 囲みの終わりの半径
@export_range(0,100000,0.01) var ring_close := 330.0:
	set(value):
		ring_close = value
		_values_dirty = true
## 囲みの猟犬の数
@export_range(0,100000,1) var ring_count := 16:
	set(value):
		ring_count = value
		_values_dirty = true
## 囲みの始めの半径
@export_range(0,100000,0.01) var ring_radius := 560.0:
	set(value):
		ring_radius = value
		_values_dirty = true
## 呼んだ猟犬が出る輪の外の距離
@export_range(0,100000,0.01) var spawn_out := 350.0:
	set(value):
		spawn_out = value
		_values_dirty = true
## 呼び足す猟犬の上限
@export_range(0,100000,1) var summon_max := 10:
	set(value):
		summon_max = value
		_values_dirty = true
## 予告（秒）
@export_range(0,100000,0.01) var warn := 1.2:
	set(value):
		warn = value
		_values_dirty = true

## 輪の中心が自機を追う時間（秒）
@export_range(0,100000,0.01) var follow_time := 2.0:
	set(value):
		follow_time = value
		_values_dirty = true
## 輪の中心の追従率（毎秒）
@export_range(0,100000,0.01) var follow_rate := 4.0:
	set(value):
		follow_rate = value
		_values_dirty = true
## 輪から飛び出す間隔（秒）
@export_range(0,100000,0.01) var seq_interval := 0.12:
	set(value):
		seq_interval = value
		_values_dirty = true
## 猟犬1体の白い予告（秒）
@export_range(0,100000,0.01) var seq_warn := 0.3:
	set(value):
		seq_warn = value
		_values_dirty = true
## 猟犬の突進速度
@export_range(0,100000,0.01) var lunge_speed := 1260.0:
	set(value):
		lunge_speed = value
		_values_dirty = true
## 猟犬の突進時間（秒）
@export_range(0,100000,0.01) var lunge_time := 0.55:
	set(value):
		lunge_time = value
		_values_dirty = true
## 猟犬1体のダメージ
@export_range(0,100000,0.01) var damage := 12.0:
	set(value):
		damage = value
		_values_dirty = true
## 最後の発進から囲み終了まで（秒）
@export_range(0,100000,0.01) var tail := 0.8:
	set(value):
		tail = value
		_values_dirty = true
