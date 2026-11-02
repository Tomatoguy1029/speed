## 鉄のがれきは、配置ごとに固定した3種類の絵をまとめて描く。
extends EnemyVisual

const TEXTURES := [preload("res://assets/pixel/iron.png"), preload("res://assets/pixel/iron_debris_2.png"),
	preload("res://assets/pixel/iron_debris_3.png")]
const KEYS := [&"iron", &"iron_debris_2", &"iron_debris_3"]
