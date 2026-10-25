## 分裂する雑魚：追いながら一定の間隔で分裂体を生み、倒されると分かれる。
extends EnemyBehavior

func step(i: int, dt: float) -> void:
	_chase(i, dt)
	_split(i, dt)

func _split(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	t.bud_t[i] += dt
	if t.bud_t[i] < float(p.bud_interval):
		return
	t.bud_t[i] = 0.0
	if t.buds[i] >= int(p.max_buds):
		return
	var a := bud_angle(i)
	t.buds[i] += 1
	spawn_later(def_of(&"splitling"), t.pos[i] + Vector2.from_angle(a) * t.r[i] * 1.2,
		{"facing": a, "vel": Vector2.from_angle(a) * 160.0, "hit_cd": 0.2, "attack_priority": t.attack_priority[i]})
	state.emit(&"bud", {"pos": t.pos[i] + Vector2.from_angle(a) * t.r[i], "color": t.color[i]})

## 分裂する雑魚が次の分裂体を生む向き（育っていく芽の位置。描画も同じ向きを使う）。
func bud_angle(i: int) -> float:
	return float(table.id[i]) * 2.39996322973 + float(table.buds[i]) * 2.399963

## 撃破で分かれる。
func on_death(i: int, _atk: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	if int(p.get("death_split", 0)) <= 0:
		return
	var n := maxi(1, int(p.get("death_split", 2)) + state.rng.randi_range(0, int(p.get("split_extra", 0))))
	var facing := t.facing[i]
	var child := def_of(&"splitling")
	for k in n:
		var a := facing + PI / 2.0 + TAU * float(k) / float(n) if n > 2 else facing + (1.0 if k == 1 else -1.0) * PI / 2.0
		spawn_later(child, t.pos[i] + Vector2.from_angle(a) * t.r[i],
			{"facing": a, "vel": Vector2.from_angle(a) * float(p.get("split_speed", 200.0)), "hit_cd": 0.35,
			"guard": float(p.get("split_guard", 0.0)), "knock": float(p.get("split_guard", 0.0)), "attack_priority": t.attack_priority[i]})
