## 3択の間に候補を準備し、選ばなかった資源の保持を外す。
extends Node
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _ready() -> void:
	var session := RunManager.create_session(self, {"lab": true, "seed": 42}, false)
	var loadout := session.sim.loadout
	check(loadout.has_method("resources_for_card"), "候補ごとの資源を準備する")
	if loadout.has_method("resources_for_card"):
		loadout.open_start_cards()
		var cards: Array[Dictionary] = session.sim.state.cards.duplicate(true)
		var scopes := []
		for card in cards:
			var scope: RefCounted = loadout.resources_for_card(card.id)
			scopes.append(scope)
			check(scope != null and scope.is_ready(), "表示中の候補の資源を準備する")
		var entry := ContentManager.catalog.find(&"weapons", cards[0].id)
		check(scopes[0].resources.has(entry.path), "候補の定義を保持する")
		# ディスクの速度に依存せず、読込待ちの間だけ進行を保留することを確認する。
		scopes[0].pending.append("test_delay")
		session.sim.choose_card(0)
		check(session.sim.state.phase == RunState.Phase.LEVELUP and session.sim.state.weapons.is_empty(), "資源が揃うまで戦闘へ戻らない")
		scopes[0].provide("test_delay", Resource.new())
		session.sim.state.lab_mode = false
		session.sim.physics_step(0.0)
		check(session.sim.state.phase == RunState.Phase.PLAY and session.sim.state.weapons.has(cards[0].id), "準備完了後に選択を反映して戦闘へ戻る")
		check(not scopes[0].cancelled, "選んだ装備の資源を引き継ぐ")
		for index in range(1, scopes.size()): check(scopes[index].cancelled and scopes[index].resources.is_empty(), "選ばなかった候補を解放する")
	session.free()
	await get_tree().process_frame
	print("[equipment_resources] %d failures" % failed)
	get_tree().quit(1 if failed else 0)
