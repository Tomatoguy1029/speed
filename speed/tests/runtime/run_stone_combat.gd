## 石化した盾への通常接触・体当たり・弾・破片をC++の戦闘入口で確認する。
extends Node
const BUILDER := preload("res://tools/content/build_run_content.gd")
const BRIDGE := preload("res://scripts/runtime/run_bridge.gd")
var failed := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)

func _ready() -> void:
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.start_radius = 0.0
	config.base_attack = 100.0
	config.planet_radius = 0.0
	var definition: EnemyDef = ContentManager.enemies[&"shield"].duplicate(true)
	definition.stage_hp = 10.0
	definition.speed = 0.0
	var records: Dictionary = BUILDER.chase_records(definition, config)
	for mode in ["front_touch","front_ram","rear_ram","front_shots","back_shots","front_debris"]:
		var bridge = BRIDGE.new()
		check(bridge.configure(BUILDER.Schema.write_content(records, "石化した盾".sha256_buffer()), {"api_version":1,"run_id":42,"mode":1,"stage_id":"stone","profile":{},"settings":{}}).ok, "盾の戦闘定義を読み込む")
		check(bridge.start(42).ok, "石化の確認用ランを開始する")
		var core = bridge._core
		var at := Vector2(1000, 0)
		var id: int = core.spawn_enemy(&"shield", at, {"facing":0.0})
		check(id > 0 and core.set_enemy_motion(id, {"stone":1.0}), "盾を生成して石化する: " + mode)
		core.set_motion_context(at, at, Vector2(640, 360))
		check(core.rebuild_enemy_grid(config.grid_cell), "個別の戦闘更新の前に敵の空間索引を更新する")
		if mode.ends_with("touch") or mode.ends_with("ram"):
			var direction := Vector2.RIGHT if mode == "rear_ram" else Vector2.LEFT
			bridge.command("dev_ship_motion", {"position":at,"velocity":direction * (0.0 if mode.ends_with("touch") else 1000.0)})
			core.collide_ship(at - direction * 100.0, config.ship_radius)
		else:
			var direction := Vector2.RIGHT if mode == "back_shots" else Vector2.LEFT
			var from := at - direction * 100.0
			if mode.ends_with("debris"):
				check(bridge.command("dev_friend_births", {"births":[{"position":from,"velocity":direction*1200.0,"kind":1,"cause":"hullDebris","damage":100.0}]}).ok, "破片を共通の飛ぶ攻撃へ登録する")
			else:
				check(core.fire_shot(from, direction.angle(), 100.0, {"speed":1200.0,"life":1.0}), "石化した盾へ味方弾を出す")
			core.step_projectiles(0.2)
		var rows: Array = core.enemies_snapshot()
		check(rows.size() == 1 and rows[0].dead == 1, "石化した盾は前後の防御に遮られず砕ける: %s; enemies=%s" % [mode, rows])
		check(core.hostiles_snapshot().is_empty(), "石化中の盾から反射弾を出さない: " + mode)
		bridge.dispose()
	print("[run_stone_combat] failed=%d" % failed)
	get_tree().quit(1 if failed else 0)
