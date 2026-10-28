## 敵の行動の種類ごとの処理の土台（設計書 6.1）。種類ごとに res://scripts/enemies/<行動名>.gd で上書きする。
##
## 1つのランで行動の種類（EnemyDef.behavior）ごとに1つだけ作り、その種類の全個体で共有する。
## 個体の状態は敵の表（EnemyTable）の列に持つ。EnemySystem は、その戦いに出た種類の Behavior だけを作って呼ぶ。
## 移動の補助（追跡・距離を保つ・射撃の時間など）はEnemyMotionを、同じ名前の関数から呼ぶ。
class_name EnemyBehavior
extends RefCounted

var m: EnemySystem
## 行動の種類の名前（EnemyDef.behavior）
var name: StringName
## 敵の表の beh 列の値
var index := 0
## 数の多い雑魚は、共通の前処理を自分のループに含めて tick_rows() で全行を進める
var custom_loop := false
## 高速移動など、画面外でも行動と移動区間の判定を毎回進める種類。
var full_rate := false
## 正の実効valueを持つ攻撃は枠を取ってから動く。自分で枠を取る種類は false
var admission := true
## ほかの種類の行が倒れた・空きに戻ったことも on_row_gone() で知りたいか（ほかの敵を抱える種類）
var watches_rows := false
## 接触の間隔（hit_cd）があっても、機体の接触を毎回調べるか（前面で弾く種類）
var ignores_hit_cd := false
## 画面から遠く離れたら、画面外の出現位置へ移すか。自分で退場する種類（横断する群れなど）は false
var recycles_far := true
var debug_spawnable := true

var table: EnemyTable:
	get: return m.table
var state: RunState:
	get: return m.state
var cfg: GameConfig:
	get: return m.cfg
var projectiles: ProjectileSystem:
	get: return m.projectiles
var field: FieldSystem:
	get: return m.field
## 1回の更新の中で共通に使う値（EnemySystem が更新の始めに読む）
var _aim: Vector2:
	get: return m._aim
var _vc: Vector2:
	get: return m._vc
var _vh: Vector2:
	get: return m._vh

func setup(system: EnemySystem, behavior_name: StringName, idx: int) -> void:
	m = system
	name = behavior_name
	index = idx

## この種類の行（倒れた行も、空きに戻るまでは含む）。
func rows() -> PackedInt32Array:
	return m.beh_rows[index]

# ── 種類ごとに上書きする入口 ────────────────────────────────────────

## 出た直後（行の値を入れ終えたあと）。opts は出すときの指定。
func on_spawn(_i: int, _opts: Dictionary) -> void:
	pass

## 1行ぶんの行動。押し出し・石化・遠い敵の間引きは EnemySystem が済ませてある。
func step(_i: int, _dt: float) -> void:
	pass

## 通常移動の直前。dt は実際に移動する世界秒（LODでまとめた判断時間とは別）。
func before_move(_i: int, _dt: float) -> void:
	pass

## custom_loop の種類だけ：この種類の全行を進める。
func tick_rows(_rows: PackedInt32Array, _dt: float) -> void:
	pass

## 全種類の行動が終わったあと（ほかの敵を動かす種類が使う）。
func after_tick(_dt: float) -> void:
	pass

## 機体の移動と通常の戦闘が終わったあと（ProjectileSystem が弾を進める前）。
func after_combat() -> void:
	pass

## 回収の更新のとき（ドロップを拾う種類が使う）。
func gather_pickups(_pk: PickupSystem, _dt: float) -> void:
	pass

## 攻撃が当たったときの扱い（EnemyTable.GateResult）。普段は敵の倒し方（EnemyDef.gate）の共通ルールに従う。
func gate(i: int, hit: Vector2, dir: Vector2, cause: StringName, dmg: float) -> int:
	return m.gate_rule(i, hit, dir, cause, dmg)

## 前面で攻撃を弾くか（命中した位置 hit、飛んできた向き dir）。
func blocks_front(_i: int, _hit: Vector2, _dir: Vector2) -> bool:
	return false

## 背面から盾を奪えるか。
func rear_open(_i: int, _hit: Vector2) -> bool:
	return false

## 攻撃の枠（攻撃の管理。仕様書 11.7）の判断。攻撃の最中か。
func admit_active(i: int, _d, _owner: String) -> bool:
	return table.mode[i] != EnemyTable.Mode.MOVE or not table.links[i].is_empty()

