## T13 反応波動：ダメージを受けたとき、周りを押し返す波動（一覧 docs/traits.md）。
extends TraitBehavior

func on_hurt() -> void:
	build.combat.explode(state.ship_pos, val("radius"), atk() * val("damage"),
		{"cause": &"reactive", "color": Color("#ff6b5a"), "knock": def.params.knock})
