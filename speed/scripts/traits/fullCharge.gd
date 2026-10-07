## T04 満タン突撃：満タンから始めた線をなぞっている間は、装甲を無視して攻撃力が上がる（一覧 docs/traits.md）。
## 線が終わると BuildManager.on_end() で元に戻る。
extends TraitBehavior

func on_launch(full: bool) -> void:
	build.combat.ignore_armor = full
	build.combat.burst_power = val("mult") if full else 1.0
