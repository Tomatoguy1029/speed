## 隕石投射の値と動き。
@tool
extends BossTechnique

## 予告（秒）
@export_range(0,100000,0.01) var warn := 1.1:
	set(value):
		warn = value
		_values_dirty = true
## 攻撃の継続時間
@export_range(0,100000,0.01) var active := 0.05:
	set(value):
		active = value
		_values_dirty = true
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 0.25:
	set(value):
		recover = value
		_values_dirty = true
## ダメージ
@export_range(0,100000,0.01) var damage := 0.0:
	set(value):
		damage = value
		_values_dirty = true
## 岩の数
@export_range(0,100000,1) var rocks := 3:
	set(value):
		rocks = value
		_values_dirty = true
## 岩のHP
@export_range(0,100000,0.01) var rock_hp := 180.0:
	set(value):
		rock_hp = value
		_values_dirty = true
## 岩の半径
@export_range(0,100000,0.01) var rock_radius := 78.0:
	set(value):
		rock_radius = value
		_values_dirty = true
## 岩までの距離
@export_range(0,100000,0.01) var rock_distance := 340.0:
	set(value):
		rock_distance = value
		_values_dirty = true
## 岩の間隔
@export_range(0,100000,0.01) var rock_spacing := 240.0:
	set(value):
		rock_spacing = value
		_values_dirty = true

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/draco/techniques/breath.gd".Runner:
	func kind() -> StringName: return &"meteor"

	func tick(_a: BossActor,_dt: float) -> void:
		pass
	func end(a: BossActor,cancelled: bool) -> void:
		if cancelled:super(a,true)
		else:
			a.placed_meteors=rocks.duplicate()
			MOTION.clear_tell(a)
	func recover(_a: BossActor,_dt: float) -> void:
		pass

	func is_meteor() -> bool:
		return true
