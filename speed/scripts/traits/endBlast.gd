## T01 終端爆縮：線の終点（弾かれた地点を含む）で爆発（一覧 docs/game/catalog/traits.md）。
extends TraitBehavior
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")

func on_end() -> void:
	ctx.combat.explode(state.ship_pos, val("radius"), atk() * val("damage"),
		{"cause": &"endBlast", "color": EFFECT_SETTINGS.tinted("trait/endBlast", Color("#c46bff")), "knock": def.params.knock})
