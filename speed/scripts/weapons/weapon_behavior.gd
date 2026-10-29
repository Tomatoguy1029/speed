## 武器の発動の共通の土台（設計書 8.1）。武器ごとに res://scripts/weapons/<内部 ID>.gd で上書きする。
##
## 発動のきっかけごとに決まった入口（関数）を持つ。LoadoutSystem が、持っている武器の入口を呼ぶ。
## 数値は WeaponDef（.tres）の params から読む。
class_name WeaponBehavior
extends RefCounted

var ctx: RunContext
var def: WeaponDef
var level := 1

var state: RunState:
	get: return ctx.state
var cfg: GameConfig:
	get: return ctx.cfg

func setup(context: RunContext, d: WeaponDef) -> void:
	ctx = context
	def = d

## 表示 Lv に対応する性能段階（仕様書 8）。
func tier() -> int:
	return def.level_steps[clampi(level, 1, def.level_steps.size()) - 1]

## 威力・頻度・範囲の係数（仕様書 8）。
func dmg_k() -> float:
	return 1.0 + 0.3 * (tier() - 1)

func rate_k() -> float:
	return 1.0 + 0.12 * (tier() - 1)

func radius_k() -> float:
	return (1.0 + 0.1 * (tier() - 1)) * ctx.loadout.area_multiplier()

func p(key: String, default = 0.0):
	var value: Variant = def.params.get(key, default)
	var targets := cfg.post_max.target(def.id)
	if key in targets.get("area", []):
		return value.map(func(v):return float(v)*post_factor(&"area")) if value is Array else float(value)*post_factor(&"area")
	if key in targets.get("duration", []):
		return value.map(func(v):return float(v)*post_factor(&"duration")) if value is Array else float(value)*post_factor(&"duration")
	if key == "knock" or key == "chain_knock":
		return float(value) * post_factor(&"knockback")
	return value

func post_factor(id: StringName) -> float:
	var key := String(id)
	if id == &"projectile_speed": key = "projectile"
	if id in [&"projectile_speed", &"duration", &"knockback", &"area"] and not cfg.post_max.target(def.id).has(key):
		return 1.0
	return cfg.post_max.factor(id, state.post_max_stacks)

func damage_factor() -> float:
	return 1.0 + cfg.post_max.amount(&"weapon_damage", state.post_max_stacks) + \
		(cfg.post_max.amount(&"followup", state.post_max_stacks) if cfg.post_max.target(def.id).has("followup") else 0.0)

func interval(base: float) -> float:
	if not cfg.post_max.target(def.id).has("interval"): return base
	return cfg.post_max.reduced(base, &"weapon_interval", state.post_max_stacks, cfg.post_max.minimum_interval)

## 武器から発射する弾だけを補正する。特性の弾と共通ProjectileSystemは基準を保つ。
func fire_shot(from: Vector2, angle: float, dmg: float, opts := {}) -> void:
	var enhanced := opts.duplicate()
	enhanced.r = float(opts.get("r", 5.0)) * ctx.loadout.area_multiplier()
	enhanced.speed = float(opts.get("speed", 1300.0)) * post_factor(&"projectile_speed")
	enhanced.knock = float(opts.get("knock", 250.0)) * post_factor(&"knockback")
	ctx.projectiles.fire_shot(from, angle, dmg, enhanced)

## 独自のLv配列を使う武器も同じ範囲補正へつなぐ。
func area(value: float) -> float:
	return value * ctx.loadout.area_multiplier()

func shots(base: int) -> int:
	return ctx.loadout.shot_count(base)

func shooting_interval(base: float) -> float:
	return interval(base) / ctx.loadout.shooting_rate()

func at_level(key: String) -> float:
	var values: Array = p(key)
	return float(values[clampi(level - 1, 0, values.size() - 1)])

func atk() -> float:
	return ctx.combat.attack_power() * damage_factor()

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
## 高速の接触（貫通・弾かれのどちらでも）。_i は触れた敵の行番号
func on_contact(_i: int, _hit: Vector2, _dir: Vector2) -> void:
	pass
## 普段・高速を問わない接触。_i は触れた敵の行番号
func on_any_contact(_i: int) -> void:
	pass
func on_ram_hit(_i: int, _hit: Vector2, _dir: Vector2, _damage: float) -> void:
	pass

func dispose() -> void:
	pass

func on_kill(_cause: StringName) -> void:
	pass
func on_end() -> void:
	pass

## 世界時間に依存しない装備の更新。
func tick_real(_dt: float) -> void:
	pass

func on_phase_changed(_phase: RunState.Phase) -> void:
	pass
