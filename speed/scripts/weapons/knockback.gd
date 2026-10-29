## W03 星砕き：最後の一撃が最大HPの8割以上なら、全攻撃から確率で砕く。
extends WeaponBehavior
func on_defeated(i: int, opts: Dictionary) -> void:
	if not opts.get("one_shot", false) or state.rng.randf() >= at_level("chance_by_level"): return
	ctx.projectiles.scatter_hull(i, opts.get("dir", Vector2.ZERO), float(p("speed")) * post_factor(&"projectile_speed"),
		cfg.hull_debris_damage * ctx.combat.attack_power() / cfg.base_attack * damage_factor(), cfg.hull_debris_knock * post_factor(&"knockback"),
		area(post_factor(&"area")), post_factor(&"duration"))
