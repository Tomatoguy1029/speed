## T01 終端爆縮：線の終点（弾かれた地点を含む）で爆発（一覧 docs/game/catalog/traits.md）。
extends TraitBehavior

func on_end() -> void:
	build.combat.explode(state.ship_pos, val("radius"), atk() * val("damage"),
		{"cause": &"endBlast", "color": Color("#c46bff"), "knock": def.params.knock})
