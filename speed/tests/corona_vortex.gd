## 冠だけの短い機構確認。実験用セッションを使い、本番のセーブ・録画へ書かない。
extends Node
var failed := 0
var passed := 0

func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error("[corona] " + label)

func _ready() -> void:
	var lab = load("res://gyms/enemy_lab/lab_session.gd").new()
	add_child(lab)
	await lab.reset({"empty": true, "stage": 4, "seed": 932, "ship_pos": [650, 0]})
	var m: EnemyManager = lab.run.enemies
	var t := m.table
	var crown := m.spawn(m.def_of(&"corona"), Vector2.ZERO)
	var ammo := m.spawn(m.def_of(&"biter"), Vector2(0, 100))
	m.table.fire_t[crown] = 0.0
	lab.run.combat.rebuild_grid()
	m.tick(0.12, 0.12)
	check(m.corona.members.has(ammo) and t.parts[crown].is_empty(), "既存の雑魚を捕捉し、専用の星を生成しない")
	var continuous := true
	var aligned := false
	var released := false
	for step in 70:
		var before := t.pos[ammo]
		var old_v := t.vel[ammo]
		m.tick(0.12, 0.12)
		lab.run.combat.rebuild_grid()
		continuous = continuous and t.pos[ammo].distance_to(before) < 100.0
		if m.corona.members.has(ammo) and m.corona.members[ammo].thrown:
			released = true
			var launch: Vector2 = m.corona.members[ammo].from
			aligned = t.vel[ammo].normalized().dot((m.state.ship_pos - launch).normalized()) > 0.99 \
				and t.vel[ammo].normalized().dot(old_v.normalized()) > 0.85
			break
	check(released and continuous and aligned and t.id[ammo] == int(m.corona.members[ammo].id), "粗い更新でも進行方向の一致をまたいで同じ個体が連続して発射される")
	if released:
		lab.run.ship.invincible = false
		m.state.ship_invuln = 0.0
		m.state.ship_pos = t.pos[ammo]
		m.corona.members[ammo].ship_from = m.state.ship_pos
		var hp := m.state.ship_hp
		m.corona.hit_thrown(m, lab.run.ship)
		m.corona.hit_thrown(m, lab.run.ship)
		check(is_equal_approx(hp - m.state.ship_hp, float(t.def[crown].params.throw_damage_biter)) and not m.corona.members.has(ammo), "投擲は種類の固定威力で1回だけ当たり、通常行動へ戻る")
	var r1 := RandomNumberGenerator.new()
	var r2 := RandomNumberGenerator.new()
	r1.seed = 19
	r2.seed = 19
	var one := {"types": {"biter": [1], "armored": [2]}}
	var many := {"types": {"biter": range(100), "armored": [2]}}
	check(m.corona.choose_type(one, t.def[crown].params, r1) == m.corona.choose_type(many, t.def[crown].params, r2) \
		and m.corona.choose_type({"types": {}}, {}, r1).is_empty(), "種類の抽選は個体数に依存せず、空プールを扱う")
	m.clear_all()
	crown = m.spawn(m.def_of(&"corona"), Vector2.ZERO)
	ammo = m.spawn(m.def_of(&"biter"), Vector2(0, 100))
	var second := m.spawn(m.def_of(&"biter"), Vector2(0, -100))
	m.state.ship_pos = Vector2(650, 0)
	lab.run.combat.rebuild_grid()
	m.table.fire_t[crown] = 0.0
	m.tick(0.02, 0.02)
	var selected := int(m.corona.owners[crown].selected)
	m.mark_dead(selected)
	check(m.corona.owners[crown].count == 1 and m.corona.owners[crown].selected == -1 \
		and not m.corona.members.has(selected), "予告中の撃破で弾薬と選択を即座に除去する")
	m.state.ship_pos = t.pos[crown]
	for step in 60: m.tick(0.02, 0.02)
	check(t.mode[crown] == EnemyTable.Mode.MOVE and m.corona.owners[crown].selected == -1, "軌道の内側では投擲も追加攻撃も始めない")
	var survivor := second if selected == ammo else ammo
	m.mark_dead(crown)
	check(m.corona.members.is_empty() and m.corona.owners.is_empty() and t.dead[survivor] == 0, "冠の撃破で残りの個体を生存した通常敵へ解放する")
	# 死亡行の再利用と、投擲の時間切れも実際の同じ表で確かめる。
	m.cleanup()
	crown = m.spawn(m.def_of(&"corona"), Vector2(200, 0))
	m.state.ship_pos = Vector2(850, 0)
	t.pos[survivor] = Vector2(200, 100)
	t.fire_t[crown] = 0.0
	lab.run.combat.rebuild_grid()
	for step in 80:
		m.tick(0.06, 0.06)
		lab.run.combat.rebuild_grid()
		if m.corona.members.has(survivor) and m.corona.members[survivor].thrown: break
	var thrown := m.corona.members.has(survivor) and bool(m.corona.members[survivor].thrown)
	if thrown:
		m.corona.members[survivor].life = 0.01
		m.tick(0.02, 0.02)
	check(thrown and not m.corona.members.has(survivor) and t.dead[survivor] == 0, "行再利用後も投擲でき、時間切れで通常敵へ戻る")
	lab.queue_free()
	await get_tree().process_frame
	print("[corona] passed=%d failed=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)
