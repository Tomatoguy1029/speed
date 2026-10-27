## 敵の共通の移動・旋回・射撃時間・遠方の衝突候補の補助。
class_name EnemyMotion
extends RefCounted
var m: EnemySystem
var table: EnemyTable:
	get: return m.table
var state: RunState:
	get: return m.state
var cfg: GameConfig:
	get: return m.cfg
var field: FieldSystem:
	get: return m.field
var _aim: Vector2:
	get: return m._aim
var _face_move: float:
	get: return m._face_move
func setup(system: EnemySystem) -> void:
	m = system

## 行 i の敵が、位置 p から margin 以内に天体があるか（FieldSystem.near_body と同じ条件）。
## 前回確かめたときの天体の表面までの距離から、その後に動いた距離と月が動けた距離を引き、
## まだ margin より遠ければ確かめずに false を返す。瞬間移動も、前回の位置からの距離に入る。
func _near_body(i: int, p: Vector2, margin: float, now: float, body_speed: float) -> bool:
	var t := table
	var gap := t.body_gap[i]
	if gap >= 0.0:
		var travelled := p.distance_to(t.body_gap_pos[i]) + (now - t.body_gap_time[i]) * body_speed
		if gap - travelled > margin:
			return false
	gap = field.body_gap(p, 4.0)
	t.body_gap[i] = maxf(gap, 0.0)
	t.body_gap_pos[i] = p
	t.body_gap_time[i] = now
	return gap < margin

## 押し出されている・吹き飛ばされている間の動き（行動の種類によらない）。
func _update_pushed(i: int, dt: float) -> void:
	var t := table
	if t.shove_time[i] > 0.0:
		t.shove_from[i] = t.pos[i]
		t.shoved[i] = 1
		t.shove_time[i] -= dt
		t.vel[i] = t.shove_vel[i]
		t.shove_vel[i] *= exp(-dt * 0.8)
	else:
		t.knock_t[i] -= dt
		t.vel[i] *= exp(-dt * 2.0)
	t.pos[i] += t.vel[i] * dt

## 敵の狙い：機体の遅れた位置（仕様書 7.5）。
func _update_aim(dt: float) -> void:
	# なぞりは自機だけ実時間で進む。世界側の照準はその間固定する。
	if state.tracing:
		return
	var d := state.ship_pos - state.enemy_aim
	var dist := d.length()
	if dist < 1e-6:
		return
	var step := minf(dist * (1.0 - exp(-dt / cfg.enemy_aim_lag)), cfg.enemy_aim_speed * dt)
	state.enemy_aim += d / dist * step

func _steer_to(i: int, target: Vector2, speed: float, accel: float, dt: float) -> void:
	var d := target - table.pos[i]
	var dist := d.length()
	if dist < 0.001:
		dist = 1.0
	var k := minf(1.0, accel * dt)
	table.vel[i] += (d / dist * speed - table.vel[i]) * k

func _turn_toward(i: int, target: float, rate: float, dt: float) -> void:
	table.facing[i] += clampf(Geom.angle_diff(target, table.facing[i]), -rate * dt, rate * dt)

## 移動中の向き：進む向きと機体への向きを config.enemy_face_move の割合で混ぜた向きへ回す。
func _turn_moving(i: int, rate: float, dt: float) -> void:
	var t := table
	var v := t.vel[i]
	var spd := maxf(t.speed[i], 1.0)
	var w := cfg.enemy_face_move * minf(1.0, v.length() / spd)
	var face := v.normalized() * w + (state.enemy_aim - t.pos[i]).normalized() * (1.0 - w)
	if face.length_squared() > 0.0025:
		_turn_toward(i, face.angle(), rate, dt)

## 追跡：18秒の周期で「接近」と「広域移動」を切り替える（仕様書 11.5）。
func _chase(i: int, _dt: float) -> void:
	var t := table
	var d := state.ship_pos - t.pos[i]
	var dist := d.length()
	if dist < 0.001:
		t.vel[i] = Vector2.ZERO
		return
	var u := d / dist
	t.vel[i] = u * t.speed[i]
	t.facing[i] = u.angle()

## 狙った位置へ速さ speed で向かい（加速 accel）、進む向きと機体への向きを混ぜた向きへ毎秒 turn まで回る。
## 追跡と距離を保つ動きの共通部分（よく呼ぶので、関数をまとめて呼び出しを減らす）。
func _move_to(i: int, target: Vector2, speed: float, accel: float, turn: float, dt: float) -> void:
	var t := table
	var from := t.pos[i]
	var d := target - from
	var dist := d.length()
	if dist < 0.001:
		dist = 1.0
	var v := t.vel[i]
	v += (d * (speed / dist) - v) * minf(1.0, accel * dt)
	t.vel[i] = v
	var w := _face_move * minf(1.0, v.length() / maxf(t.speed[i], 1.0))
	var face := v.normalized() * w + (_aim - from).normalized() * (1.0 - w)
	if face.length_squared() > 0.0025:
		var f := t.facing[i]
		var turn_max := turn * dt
		t.facing[i] = f + clampf(wrapf(face.angle() - f, -PI, PI), -turn_max, turn_max)

## 射撃型・ミサイル艇：機体の周りの keep の距離を保ち、回り込む。
func _keep_distance(i: int, dt: float) -> void:
	var t := table
	var aim := _aim
	var d := t.pos[i] - aim
	var dist := d.length()
	if dist < 0.001:
		dist = 1.0
	var u := d / dist
	var side := 1.0 if t.id[i] % 2 == 1 else -1.0
	var def := t.def[i]
	var keep: float = def.params.keep
	var target := aim + u * keep + Vector2(-u.y, u.x) * 200.0 * side
	if t.charge[i] > 0.0:
		# 撃つ前の予告の間は機体の方を向く
		_steer_to(i, target, t.speed[i], def.accel, dt)
		_turn_toward(i, (aim - t.pos[i]).angle(), 3.0, dt)
	else:
		_move_to(i, target, t.speed[i], def.accel, 3.0, dt)

## 発射までの時間を進める。予告の間は charge が 0〜1 で増える。撃つときに true。
func _gun_timer(i: int, dt: float) -> bool:
	var t := table
	var p: Dictionary = t.def[i].params
	t.fire_t[i] -= dt
	var tele: float = p.telegraph
	t.charge[i] = 1.0 - maxf(0.0, t.fire_t[i]) / tele if t.fire_t[i] < tele else 0.0
	if t.fire_t[i] <= 0.0:
		t.fire_t[i] = p.fire_interval
		return true
	return false

# ── 雑魚と硬めの敵の攻撃（仕様書 11.7） ─────────────────────────────

## 予告や攻撃の間、その場で止まる。
func _hold(i: int, dt: float) -> void:
	table.vel[i] *= maxf(0.0, 1.0 - 8.0 * dt)

# ── 強敵（仕様書 11.7・敵一覧） ──────────────────────────────────

## 大きく旋回しながら一定の速さで走る（ぎょしゃ座・わし座）。向きは turn の速さでしか変わらない。
func _drive(i: int, dt: float) -> void:
	var t := table
	_turn_toward(i, (state.enemy_aim - t.pos[i]).angle(), t.turn[i], dt)
	t.vel[i] = Vector2.from_angle(t.facing[i]) * t.speed[i]
