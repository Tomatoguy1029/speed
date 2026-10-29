## ボスの役者の共通の土台（設計書 4.2・6.1）。ボスのシーンのルートに付ける。
##
## 当たり判定の円は敵の表（EnemyTable）の1行（body）として入り、ボスの行動はこの役者が
## BossSystem から決まった順番で呼ばれて動かす（sim_tick）。見た目はこのノードの子に置く。
class_name BossActor
extends Node2D

var combat_trace := preload("res://scripts/bosses/combat_trace.gd").new()
## Adapter scopes natural AI; direct/debug callers keep the explicit external origin.
var combat_origin := "external_forced"
var ctx: RunContext
var body_id := 0
var registered := false
## 当たり判定の円の、敵の表での行番号
var body := -1
var def: BossDef
## true なら、役者が本体を自分で描く（RunPresentation はボスの行を描かない）
var draws_self := false
## 命中行IDごとの表示用状態。物理・照準・技の状態へは書き戻さない。
var hit_feedback := preload("res://scripts/bosses/boss_hit_feedback.gd").new()

var run_state: RunState:
	get: return ctx.state
var table: EnemyTable:
	get: return ctx.enemies.table

func bind(context: RunContext, row: int, d: BossDef) -> void:
	ctx = context
	body = row
	body_id = table.id[row]
	registered = true
	def = d
	position = table.pos[row]
	combat_trace.bind(self)
	_on_bound()

## 結び付いたあとの準備（各ボスで上書きする）。
func _on_bound() -> void:
	pass

## 固定更新1回ぶん（各ボスで上書きする）。
func sim_tick(_real_dt: float, _world_dt: float) -> void:
	pass

## 撃破済みの部位の行を空きへ戻す前の通知。row の HP・攻撃情報はまだ読み取れる。
## 部位の撃破で本体や再生の状態を変えるボスが上書きする。
func on_part_defeated(_row: int) -> void:
	pass

## 共通の被弾通知。役者がHP閾値と形態移行を確定する。
func on_body_damaged() -> void:
	pass

## trueならこの破壊は形態移行として役者が引き受ける。
func handle_body_defeat(_opts: Dictionary) -> bool:
	return false

func _process(_delta: float) -> void:
	if has_body():
		position = table.pos[body]
		rotation = table.facing[body]

## 上部HP表示の対象行。形態によって本命の部位へ切り替えられる。
func health_row()->int:
	return body

## 行を再利用した別の敵を、この役者の本体として扱わない。
func has_body() -> bool:
	return registered and ctx != null and ctx.enemies != null and ctx.enemies.is_same(body, body_id)

func body_alive() -> bool:
	return has_body() and table.dead[body] == 0

## 複数の命中形状を一体として受けるボスで上書きする。
func damage_target(row: int) -> int:
	return row

## 独立HPの複製を持つ役者は、その有効な命中先も含める。
func owns_damage_target(row: int) -> bool:
	return row == body and has_body()

func contains_hit(point: Vector2, radius: float) -> bool:
	return point.distance_to(table.pos[body]) <= table.r[body]+radius

## 独立HPを持つ複製など、追加の命中先の全身を追う。
func contains_additional_target(_row: int, _point: Vector2, _radius: float) -> bool:
	return false
