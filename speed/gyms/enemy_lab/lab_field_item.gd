## 実験場の敵一覧から置ける、フィールドの障害物と仕掛け（惑星・彗星・重力・ワープホール）。
## 敵の表の敵ではないので、置くと FieldManager の要素として加える。
extends Resource

var id: StringName
var display_name: String
## planet・comet・gravity・warp
var kind: StringName
## 惑星の半径（ほかは使わない）
var radius := 0.0
var color := Color.WHITE

static func make(id: StringName, name: String, kind: StringName, radius: float, color: Color):
	var item = load("res://gyms/enemy_lab/lab_field_item.gd").new()
	item.id = id
	item.display_name = name
	item.kind = kind
	item.radius = radius
	item.color = color
	return item
