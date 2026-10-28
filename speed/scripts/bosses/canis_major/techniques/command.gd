## 号令の値と動き。
@tool
extends BossTechnique

## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 7.0
## 再使用待ち（秒）（第2形態）
@export_range(0,100000,0.01) var cd_p2 := 5.0
## ダメージ
@export_range(0,100000,0.01) var damage := 12.0
## 猟犬が飛び出す速さ
@export_range(0,100000,0.01) var lunge_speed := 1260.0
## 猟犬が飛び出す速さ（第2形態）
@export_range(0,100000,0.01) var lunge_speed_p2 := 1500.0
## 猟犬が飛び出す時間（秒）
@export_range(0,100000,0.01) var lunge_time := 0.55
## 号令に要る猟犬の数
@export_range(0,100000,1) var min_hounds := 3
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 0.6
## 予告（秒）
@export_range(0,100000,0.01) var warn := 0.6

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/canis_major/technique_runner.gd":
	pass
