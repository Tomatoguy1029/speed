## ケンタウルス座の技の値と実行処理。
@tool
extends BossTechnique

## 次の技までの間（秒）
@export_range(0, 100000, 0.01) var gap := 0.2:
	set(value):
		gap = value
		_values_dirty = true
## 再使用待ち（秒）
@export_range(0, 100000, 0.01) var cd := 10.0:
	set(value):
		cd = value
		_values_dirty = true

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/centaurus/technique_runner.gd":
	func kind() -> StringName: return &"combo_rain_volley"
