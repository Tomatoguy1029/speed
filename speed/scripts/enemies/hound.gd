## 猟犬。噛みつきを共用し、近くの群れの仲間と速度・方向をそろえて追う。
extends "res://scripts/enemies/biter.gd"

## 群れの番号は最初に出た個体のID。特定の生存個体を頭にしない。
var packs: Dictionary = {}
var members: Dictionary = {}
var _pursuit: Dictionary = {}
## ボスが率いる個体の走る先（行 → [目標, 期限の世界時刻, 速さの倍率]）。期限が過ぎると群れの追跡へ戻る。
var follows: Dictionary = {}

## 行 i を、世界時刻 until まで goal へ走らせる。遠いほど速く、最大で自分の速さの speed_scale 倍。
func follow(i: int, goal: Vector2, until: float, speed_scale: float) -> void:
	follows[i] = [goal, until, speed_scale]

func setup(system: EnemySystem, behavior_name: StringName, idx: int) -> void:
	super(system, behavior_name, idx)
	watches_rows = true

func on_spawn(i: int, opts: Dictionary) -> void:
	var t := table
	var pack := int(opts.get("hound_pack", t.id[i]))
	if not packs.has(pack): packs[pack] = []
	packs[pack].append(i)
	members[i] = pack
	if not opts.has("vel"):
		t.vel[i] = (state.ship_pos - t.pos[i]).normalized() * t.speed[i]
		t.facing[i] = t.vel[i].angle()
	if opts.has("hound_pack"): return
	var p := t.def[i].params
	var count := maxi(1, int(p.pack_count))
	var direction := Vector2.from_angle(t.facing[i])
	var side := direction.orthogonal()
	var gap := maxf(0.0, float(p.pack_gap))
	# 置いた1体を含む数体の小さな塊。個体は通常の雑魚として扱う。
	for k in range(1, count):
		var at := t.pos[i] - direction * gap * float((k + 1) / 2) + side * gap * (0.5 if k % 2 else -0.5)
		var child := opts.duplicate()
		child["hound_pack"] = pack
		child["facing"] = t.facing[i]
		child["attack_group"] = t.attack_group[i]
		child["attack_value"] = t.attack_value[i]
		child["attack_priority"] = t.attack_priority[i]
		spawn(t.def[i], at, child)

func _running(i: int) -> bool:
	var t := table
	return t.alive[i] != 0 and t.dead[i] == 0 and t.held[i] == 0 and t.stone[i] <= 0.0 \
		and t.shove_time[i] <= 0.0 and t.knock_t[i] <= 0.0 and t.mode[i] != EnemyTable.Mode.WINDUP

func tick_rows(rows: PackedInt32Array, dt: float) -> void:
	_pursuit.clear()
	# 1回の更新前の位置・速度から全個体を計算し、行を回す順番への依存を避ける。
	for i in rows:
		if _running(i): _pursuit[i] = _pack_velocity(i)
	super(rows, dt)

func _pack_velocity(i: int) -> Vector2:
	var t := table
	var p := t.def[i].params
	var order: Array = follows.get(i, [])
	if not order.is_empty() and float(order[1]) >= state.world_time:
		return _follow_velocity(i, order)
	var chase := (state.ship_pos - t.pos[i]).normalized() * t.speed[i]
	var center := Vector2.ZERO
	var velocity := Vector2.ZERO
	var separation := Vector2.ZERO
	var count := 0
	var reach := maxf(1.0, float(p.pack_neighbor_radius))
	var gap := maxf(1.0, float(p.pack_gap))
	for j: int in packs[members[i]]:
		if j == i or not _running(j): continue
		var offset := t.pos[i] - t.pos[j]
		var distance := offset.length()
		if distance > reach: continue
		center += t.pos[j]
		velocity += t.vel[j]
		count += 1
		if distance > 0.001 and distance < gap:
			separation += offset / distance * (1.0 - distance / gap)
	if count == 0: return chase
	var desired := chase.lerp(velocity / count, clampf(float(p.pack_alignment), 0.0, 1.0))
	desired += (center / count - t.pos[i]) / reach * t.speed[i] * float(p.pack_cohesion)
	desired += separation * t.speed[i] * float(p.pack_separation)
	return desired.limit_length(t.speed[i])

## 率いられている間は群れの向きをそろえず、目標へ寄りながら仲間との間隔だけ保つ。
func _follow_velocity(i: int, order: Array) -> Vector2:
	var t := table
	var p := t.def[i].params
	var to: Vector2 = order[0] - t.pos[i]
	var top := t.speed[i] * float(order[2])
	var desired := to.normalized() * minf(top, to.length() / 0.25) if to.length_squared() > 1.0 else Vector2.ZERO
	var gap := maxf(1.0, float(p.pack_gap))
	var separation := Vector2.ZERO
	for j: int in packs[members[i]]:
		if j == i or not _running(j): continue
		var offset := t.pos[i] - t.pos[j]
		var distance := offset.length()
		if distance > 0.001 and distance < gap:
			separation += offset / distance * (1.0 - distance / gap)
	desired += separation * t.speed[i] * float(p.pack_separation)
	return desired.limit_length(top)

func _pursuit_velocity(i: int, ship: Vector2, dt: float) -> Vector2:
	var target: Vector2 = _pursuit.get(i, (ship - table.pos[i]).normalized() * table.speed[i])
	return table.vel[i].lerp(target, clampf(table.accel[i] * dt, 0.0, 1.0))

func on_row_gone(i: int) -> void:
	# 再配置では個体IDと群れを保つ。撃破・行の解放だけで抜ける。
	if table.dead[i] != 0: _remove(i)

func on_release(i: int) -> void:
	_remove(i)

func _remove(i: int) -> void:
	if not members.has(i): return
	var pack: int = members[i]
	packs[pack].erase(i)
	if packs[pack].is_empty(): packs.erase(pack)
	members.erase(i)
	_pursuit.erase(i)
	follows.erase(i)

func clear() -> void:
	packs.clear()
	members.clear()
	_pursuit.clear()
	follows.clear()
