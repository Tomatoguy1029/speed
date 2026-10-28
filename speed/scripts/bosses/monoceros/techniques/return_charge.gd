## 往復突進の値と動き。
@tool
extends BossTechnique

## 攻撃の継続時間
@export_range(0,100000,0.01) var active := 0.8
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 12.0
## ダメージ
@export_range(0,100000,0.01) var damage := 25.0
## 移動距離
@export_range(0,100000,0.01) var distance := 1150.0
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 2.4
## 予告（秒）
@export_range(0,100000,0.01) var warn := 1.0

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/monoceros/techniques/charge.gd".Runner:
	pass
