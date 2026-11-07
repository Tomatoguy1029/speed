## りゅう座の決着で固定する連撃の経路。speed/tools/art/bake_draco_finale.py が生成する。
## 座標はすべて決着の中心からの相対位置、時刻は叩き込む段階の開始からの秒数。
class_name DracoFinaleRush
extends Resource
const HIT_FIELDS := 9
const GHOST_FIELDS := 4
## 時刻・x・y の並び。
@export var path := PackedFloat32Array()
## 時刻・次までの間隔・背骨の位置（0〜1）・x・y・向きx・向きy・機体を見せるか・大きな一撃か の並び。
@export var hits := PackedFloat32Array()
## 時刻・x・y・角度 の並び。
@export var ghosts := PackedFloat32Array()
## 切り口のy・幅 の並び。
@export var cuts := PackedFloat32Array()
