## T13 反応波動：ダメージを受けたとき、周りを押し返す波動（一覧 docs/game/catalog/traits.md）。
extends TraitBehavior
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")

func on_hurt() -> void:
	ctx.combat.explode(state.ship_pos, val("radius"), atk() * val("damage"),
		{"cause": &"reactive", "color": EFFECT_SETTINGS.tinted("trait/reactive", Color("#ff6b5a")), "knock": def.params.knock})
