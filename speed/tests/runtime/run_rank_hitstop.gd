## 星別の入力を実際の命中・保持点・ラン分離へ通す。
extends Node
const BUILD := preload("res://tools/content/build_run_content.gd")
const BRIDGE := preload("res://scripts/runtime/run_bridge.gd")
var failed := 0
var passed := 0

func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)

func fixture(rank: int, enabled := true, development := true):
	var config: GameConfig = ContentManager.base.duplicate(true)
	config.kill_hitstop = 0.04
	config.kill_hitstop_cap = 0.5
	config.hitstop_big_mult = 1
	config.start_radius = 0
	var definition: EnemyDef = ContentManager.enemies[&"biter"].duplicate(true)
	definition.rank = rank
	definition.stage_hp = 100
	definition.armor = 0
	definition.speed = 0
	definition.hitstop_multiplier = 0.5
	var records: Dictionary = BUILD.chase_records(definition, config)
	var bridge = BRIDGE.new()
	check(bridge.configure(BUILD.Schema.write_content(records, "星別の停止時間".sha256_buffer()), {"api_version":1,"run_id":42,"mode":1 if development else 0,"stage_id":"hitstop","profile":{},"settings":{"hitstop":enabled}}).ok, "命中確認用のランを設定する")
	check(bridge.start(42).ok, "命中確認用のランを開始する")
	return bridge

func change(bridge, rank, multiplier) -> Dictionary:
	var result: Dictionary = bridge.command("dev_edit", {"kind":"debug_action","payload":{"action":"rank_hitstop","args":{"rank":rank,"multiplier":multiplier}}})
	check(bridge.read_frame().ok and bridge.delivery_error.get("ok", true), "倍率変更後も通知とフレームを配信する")
	return result

func spawn(bridge) -> int:
	var result: Dictionary = bridge.command("dev_spawn", {"definition_id":"biter","position":Vector2(10000, 0)})
	check(result.ok, "命中対象を出現させる")
	return int(result.value.entity_id) if result.value is Dictionary else int(result.value)

func hit(bridge, id: int, crit := false, cause := "ram", amount := 100000.0) -> float:
	check(bridge.command("dev_damage", {"entity_id":id,"amount":amount,"cause":cause,"crit":crit}).ok, "共通の命中処理へ渡す")
	return float(bridge._core.combat_snapshot().hitstop)

func clear_stop(bridge) -> void:
	for n in 240:
		var result: Dictionary = bridge.step(1.0 / 120.0, BRIDGE.pack_intent(Intent.new()), {"logical_size":Vector2(1280,720)})
		if not result.ok:
			check(false, "停止時計の更新: " + result.message)
			return

