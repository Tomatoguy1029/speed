## 味方の弾・攻撃する破片1つ（設計書 6）。
class_name Shot
extends RefCounted

var kind: StringName
var cause: StringName
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var r := 5.0
var dmg := 0.0
var life := 1.0
var max_life := 1.0
## 敵を貫くか。貫かない場合は、あと何体貫けるか
var pierce := false
var pierce_left := 0
## もう当てた敵（id → true）
var hit: Dictionary = {}
var color := Color.WHITE
var no_crit := false
var knock := 250.0
## 破片：回転と、実際に通った位置の跡
var angle := 0.0
var spin := 0.0
var trail := PackedVector2Array()
