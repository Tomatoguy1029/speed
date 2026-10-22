## ケフェウス座の兵。
extends EnemyBehavior

func step(i: int, dt: float) -> void:
	_soldier(i, dt)

## 王の隊列の位置と向き。
func cepheus_slot(king: int, k: int) -> Array:
	return m.behavior(&"cepheus").cepheus_slot(king, k)

## ケフェウス座の兵：王が決めた隊列の位置へ動き（DASH）、着いたら止まって撃つ向きを向く（MOVE。撃つのは王の号令）。
## 王が倒れると（RECOVER）、機体への攻撃をやめ、近くの兵へ向き直って撃ち合い、mutiny の時間が過ぎると崩れて倒れる。
## 王がいないまま置かれた兵は、すぐに崩れる。
func _soldier(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	var king := t.target[i]
	if t.mode[i] == EnemyTable.Mode.RECOVER:
		_hold(i, dt)
		t.timer[i] -= dt
		t.fire_t[i] -= dt
		var foe := _nearest_soldier(i)
		if foe >= 0:
			_turn_toward(i, (t.pos[foe] - t.pos[i]).angle(), t.turn[i], dt)
			if t.fire_t[i] <= 0.0:
				t.fire_t[i] = float(p.mutiny_shot)
				state.emit(&"beam", {"from": t.pos[i], "to": t.pos[foe], "width": 4.0, "life": 0.12, "color": t.color[i].lightened(0.3)})
				projectiles.combat.damage_enemy(foe, t.max_hp[foe] * 0.35, {"cause": &"collapse", "no_crit": true})
		if t.timer[i] <= 0.0 and t.dead[i] == 0:
			projectiles.combat.kill_enemy(i, {"cause": &"collapse"})
		return
	if not self.is_same(king, t.target_id[i]) or t.dead[king] != 0:
		_start_mutiny(i, 0.4)
		return
	var slot := cepheus_slot(king, t.buds[i])
	if t.mode[i] == EnemyTable.Mode.DASH:
		var goal: Vector2 = slot[0]
		_steer_to(i, goal, t.speed[i], t.accel[i], dt)
		_turn_toward(i, (goal - t.pos[i]).angle(), t.turn[i], dt)
		if t.pos[i].distance_to(goal) < 8.0:
			t.pos[i] = goal
			t.vel[i] = Vector2.ZERO
			t.facing[i] = slot[1]
			t.mode[i] = EnemyTable.Mode.MOVE
		return
	t.vel[i] = Vector2.ZERO
	t.pos[i] = slot[0]
	_turn_toward(i, slot[1], t.turn[i], dt)

## 兵（行 i）の崩壊を始める。seconds ののちに崩れて倒れる。
func _start_mutiny(i: int, seconds: float) -> void:
	var t := table
	t.mode[i] = EnemyTable.Mode.RECOVER
	t.timer[i] = seconds
	t.fire_t[i] = state.rng.randf() * float(t.def[i].params.mutiny_shot)

## 兵（行 i）にいちばん近い、ほかの兵（いなければ -1）。
func _nearest_soldier(i: int) -> int:
	var t := table
	var best := -1
	var best_d := INF
	for j in rows():
		if j == i or t.dead[j] != 0:
			continue
		var d := t.pos[i].distance_squared_to(t.pos[j])
		if d < best_d:
			best_d = d
			best = j
	return best
