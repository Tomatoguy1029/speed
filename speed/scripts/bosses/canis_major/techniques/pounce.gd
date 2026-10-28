## 飛びかかりの値と動き。
@tool
extends BossTechnique

## 攻撃の継続時間
@export_range(0,100000,0.01) var active := 0.45
## 群れが少ないとみなす猟犬の数
@export_range(0,100000,1) var alone_hounds := 3
## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 4.0
## 群れが少ないときの再使用待ち（秒）
@export_range(0,100000,0.01) var cd_alone := 2.0
## 群れが少ないときの再使用待ち（秒）（第2形態）
@export_range(0,100000,0.01) var cd_alone_p2 := 1.5
## 再使用待ち（秒）（第2形態）
@export_range(0,100000,0.01) var cd_p2 := 3.0
## ダメージ
@export_range(0,100000,0.01) var damage := 24.0
## 狙いを固定する時間（秒）
@export_range(0,100000,0.01) var lock := 0.2
## 着地点の先までの距離
@export_range(0,100000,0.01) var overshoot := 80.0
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 1.4
## 予告（秒）
@export_range(0,100000,0.01) var warn := 0.7
## 予告（秒）（第2形態）
@export_range(0,100000,0.01) var warn_p2 := 0.5

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/canis_major/technique_runner.gd":
	pass
