## 光の槍の値と動き。
@tool
extends BossTechnique

## 攻撃の継続時間
@export_range(0,100000,0.01) var active := 0.38
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 10.0
## ダメージ
@export_range(0,100000,0.01) var damage := 30.0
## 移動距離
@export_range(0,100000,0.01) var distance := 340.0
## 到達距離
@export_range(0,100000,0.01) var reach := 650.0
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 2.2
## 予告（秒）
@export_range(0,100000,0.01) var warn := 1.35

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/monoceros/techniques/charge.gd".Runner:
	pass
