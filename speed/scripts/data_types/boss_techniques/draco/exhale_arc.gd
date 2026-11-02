## 吐き出しビーム左右の彗星弾。技リソースのInspectorで弧を調整する。
@tool
class_name DracoExhaleArc
extends Resource
@export var offset := Vector2.ZERO
@export var radius := 180.0
@export_range(-180,180) var angle_degrees := 0.0
@export_range(0,180) var spread_degrees := 60.0
@export_range(1,30) var count := 5
