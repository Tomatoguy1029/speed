## ラン中の System の共通の土台（設計書 4.3）。
##
## System は自分で更新を回さない。RunSimulation が決まった順番で tick() を呼ぶ。
## ほかの System・ランの状態・資源は、同じランの RunContext から引く。
class_name RunSystem
extends RefCounted

var ctx: RunContext
var state: RunState
var cfg: GameConfig

## RunSimulation がランの開始時に呼ぶ。ほかの System はこれより前に ctx へ入れてある。
func setup(context: RunContext) -> void:
	ctx = context
	state = context.state
	cfg = context.cfg

## 固定更新1回ぶん。real_dt は実秒、world_dt は世界秒。
func tick(_real_dt: float, _world_dt: float) -> void:
	pass
