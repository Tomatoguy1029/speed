## からす座。
extends EnemyBehavior

func step(i: int, dt: float) -> void:
	_crow(i, dt)

func setup(system: EnemySystem, behavior_name: StringName, idx: int) -> void:
	super(system, behavior_name, idx)
	recycles_far = false

## 群れの先頭として出たら、残りを隊列に並べて出す。
func on_spawn(i: int, opts: Dictionary) -> void:
	if not opts.get("flock_member", false):
		_spawn_flock(i, opts)

## からす座が、横を通り過ぎる経験値の結晶を拾う（敵の表の carry に足す）。拾うのは、体の真横から少し後ろまでにあり、
## 左右 gather_width の中にある結晶。前方の結晶は、横に来るまで拾わない。拾った結晶は足元の束へ飛び込む。
## 機体が吸い寄せ始めた結晶は機体が先に取る。
func gather_pickups(pk: PickupSystem, dt: float) -> void:
	var t := table
	var rows := rows()
	if rows.is_empty():
		return
	for j in rows:
		if t.dead[j] != 0:
			continue
		var p: Dictionary = t.def[j].params
		var width := float(p.gather_width)
		var behind := float(p.gather_behind)
		var reach := maxf(width, behind) + t.r[j]
		var reach_sq := reach * reach
		var step := float(p.gather_speed) * dt
		var u := Vector2.from_angle(t.facing[j])
		var feet := t.pos[j] - u * t.r[j] * 0.62
		for i in pk.gem_alive.size():
			if pk.gem_alive[i] == 0 or pk.gem_pulled[i] != 0 or pk.gem_wait[i] > 0.0:
				continue
			var rel := pk.gem_pos[i] - t.pos[j]
			if rel.length_squared() >= reach_sq:
				continue
			var along := rel.dot(u)
			if along > t.r[j] * 0.3 or along < -behind or absf(rel.cross(u)) > width:
				continue
			var d := feet - pk.gem_pos[i]
			var dist := d.length()
			if dist <= step + 4.0:
				t.carry[j] += pk.gem_value[i]
				t.buds[j] += 1
				if pk.records_xp():
					pk.record_xp({"type": "xp_transfer", "id": pk.gem_seq[i], "xp": pk.gem_value[i],
						"method": "crow", "enemy_id": t.id[j]})
				pk.gem_slots.release(i)
			else:
				pk.gem_pos[i] += d / dist * step

## からす座の群れの隊列（先頭からの位置。前へ x、右へ y、flock_gap 単位）。からす座の4つの星の並びにそろえる
const CROW_FORMATION := [Vector2(-1.0, -1.1), Vector2(-1.1, 1.0), Vector2(-2.1, 0.2)]

## からす座：先頭の1羽（行 i）の向きを決め、残りを隊列に並べて同じ向き・同じ速さで出す。
## 向きは、画面の中心から aim_spread だけずれた所を通る向き。画面の中心のすぐ近くに置かれた群れは、置いた向きのまま進む。
func _spawn_flock(i: int, opts: Dictionary) -> void:
	var t := table
	var def := t.def[i]
	var p: Dictionary = def.params
	var vc := state.view_center
	var vh := state.view_half
	var spread := float(p.aim_spread)
	var target := vc + Vector2(state.rng.randf_range(-spread, spread) * vh.x, state.rng.randf_range(-spread, spread) * vh.y)
	if target.distance_to(t.pos[i]) > minf(vh.x, vh.y) * 0.25:
		t.facing[i] = (target - t.pos[i]).angle()
	t.mode[i] = EnemyTable.Mode.DASH
	var u := Vector2.from_angle(t.facing[i])
	var side := Vector2(-u.y, u.x)
	var gap := float(p.flock_gap)
	for k in mini(int(p.flock) - 1, CROW_FORMATION.size()):
		var at: Vector2 = t.pos[i] + (u * CROW_FORMATION[k].x + side * CROW_FORMATION[k].y) * gap
		var j := spawn(def, at, {"facing": t.facing[i], "elite": opts.get("elite", false), "flock_member": true, "attack_group": t.attack_group[i], "attack_value": t.attack_value[i], "attack_priority": t.attack_priority[i]})
		t.mode[j] = EnemyTable.Mode.DASH

## からす座：群れで隊列を組み、機体を追わずに一直線に戦場を横断する（向きは出たときに _spawn_flock が決める）。
## 経験値の回収は PickupSystem が1羽ずつ行う（carry が運んでいる量）。
## 画面の外で exit_margin より離れ、さらに離れていくと、運んでいる経験値ごと退場する（撃破にはならない）。
func _crow(i: int, dt: float) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	var rel := t.pos[i] - _vc
	t.vel[i] = Vector2.from_angle(t.facing[i]) * t.speed[i]
	var margin := float(p.exit_margin)
	if (absf(rel.x) > _vh.x + margin or absf(rel.y) > _vh.y + margin) and rel.dot(t.vel[i]) > 0.0:
		mark_dead(i)
