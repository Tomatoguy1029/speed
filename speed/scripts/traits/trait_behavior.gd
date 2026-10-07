## 特性の発動の共通の土台（設計書 8.1）。発動のきっかけを持つ特性だけ、
## res://scripts/traits/<内部 ID>.gd で上書きする。能力値を変えるだけの特性は BuildManager が計算する。
class_name TraitBehavior
extends RefCounted

var build: BuildManager
var def: TraitDef
## 重ね数（1〜5）
var n := 1

var state: RunState:
	get: return build.state
var cfg: GameConfig:
	get: return build.cfg

func setup(b: BuildManager, d: TraitDef) -> void:
	build = b
	def = d

## params の base ＋ per × n。
func val(key: String) -> float:
	return float(def.params.get(key + "_base", 0.0)) + float(def.params.get(key + "_per", 0.0)) * n

func atk() -> float:
	return build.combat.attack_power()

func tick(_dt: float, _busy: bool) -> void:
	pass
func on_launch(_full: bool) -> void:
	pass
func on_trail(_run: TraceRun, _p0: Vector2, _p1: Vector2) -> void:
	pass
func on_kill(_cause: StringName) -> void:
	pass
func on_critical(_p: Vector2) -> void:
	pass
func on_hurt() -> void:
	pass
func on_end() -> void:
	pass
