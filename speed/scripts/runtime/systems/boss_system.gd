## ボス（仕様書 12.2・12.3・12.4、設計書 6.1）。出現・役者の登録・撃破。
##
## ボスは役者（BossActor のシーン）としてノードで作り、当たり判定の円を敵の表（EnemyTable）の1行として登録する。
## ボスの行動（形態・判断・攻撃）は役者のシーンの側で持ち、この Manager は特定のボスを知らない。
class_name BossSystem
extends RunSystem

signal boss_spawned(actor: Node)

var enemies: EnemySystem:
	get: return ctx.enemies
var projectiles: ProjectileSystem:
	get: return ctx.projectiles
var field: FieldSystem:
	get: return ctx.field
## ボスの役者を置く場所（World の子）
var actor_parent: Node

var definitions: Dictionary = {}
## 1つのSystemが、本番・実験場のすべての役者を所有する。
var actors: Array[BossActor] = []
var actor: BossActor:
	get: return actors[0] if not actors.is_empty() else null
var boss_row: int:
	get: return actor.body if actor != null else -1
var boss_id: int:
	get: return actor.body_id if actor != null else 0

func tick(real_dt: float, world_dt: float) -> void:
	if state.stage.boss_enabled and state.boss_at < 0.0:
		state.boss_at = state.stage.boss_start(cfg)
		if state.stage.boss_time < 0.0:
			state.boss_at += state.rng.randf() * cfg.boss_time_spread
	if state.stage.boss_enabled and not state.boss_spawned and not state.endless and state.time >= state.boss_at:
		spawn()
	if state.boss_stun > 0.0:
		state.boss_stun -= real_dt
		for owner in actors:
			if owner.body_alive():
				enemies.table.vel[owner.body] = Vector2.ZERO
		return
	for owner in actors.duplicate():
		if owner.body_alive():
			projectiles.lab_context = projectiles.director.token("boss:" + str(owner.body_id)) if projectiles.director != null else 0
			owner.sim_tick(real_dt, world_dt)
			projectiles.lab_context = 0

## ボスの行が残っているか（撃破の演出中を含む）。
func has_boss() -> bool:
	return actor != null and actor.has_body()

## ボスが撃破されずに残っているか。
func boss_alive() -> bool:
	return actor != null and actor.body_alive()

## 描画する本体の役者を、本番・実験場で同じ行と ID の照合で探す。
func actor_for_row(row: int) -> BossActor:
	for owner in actors:
		if owner.body == row and owner.has_body():
			return owner
	return null

## 敵の行を解放する前に、今のボスの撃破済みの部位を役者へ渡す。
func part_defeated(row: int) -> void:
	var t := enemies.table
	var owner := actor_for_row(t.parent[row])
	if owner != null and t.parent_id[row] == owner.body_id:
		owner.on_part_defeated(row)

## ボスの位置。ボスがいなければ fallback。
func boss_pos(fallback: Vector2) -> Vector2:
	return enemies.table.pos[boss_row] if has_boss() else fallback

## ボスを出す（仕様書 12.2）。機体から少し離れた位置に出し、惑星の中と外縁の外は避ける。
func spawn(def_override: BossDef = null, position_override := Vector2.INF) -> void:
	_spawn_actor(def_override, position_override)

func _spawn_actor(def_override: BossDef, position_override: Vector2) -> BossActor:
	var def: BossDef = def_override if def_override != null else definitions.get(state.stage.boss_id, ConfigManager.bosses.get(state.stage.boss_id))
	if def == null:
		return null
	state.boss_spawned = true
	var distance := minf(1000.0, state.view_half.length() * 0.65)
	var p := state.ship_pos + Vector2.from_angle(state.rng.randf() * TAU) * distance
	if p.distance_to(field.planet.pos) < field.planet.r + 180.0:
		p = field.planet.pos + (state.ship_pos - field.planet.pos).normalized() * (field.planet.r + 220.0)
	if p.length() > cfg.field_radius - 160.0:
		p = p.normalized() * (cfg.field_radius - 160.0)
	if position_override != Vector2.INF:
		p = position_override
	var row := enemies.spawn_boss(def.id, p, def.radius * cfg.character_scale, cfg.boss_hp * cfg.enemy_hp_mult,
		cfg.boss_armor * cfg.enemy_armor_mult, def.xp, def.speed, def.weak_arc,
		(state.ship_pos - p).angle(), Color("#ff526e"))
	var scene := load(def.scene_path) as PackedScene
	var owner := scene.instantiate() as BossActor
	actors.append(owner)
	actor_parent.add_child(owner)
	owner.bind(ctx, row, def)
	state.emit(&"boss_spawn", {"pos": p})
	boss_spawned.emit(owner)
	return owner

## 本体行への被弾を、対応する役者へ通知する。
func body_damaged(row: int) -> void:
	var owner := actor_for_row(row)
	if owner != null:
		owner.on_body_damaged()

## ボスの HP が0になった（CombatSystem から呼ばれる）。撃破の演出は RunManager が始める。
func on_boss_defeated(i: int, opts: Dictionary) -> void:
	var owner := actor_for_row(i)
	if owner != null and opts.get("cause", &"") != &"debug" and owner.handle_body_defeat(opts):
		return
	if state.lab_mode:
		if owner != null:
			state.emit(&"boss_defeated", {"pos": enemies.table.pos[i]})
			remove_actor(owner)
		return
	if state.boss_dead:
		return
	enemies.table.hp[i] = 0.0
	state.boss_dead = true
	state.emit(&"boss_defeated", {"pos": enemies.table.pos[i], "dir": opts.get("dir", Vector2.ZERO), "cause": opts.get("cause", &"")})

## 撃破の演出が終わったら、ボスを片付ける。
func remove_boss() -> void:
	for owner in actors.duplicate():
		remove_actor(owner)

func remove_actor(owner: BossActor) -> void:
	if owner == null or not actors.has(owner):
		return
	if owner.has_body():
		enemies.mark_dead(owner.body)
	owner.registered = false
	actors.erase(owner)
	owner.queue_free()

## 実験場も同じ役者一覧へ追加する。通常ランでは呼び出せない。
func spawn_lab(type: StringName, pos: Vector2) -> int:
	if not state.lab_mode or not ConfigManager.bosses.has(type):
		return -1
	var owner := _spawn_actor(definitions.get(type, ConfigManager.bosses[type]), pos)
	return owner.body if owner != null else -1

## 技を構える前に、必要な分類を同時取得する。
func admit(key: String, cats: Array, row: int, duration: float) -> bool:
	if projectiles.director == null or projectiles.director.formation_mode:
		return true
	return projectiles.director.request(key, cats, row, enemies.table.id[row], duration, 1.5)
