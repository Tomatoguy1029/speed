## 突進から薙ぎ払いの値と動き。
@tool
extends BossTechnique

## 再使用待ち（秒）
@export_range(0,100000,0.01) var cd := 12.0

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends "res://scripts/bosses/monoceros/technique_runner.gd":
	pass
