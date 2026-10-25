## 重ねた絵で描く敵の外観（本体・装甲・法線と任意のディテール）。res://data/visuals/looks/<外観の名前>.tres に置く。
##
## 敵はふつう自分の type ID と同じ名前の外観を使い、ステージの敵の見た目（StageDef.enemy_looks）は外観の名前で差し替える。
## 絵を足すときは、この Resource を1つ作って3枚の絵を入れる。コードは直さない。
@tool
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

## 制作工程で確定した外観。実行時はScopeがこのResourceと画像を保持する。
@export_storage var prepared := false
@export_storage var source_path := ""
@export_storage var armor_key := ""
@export_storage var painted_armors: Dictionary = {}
@export_storage var previews: Dictionary = {}

func colors_key(palettes: Dictionary) -> String:
	var colors: Dictionary = palettes.get(armor_key, {})
	var ids := colors.keys()
	ids.sort()
	var parts := PackedStringArray()
	for id in ids: parts.append(str(id) + ":" + str(colors[id]))
	return ";".join(parts)

func preview_key(palettes: Dictionary) -> String:
	return colors_key(palettes) + "|" + (split_other.preview_key(palettes) if split_other != null else "")

## 本体とディテールは制作工程で合成済み。
func base_texture() -> Texture2D:
	assert(prepared, "生成済みの外観を使う: " + resource_path)
	return base
