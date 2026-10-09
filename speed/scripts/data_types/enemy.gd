## 敵1体の状態（設計書 6）。ノードではなくデータとして、EnemyManager の配列に入る。
class_name Enemy
extends RefCounted

enum Mode { MOVE, WINDUP, DASH, RECOVER }
## 行動の種類（EnemyDef.behavior を生成時に数値へ直したもの。更新の高速化のため）
enum Beh { CHASE, DASH, SPLIT, GUNNER, MISSILE, BATTLESHIP, DRIFT }

var id := 0
var def: EnemyDef
var beh: Beh = Beh.CHASE
## 追跡の広域移動の、敵ごとに決まった値（周期のずれ・移動先の向きと広がり）
var roam_phase := 0.0
var roam_angle := 0.0
var roam_radius := 0.0
var accel := 2.0
var turn := 4.0
var type: StringName
var level := 1.0
var elite := false
var is_boss := false
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var r := 10.0
var hp := 1.0
var max_hp := 1.0
var armor := 0.0
var contact := 0.0
var xp := 0.0
var speed := 0.0
var facing := 0.0
## 背面の弱点の半角（0 なら弱点なし）
var weak_arc := 0.0
var color := Color.WHITE
var dead := false

## 同じ敵に続けて当たらない時間、被弾の光、年齢
var hit_cd := 0.0
var flash := 0.0
var age := 0.0

## 行動（ダーターの突進など）
var mode: Mode = Mode.MOVE
var timer := 0.0
var fire_t := 0.0
var charge := 0.0
var bud_t := 0.0
var buds := 0
var spin := 0.0

## 吹き飛ばされて追跡をやめている時間
var knock_t := 0.0
## 吹き飛ばし衝角で押し出されている間の値
var shove_time := 0.0
var shove_vel := Vector2.ZERO
var shove_dmg := 0.0
var shove_hits: Dictionary = {}
var shove_from := Vector2.ZERO
var shoved := false

## 1回の突進で最初に触れたときに満タンだったか（ヒットストップの一撃の判定、仕様書 7.4）
var dash_seen := -1
var dash_fresh := false
var hull_scattered := false
## 隕石の配置の通し番号（隕石だけ）
var meteor_index := -1
