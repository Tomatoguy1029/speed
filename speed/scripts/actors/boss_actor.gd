## ボスの役者の共通の土台（設計書 4.2・6.1）。ボスのシーンのルートに付ける。
##
## 当たり判定の円は Enemy（body）として EnemyManager の配列に入り、ボスの行動はこの役者が
## BossManager から決まった順番で呼ばれて動かす（sim_tick）。見た目はこのノードの子に置く。
class_name BossActor
extends Node2D

var manager: BossManager
var body: Enemy
var def: BossDef

var run_state: RunState:
	get: return manager.state

func bind(m: BossManager, e: Enemy, d: BossDef) -> void:
	manager = m
	body = e
	def = d
	position = e.pos
	_on_bound()

## 結び付いたあとの準備（各ボスで上書きする）。
func _on_bound() -> void:
	pass

## 固定更新1回ぶん（各ボスで上書きする）。
func sim_tick(_real_dt: float, _world_dt: float) -> void:
	pass

func _process(_delta: float) -> void:
	if body != null:
		position = body.pos
		rotation = body.facing
