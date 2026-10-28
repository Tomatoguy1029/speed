## 隕石投射の値と動き。
@tool
extends BossTechnique

## 予告（秒）
@export_range(0,100000,0.01) var warn := 1.1
## 攻撃の継続時間
@export_range(0,100000,0.01) var active := 0.05
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 0.25
## ダメージ
@export_range(0,100000,0.01) var damage := 0.0
## 岩の数
@export_range(0,100000,1) var rocks := 3
## 岩のHP
@export_range(0,100000,0.01) var rock_hp := 180.0
## 岩の半径
@export_range(0,100000,0.01) var rock_radius := 78.0
## 岩までの距離
@export_range(0,100000,0.01) var rock_distance := 340.0
## 岩の間隔
@export_range(0,100000,0.01) var rock_spacing := 240.0

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/draco/techniques/breath.gd".Runner:
	func tick(_a: BossActor,_dt: float) -> void:
		pass
	func end(a: BossActor,cancelled: bool) -> void:
		if cancelled:super(a,true)
		else:
			a.placed_meteors=rocks.duplicate()
			MOTION.clear_tell(a)
	func recover(_a: BossActor,_dt: float) -> void:
		pass
