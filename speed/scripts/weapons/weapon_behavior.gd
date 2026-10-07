## 武器の発動の共通の土台（設計書 8.1）。武器ごとに res://scripts/weapons/<内部 ID>.gd で上書きする。
##
## 発動のきっかけごとに決まった入口（関数）を持つ。BuildManager が、持っている武器の入口を呼ぶ。
## 数値は WeaponDef（.tres）の params から読む。
class_name WeaponBehavior
extends RefCounted

var build: BuildManager
var def: WeaponDef
var level := 1

var state: RunState:
	get: return build.state
var cfg: GameConfig:
	get: return build.cfg

func setup(b: BuildManager, d: WeaponDef) -> void:
	build = b
	def = d

## 表示 Lv に対応する性能段階（仕様書 6）。
func tier() -> int:
	return def.level_steps[clampi(level, 1, def.level_steps.size()) - 1]

## 威力・頻度・範囲の係数（仕様書 6）。
func dmg_k() -> float:
	return 1.0 + 0.3 * (tier() - 1)

func rate_k() -> float:
	return 1.0 + 0.12 * (tier() - 1)

func radius_k() -> float:
	return 1.0 + 0.1 * (tier() - 1)

func p(key: String, default = 0.0):
	return def.params.get(key, default)

func atk() -> float:
	return build.combat.attack_power()

# ── 発動のきっかけ ─────────────────────────────────────────────────
## 固定更新ごと。busy は描画中・なぞり中（このときは周期の攻撃を休む）
func tick(_dt: float, _busy: bool) -> void:
	pass
## なぞりの開始（full は満タンから始めたか）
func on_launch(_full: bool) -> void:
	pass
## なぞり・勢いで実際に動いた区間
func on_trail(_run: TraceRun, _p0: Vector2, _p1: Vector2) -> void:
	pass
## 高速の接触（貫通・弾かれのどちらでも）
func on_contact(_e: Enemy, _hit: Vector2, _dir: Vector2) -> void:
	pass
## 普段・高速を問わない接触
func on_any_contact(_e: Enemy) -> void:
	pass
func on_kill(_cause: StringName) -> void:
	pass
func on_end() -> void:
	pass
