## 永続強化の計算結果をランへ値として渡し、実験場も同じ計算を使う。
extends Node
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	var profile := get_node_or_null("/root/ProfileManager")
	check(profile != null, "永続強化の計算をProfileManagerが持つ")
	if profile != null:
		var values: Dictionary = profile.compute({"speed": 2, "hp": 3, "charge": 2})
		check(is_equal_approx(values.mult.get(&"max_speed", 1.0), 1.1), "速度の加算倍率を保つ")
		check(values.add.get(&"max_hp", 0.0) == 60.0, "HPの加算を保つ")
		var charge := ContentManager.catalog.find(&"meta_upgrades", &"charge")
		check(is_equal_approx(values.reduce[&"charge_time"], pow(1.0 - charge.per_level, 2)), "充填時間の累乗を保つ")
		var session := RunManager.create_session(self, {"lab": true, "seed": 42, "meta": {"speed": 2}}, false)
		var speed := session.sim.state.stats.max_speed
		check(is_equal_approx(speed, session.sim.cfg.base_max_speed * 1.1), "実験場でも同じ基礎性能を使う")
		profile.compute({"speed": 0})
		session.sim.loadout.refresh_stats()
		check(is_equal_approx(session.sim.state.stats.max_speed, speed), "別の計算が進行中ランの値を変えない")
		session.free()
	print("[profile_values] %d failures" % failed)
	get_tree().quit(1 if failed else 0)
