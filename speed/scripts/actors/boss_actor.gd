## ボスの役者の共通の土台（設計書 4.2・6.1）。ボスのシーンのルートに付ける。
##
## 当たり判定の円は敵の表（EnemyTable）の1行（body）として入り、ボスの行動はこの役者が
## BossManager から決まった順番で呼ばれて動かす（sim_tick）。見た目はこのノードの子に置く。
class_name BossActor
extends Node2D

var manager: BossManager
## 当たり判定の円の、敵の表での行番号
var body := -1
var def: BossDef

var run_state: RunState:
	get: return manager.state
var table: EnemyTable:
	get: return manager.enemies.table

func bind(m: BossManager, row: int, d: BossDef) -> void:
	manager = m
	body = row
	def = d
	position = table.pos[row]
	_on_bound()

## 結び付いたあとの準備（各ボスで上書きする）。
func _on_bound() -> void:
	pass

## 固定更新1回ぶん（各ボスで上書きする）。
func sim_tick(_real_dt: float, _world_dt: float) -> void:
	pass

func _process(_delta: float) -> void:
	if manager != null and manager.has_boss():
		position = table.pos[body]
		rotation = table.facing[body]
