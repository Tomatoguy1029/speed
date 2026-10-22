## 隕石と彗星。漂流の動きと固有のドロップを持つ。
extends "res://scripts/enemies/drift.gd"
func _init() -> void:
	debug_spawnable = false

func coin_count(_row: int) -> int:
	return (1 + state.rng.randi_range(0, 2)) if state.rng.randf() < cfg.meteor_coin_chance else 0

func extra_drops(pickups: PickupSystem, i: int) -> void:
	var t := table
	var pos := t.pos[i]
	if state.rng.randf() < cfg.meteor_heal_chance:
		pickups._add_capsule(Pickup.Kind.HEAL, &"drop", pos)
	if state.rng.randf() < cfg.meteor_magnet_chance:
		pickups._add_capsule(Pickup.Kind.MAGNET, &"drop", pos)
	# レアな彗星は、決まった彗星限定の武器のカプセルを必ず落とす
	var weapon := field.comet_weapon(t.meteor_index[i])
	if weapon != &"":
		pickups._add_capsule(Pickup.Kind.COMET_WEAPON, &"comet", pos)
		pickups.capsules[pickups.capsules.size() - 1].weapon_id = weapon
