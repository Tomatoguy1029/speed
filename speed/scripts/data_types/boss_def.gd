## ボス1体の定義（仕様書 10・21）。値の正は res://data/bosses/*.tres。
class_name BossDef
extends Resource

@export var id: StringName
@export var display_name: String
## ボスのシーン（res://scenes/bosses/）
@export var scene_path: String
@export var radius: float
@export var hp: float
@export var armor: float
@export var speed: float
@export var accel: float
@export var turn: float
@export var contact: float
@export var xp: float
@export var weak_arc: float
## 攻撃の値（fire_interval, telegraph, volley, spread, bullet_speed, bullet_dmg, slow など）
@export var params: Dictionary
