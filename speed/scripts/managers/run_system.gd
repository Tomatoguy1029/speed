## ラン中の Manager の共通の土台（設計書 4.3）。
##
## ラン中の Manager は自分で _physics_process を回さない。RunManager が決まった順番で tick() を呼ぶ。
## ほかの Manager が必要なときは、RunManager が初期化のときに変数へ入れて渡す（設計書 4.4 の決まり2）。
class_name RunSystem
extends Node

var state: RunState
var cfg: GameConfig

## RunManager がランの開始時に呼ぶ。ほかの Manager はこれより前に変数へ入れてある。
func setup(run_state: RunState, config: GameConfig) -> void:
	state = run_state
	cfg = config

## 固定更新1回ぶん。real_dt は実秒、world_dt は世界秒。
func tick(_real_dt: float, _world_dt: float) -> void:
	pass
