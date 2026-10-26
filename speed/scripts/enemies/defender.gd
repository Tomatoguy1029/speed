## 守る雑魚。近くの強敵・ボスと機体の間へ横一列に並び、守る相手がいない間は噛みつく。
extends "res://scripts/enemies/biter.gd"

## 1世界更新の間だけ共有する整列先。死亡・行解放・再出現で破棄する。
var _posts: Dictionary = {}
var _posts_tick := -1

func setup(system: EnemySystem, behavior_name: StringName, idx: int) -> void:
	super(system, behavior_name, idx)
	watches_rows = true

func on_spawn(_i: int, _opts: Dictionary) -> void:
	_posts_tick = -1

func on_row_gone(_i: int) -> void:
	_posts_tick = -1

func clear() -> void:
	_posts.clear()
	_posts_tick = -1

func _move_without_bite(i: int, dt: float) -> bool:
	if _posts_tick != m._lod:
		_assign_posts()
	var t := table
	if _posts.has(i):
		# 整列へ移ると進行中の噛みつきも取り消す。
		t.mode[i] = EnemyTable.Mode.MOVE
		t.timer[i] = 0.0
		t.charge[i] = 0.0
		var goal: Vector2 = _posts[i]
		var arrive := maxf(float(t.def[i].params.guard_arrive), 0.001)
		var speed := t.speed[i] * minf(t.pos[i].distance_to(goal) / arrive, 1.0)
		_steer_to(i, goal, speed, t.accel[i], dt)
		_turn_toward(i, (state.ship_pos - t.pos[i]).angle(), t.turn[i], dt)
		return true
	return false

## 強敵とボスの本体を一度だけ列挙し、同じ相手を守る個体をID順の列へ割り当てる。
## 並ぶ数は、その相手の近くに出現させた守る雑魚の数で決まる。
func _assign_posts() -> void:
	_posts.clear()
	_posts_tick = m._lod
	var t := table
	var strong: Array[int] = []
	for j in t.alive.size():
		if t.alive[j] == 0 or t.dead[j] != 0 or t.parent[j] >= 0 or t.held[j] != 0 or t.meteor_index[j] >= 0:
			continue
		if t.is_boss[j] != 0 or (t.def[j] != null and t.def[j].rank >= 3 and t.def[j].rank <= 5):
			strong.append(j)
	var ordered: Array[int] = []
	ordered.assign(rows())
	ordered.sort_custom(func(a: int, b: int): return t.id[a] < t.id[b])
	var groups: Dictionary = {}
	for i in ordered:
		if t.dead[i] != 0 or t.held[i] != 0:
			continue
		var nearest := -1
		var distance := pow(maxf(0.0, float(t.def[i].params.guard_radius)), 2.0)
		for j in strong:
			var d := t.pos[i].distance_squared_to(t.pos[j])
			if d < distance:
				distance = d
				nearest = j
		if nearest >= 0:
			if not groups.has(nearest): groups[nearest] = []
			groups[nearest].append(i)
	for j: int in groups:
		var members: Array = groups[j]
		var to_ship := state.ship_pos - t.pos[j]
		var forward := to_ship.normalized() if to_ship.length_squared() > 0.001 else Vector2.from_angle(t.facing[j])
		var side := Vector2(-forward.y, forward.x)
		# 上書き値や個体の大きさが異なっても、同じ列で重ならない間隔を共有する。
		var spacing := 0.0
		var offset := 0.0
		for i: int in members:
			spacing = maxf(spacing, maxf(float(t.def[i].params.guard_spacing), t.r[i] * 2.0))
			offset = maxf(offset, t.r[j] + t.r[i] + maxf(0.0, float(t.def[i].params.guard_distance)))
		offset = minf(offset, to_ship.length() * 0.5)
		for k in members.size():
			var i: int = members[k]
			_posts[i] = t.pos[j] + forward * offset + side * (float(k) - float(members.size() - 1) * 0.5) * spacing
