## 敵1種類の定義（仕様書 9、一覧 docs/enemies.md）。値の正は res://data/enemies/*.tres。
## 既定値は 0（GameConfig と同じ理由）。
class_name EnemyDef
extends Resource

@export var id: StringName
@export var display_name: String
@export var radius: float
@export var hp: float
@export var armor: float
@export var speed: float
@export var accel: float
@export var turn: float
@export var contact: float
@export var xp: float
@export var color: Color
## 見た目の形（orb, dart, hex, blob, diamond, ship, rock）
@export var shape: StringName
## 行動の種類（chase, dash, split, leech, gunner, missile, battleship, drift）
@export var behavior: StringName
## 標準の 0.85〜1.30 倍のサイズで生成するか
@export var size_var: bool
## 背面の弱点の半角（ラジアン）。0 なら弱点なし
@export var weak_arc: float
## 行動ごとの値（range, windup, dash_speed, fire_interval, bullet_speed など）
@export var params: Dictionary
