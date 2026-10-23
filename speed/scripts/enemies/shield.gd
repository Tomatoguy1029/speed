## たて座：機体を追いながら盾の前面を向け続ける。前面は攻撃を弾き、背面から盾を奪える。
extends EnemyBehavior

func step(i: int, dt: float) -> void:
	var t := table
	t.fire_t[i] = maxf(0.0, t.fire_t[i] - dt)
	_steer_to(i, state.enemy_aim, t.speed[i], t.accel[i], dt)
	_turn_toward(i, (state.ship_pos - t.pos[i]).angle(), t.turn[i], dt)

func setup(system: EnemySystem, behavior_name: StringName, idx: int) -> void:
	super(system, behavior_name, idx)
	ignores_hit_cd = true

## 前面に当たった攻撃は、体当たりなら弾かれ、ほかは貫通してダメージを与えない。
func gate(i: int, hit: Vector2, dir: Vector2, cause: StringName, _dmg: float) -> int:
	if blocks_front(i, hit, dir):
		return EnemyTable.GateResult.BOUNCE if cause == &"ram" else EnemyTable.GateResult.PASS
	return EnemyTable.GateResult.ALLOW

## たて座の前面。命中した位置を使い、位置のない攻撃は飛んできた向きから判定する。
func blocks_front(i: int, hit: Vector2, dir: Vector2) -> bool:
	if table.stone[i] > 0.0:
		return false
	var d := hit - table.pos[i]
	if d.length_squared() < 0.01:
		d = -dir
	return d.length_squared() > 0.0 and absf(Geom.angle_diff(d.angle(), table.facing[i])) <= float(table.def[i].params.front_arc)

## 盾を奪える背面。側面の通常攻撃と、背後からの高速体当たりを分ける。
func rear_open(i: int, hit: Vector2) -> bool:
	return absf(Geom.angle_diff((hit - table.pos[i]).angle(), table.facing[i] + PI)) <= table.weak_arc[i]
