## 速射の値と動き。
@tool
extends BossTechnique

## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 3.0
## 弾数
@export_range(0,100000,1) var count := 5
## 弾数（第2形態）
@export_range(0,100000,1) var count_p2 := 8
## ダメージ
@export_range(0,100000,0.01) var damage := 12.0
## 矢の間隔（秒）
@export_range(0,100000,0.01) var interval := 0.18
## 半径
@export_range(0,100000,0.01) var radius := 12.0
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 0.8
## 矢の速さ
@export_range(0,100000,0.01) var speed := 900.0
## 矢の射程
@export_range(0,100000,0.01) var travel := 1400.0
## 予告（秒）
@export_range(0,100000,0.01) var warn := 0.6

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/centaurus/technique_runner.gd":
	pass