func _ready() -> void:
	var saved: Dictionary = SaveManager.data.duplicate(true)
	for rank in range(1, 11):
		var bridge = fixture(rank)
		var current := spawn(bridge)
		check(change(bridge, rank, 0.25).ok, "★%dを変更する" % rank)
		check(is_equal_approx(hit(bridge, current), 0.005), "★%dは現在の敵にも種類別の倍率と合成する" % rank)
		check(change(bridge, rank, 0).ok, "★%dを停止なしへ変更する" % rank)
		# 新たな命中の前に停止時間と累積分を解消する。
		clear_stop(bridge)
		check(hit(bridge, spawn(bridge), true) == 0, "★%dの次の敵へのクリティカルも0で停止しない" % rank)
		check(change(bridge, 1 if rank != 1 else 2, 3).ok, "別の星を変更する")
		check(bridge.read_lab().value.debug_rank_hitstop[rank - 1] == 0, "他の星の編集が干渉しない")
		bridge.dispose()
	var bridge = fixture(1)
	var other = fixture(1)
	var owner := RunSession.new()
	owner.bridge = bridge
	var tab := preload("res://scripts/dev/debug_hitstop_tab.gd").new()
	tab.cpp_session = owner
	add_child(tab)
	tab.refresh()
	var events: Array = []
	bridge.subscribe("hitstop_test", func(frame: Dictionary) -> bool:
		events.append_array(frame.events)
		return true, [], ["debug_rank_hitstop_changed"])
	var held: Dictionary = bridge.checkpoint()
	check(held.ok, "変更前の保持点を作る")
	var edits := Time.get_ticks_usec()
	for n in 100: tab._sliders[0].value = 0.25 if n % 2 == 0 else 0.5
	print("[rank_hitstop] 100_slider_edits_ms=", (Time.get_ticks_usec() - edits) / 1000.0)
	check(events.size() == 100 and events.back().payload == {"rank":1,"multiplier":0.5}, "変更通知を録画と同じ配信経路で受ける")
	check(bridge.read_frame().ok and bridge.delivery_error.ok, "スライダー操作後もフレームの配信を継続する")
	check(tab._boxes[0].value == 0.5 and bridge.read_lab().value.debug_rank_hitstop[0] == 0.5, "スライダーと数値欄を同期してC++へ渡す")
	check(other.read_lab().value.debug_rank_hitstop[0] == 1, "別ランの設定を保つ")
	tab._boxes[0].value = 2
	check(tab._sliders[0].value == 2 and is_equal_approx(hit(bridge, spawn(bridge)), 0.04), "数値入力を実停止時間へ反映する")
	check(bridge.read_recording(true).value.conditions.debug_rank_hitstop[0] == 2, "途中開始の録画に試遊倍率を含める")
	clear_stop(bridge)
	check(hit(bridge, spawn(bridge), false, "shot") == 0, "弾の撃破へ停止を追加しない")
	check(bridge.restore(held.value).ok, "保持点へ復帰する")
	tab.refresh()
	check(tab._boxes[0].value == 1 and is_equal_approx(hit(bridge, spawn(bridge)), 0.02), "復帰した倍率と既定の停止時間を表示する")
	bridge.release_checkpoint(held.value)
	for invalid in [[0,1], [11,1], [1,-0.1], [1,INF], [1,NAN], [1,10.1], [1.0,1], [1,"1"]]:
		check(not change(bridge, invalid[0], invalid[1]).ok, "不正なランク・倍率を拒否する")
	check(bridge.read_lab().value.debug_rank_hitstop[0] == 1, "拒否した入力で倍率を変えない")
	for index in 10: tab._boxes[index].value = 0
	tab._reset()
	check(bridge.read_lab().value.debug_rank_hitstop == PackedFloat64Array([1,1,1,1,1,1,1,1,1,1]), "全星の倍率を戻す")
	# メニューの停止中にも編集し、閉じた後の命中へ適用する。
	check(bridge.command("pause", {"paused":true}).ok and change(bridge, 1, 10).ok, "ポーズ中に編集する")
	bridge.command("pause", {"paused":false})
	clear_stop(bridge)
	for n in 3: hit(bridge, spawn(bridge))
	check(is_equal_approx(bridge._core.combat_snapshot().dash_stop, 0.5), "星別の増幅後も累積停止の上限を守る")
	clear_stop(bridge)
	var boss := spawn(bridge)
	bridge.command("dev_enemy_combat", {"entity_id":boss,"is_boss":true})
	check(is_equal_approx(hit(bridge, boss), 0.02), "ボスは星別の倍率を使わない")
	check(SaveManager.data == saved, "試遊は保存データを変えない")
	check(ContentManager.enemies[&"biter"].hitstop_multiplier == 1, "種類別の保存値を保つ")
	tab.free()
	owner.bridge = null
	owner.free()
	bridge.dispose()
	other.dispose()
	bridge = fixture(0)
	change(bridge, 1, 0)
	check(is_equal_approx(hit(bridge, spawn(bridge)), 0.02), "星なしは星別の倍率を使わない")
	bridge.dispose()
	bridge = fixture(1, false)
	change(bridge, 1, 10)
	check(hit(bridge, spawn(bridge), true) == 0, "ヒットストップOFFを尊重する")
	bridge.dispose()
	bridge = fixture(1, true, false)
	check(not change(bridge, 1, 0).ok, "製品用ランでは開発調整を拒否する")
	bridge.dispose()
	print("[rank_hitstop] passed=%d failed=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)