## 攻撃の枠を取りにいく時期か。普段は射撃の時間が予告の長さまで来たとき。
func admit_due(i: int, dt: float) -> bool:
	return table.fire_t[i] <= float(table.def[i].params.get("telegraph", 0)) + dt

## 攻撃の枠を持つ時間。
func admit_duration(i: int) -> float:
	var p: Dictionary = table.def[i].params
	return float(p.get("telegraph", p.get("windup", 0))) + float(p.get("dash_time", p.get("beam_time", p.get("blast_delay", 0.2)))) + 0.1

## 攻撃の許可を待っている間の移動。種類固有の距離の取り方は派生側で保つ。
func wait_for_attack(i: int, dt: float) -> void:
	_chase(i, dt)

## 隕石が増えた（隕石を遮る物として見る種類が使う）。
func rocks_changed() -> void:
	pass

## 撃破されたとき。atk は機体の攻撃力。
func on_death(_i: int, _atk: float) -> void:
	pass

## この種類の行が空きに戻る直前。
func on_release(_i: int) -> void:
	pass

## watches_rows の種類だけ：どの種類の行でも、撃破・空きに戻るとき。
func on_row_gone(_i: int) -> void:
	pass

## 全部の敵を消したとき。
func clear() -> void:
	pass

# ── EnemySystem の共通処理 ────────────────────────────────────────

func _chase(i: int, dt: float) -> void:
	m.motion._chase(i, dt)

func _steer_to(i: int, target: Vector2, speed: float, accel: float, dt: float) -> void:
	m.motion._steer_to(i, target, speed, accel, dt)

func _turn_toward(i: int, target: float, rate: float, dt: float) -> void:
	m.motion._turn_toward(i, target, rate, dt)

func _turn_moving(i: int, rate: float, dt: float) -> void:
	m.motion._turn_moving(i, rate, dt)

func _move_to(i: int, target: Vector2, speed: float, accel: float, turn: float, dt: float) -> void:
	m.motion._move_to(i, target, speed, accel, turn, dt)

func _keep_distance(i: int, dt: float) -> void:
	m.motion._keep_distance(i, dt)

func _gun_timer(i: int, dt: float) -> bool:
	return m.motion._gun_timer(i, dt)

func _hold(i: int, dt: float) -> void:
	m.motion._hold(i, dt)

func _drive(i: int, dt: float) -> void:
	m.motion._drive(i, dt)

func mark_dead(i: int) -> void:
	m.mark_dead(i)

func spawn(def: EnemyDef, pos: Vector2, opts := {}) -> int:
	return m.spawn(def, pos, opts)

func spawn_later(def: EnemyDef, pos: Vector2, opts := {}) -> void:
	m.spawn_later(def, pos, opts)

func spawn_part(i: int, def: EnemyDef, pos: Vector2) -> int:
	return m.spawn_part(i, def, pos)

func parts_alive(i: int) -> int:
	return m.parts_alive(i)

func def_of(type: StringName) -> EnemyDef:
	return m.def_of(type)

func is_same(i: int, id: int) -> bool:
	return m.is_same(i, id)

func _lab_admit(i: int, dt: float) -> bool:
	return m._lab_admit(i, dt)

func _lab_owner(i: int) -> String:
	return m._lab_owner(i)

## 接触を固有の動きで引き受けたらtrue。
func on_contact(_row: int, _dir: Vector2, _from: Vector2, _ship_speed: float) -> bool:
	return false

func extra_drops(_pickups: PickupSystem, _row: int) -> void:
	pass

func coin_count(_row: int) -> int:
	return 1 if state.rng.randf() < 0.03 else 0


func _self_destruct(i: int) -> void:
	var t := table
	var p: Dictionary = t.def[i].params
	projectiles.fire_zone(t.pos[i], float(p.blast_radius), 0.0, float(p.blast_dmg),
		ProjectileSystem.HazardStyle.BLAST, t.color[i])
	mark_dead(i)


func fire_volley(i: int) -> void:
	var p: Dictionary = table.def[i].params
	var base := (state.enemy_aim - table.pos[i]).angle()
	var n: int = p.volley
	var spread: float = p.spread
	for k in n:
		projectiles.fire_enemy(i, base + (float(k) / maxi(1, n - 1) - 0.5) * spread, p.bullet_speed, &"bullet")
