## 重ねた絵で描く敵の外観（本体・装甲・法線と任意のディテール）。res://data/visuals/looks/<外観の名前>.tres に置く。
##
## 敵はふつう自分の type ID と同じ名前の外観を使い、ステージの敵の見た目（StageDef.enemy_looks）は外観の名前で差し替える。
## 絵を足すときは、この Resource を1つ作って3枚の絵を入れる。コードは直さない。
class_name EnemyLook
extends Resource

## 光る部分を含む本体の絵
@export var base: Texture2D
## 本体と装甲の間に重ねるディテール（任意）
@export var decorations: Texture2D
## 照明を受ける装甲の絵
@export var armor: Texture2D
## 装甲の法線マップ
@export var normal: Texture2D
## 分離するもう片側の外観。分離前の一覧・船体では同じ位置に重ねる。
@export var split_other: EnemyLook
## 絵の正面の向き（ラジアン。敵の向きに足す）
@export var angle := 0.0
## 敵が回っても絵を回さない（冠など）
@export var fixed_angle := false
## 絵の大きさを当たり判定の半径に合わせる。false なら絵の寸法を敵データの半径の比で拡大縮小する
@export var size_from_collision := false

var _base_texture: Texture2D

## ディテールを本体へ重ね、装甲より下の層として共有する。
func base_texture() -> Texture2D:
	if decorations == null:
		return base
	if _base_texture == null:
		var image := base.get_image()
		image.blend_rect(decorations.get_image(), Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
		_base_texture = ImageTexture.create_from_image(image)
	return _base_texture
