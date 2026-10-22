## 重ねた絵で描く敵の外観（本体・装甲・法線の3枚）。res://data/visuals/looks/<外観の名前>.tres に置く。
##
## 敵はふつう自分の type ID と同じ名前の外観を使い、ステージの敵の見た目（StageDef.enemy_looks）は外観の名前で差し替える。
## 絵を足すときは、この Resource を1つ作って3枚の絵を入れる。コードは直さない。
class_name EnemyLook
extends Resource

## 光る部分を含む本体の絵
@export var base: Texture2D
## 照明を受ける装甲の絵
@export var armor: Texture2D
## 装甲の法線マップ
@export var normal: Texture2D
## 絵の正面の向き（ラジアン。敵の向きに足す）
@export var angle := 0.0
## 敵が回っても絵を回さない（冠など）
@export var fixed_angle := false
## 絵の大きさを当たり判定の半径に合わせる。false なら絵の寸法を敵データの半径の比で拡大縮小する
@export var size_from_collision := false
