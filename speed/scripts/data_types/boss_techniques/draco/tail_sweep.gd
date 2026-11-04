## 尾の薙ぎ払いの値と動き。実行状態は再生ごとのRunnerが持つ。
@tool
extends BossTechnique

## 予告（秒）
@export_range(0,30,0.01) var warn := 0.85:
	set(value):
		warn = value
		_values_dirty = true
## 実行時間（秒）
@export_range(0,30,0.01) var active := 0.55:
	set(value):
		active = value
		_values_dirty = true
## 技後の待ち（秒）
@export_range(0,30,0.01) var recover := 1.0:
	set(value):
		recover = value
		_values_dirty = true
## ダメージ
@export_range(0,100000,0.1) var damage := 30.0:
	set(value):
		damage = value
		_values_dirty = true
## 届く長さ
@export_range(0,100000,1) var reach := 1000.0:
	set(value):
		reach = value
		_values_dirty = true
## 当たりの太さ（中心から片側）
@export_range(0,100000,1) var width := 77.0:
	set(value):
		width = value
		_values_dirty = true
## 左右の広がり角度（度）
@export_range(0,180,0.1,"radians_as_degrees") var half_angle := 1.3:
	set(value):
		half_angle = value
		_values_dirty = true
