## 回収物ごとの取得効果を同じ入口で適用できる。
extends Node
var failed := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failed += 1
		push_error(message)
func _ready() -> void:
	var session := RunManager.create_session(self, {"lab": true, "seed": 42}, false)
	session.auto_step = false
	var sim := session.sim
	var pickups := sim.pickups
	check(pickups.has_method("effect"), "回収物ごとの効果を取得できる")
	if pickups.has_method("effect"):
		var coins := sim.state.coins
		pickups.collect(&"coin")
		check(sim.state.coins == coins + 1, "部品を1つ増やす")
		var xp := sim.state.xp_gained
		pickups.collect(&"gem", 1.0)
		check(sim.state.xp_gained > xp, "結晶の経験値を反映する")
		sim.state.ship_hp = 1.0
		var capsule := Pickup.new()
		capsule.kind = Pickup.Kind.HEAL
		pickups._apply(capsule)
		check(sim.state.ship_hp > 1.0, "回復カプセルがHPを回復する")
		sim.state.ship_hp = sim.state.stats.max_hp
		check(not pickups.effect(&"heal").can_collect(capsule), "HP満タンでは回復カプセルを吸い寄せない")
		capsule.kind = Pickup.Kind.COMET_WEAPON
		capsule.weapon_id = &"W21"
		pickups._apply(capsule)
		check(sim.state.pending_comet_weapons.has(&"W21"), "彗星武器の受け取りを予約する")
	session.free()
	await get_tree().process_frame
	print("[pickup_effects] %d failures" % failed)
	get_tree().quit(1 if failed else 0)
