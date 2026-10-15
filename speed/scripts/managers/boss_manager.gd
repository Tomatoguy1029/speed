## ボス（仕様書 12.2・12.3・12.4、設計書 6.1）。出現・役者の登録・撃破。
##
## ボスは役者（BossActor のシーン）としてノードで作り、当たり判定の円を敵の表（EnemyTable）の1行として登録する。
## ボスの行動（形態・判断・攻撃）は役者のシーンの側で持ち、この Manager は特定のボスを知らない。
class_name BossManager
extends RunSystem

signal boss_spawned(actor: Node)

var enemies: EnemyManager
var projectiles: ProjectileManager
var field: FieldManager
## ボスの役者を置く場所（World の子）
var actor_parent: Node

var definitions: Dictionary = {}
var actor: BossActor = null
## ボスの当たり判定の行と、その id（ボスがいなければ boss_row は -1）
var boss_row := -1
var boss_id := 0
## 実験場だけで使う、独立した本体・役者の所有者。
var lab_instances: Array[BossManager] = []

func tick(real_dt: float, world_dt: float) -> void:
	for instance in lab_instances:
		instance.tick(real_dt, world_dt)
	if state.boss_at < 0.0:
		state.boss_at = cfg.boss_time + state.rng.randf() * cfg.boss_time_spread
	if not state.boss_spawned and not state.endless and state.time >= state.boss_at:
		spawn()
	if actor != null and boss_alive():
		if state.boss_stun > 0.0:
			# ペルセウス座の力で、少しの間止まる
			state.boss_stun -= real_dt
			enemies.table.vel[boss_row] = Vector2.ZERO
			return
		projectiles.lab_context = projectiles.director.token("boss:" + str(boss_id)) if projectiles.director != null else 0
		actor.sim_tick(real_dt, world_dt)
		projectiles.lab_context = 0

## ボスの行が残っているか（撃破の演出中を含む）。
func has_boss() -> bool:
	return boss_row >= 0 and enemies.is_same(boss_row, boss_id)

## ボスが撃破されずに残っているか。
func boss_alive() -> bool:
	return has_boss() and enemies.table.dead[boss_row] == 0

## 敵の行を解放する前に、今のボスの撃破済みの部位を役者へ渡す。
func part_defeated(row: int) -> void:
	for instance in lab_instances:
		instance.part_defeated(row)
	var t := enemies.table
	if actor != null and has_boss() and t.parent[row] == boss_row and t.parent_id[row] == boss_id:
		actor.on_part_defeated(row)

## ボスの位置。ボスがいなければ fallback。
func boss_pos(fallback: Vector2) -> Vector2:
	return enemies.table.pos[boss_row] if has_boss() else fallback

## ボスを出す（仕様書 12.2）。機体から少し離れた位置に出し、惑星の中と外縁の外は避ける。
func spawn(def_override: BossDef = null, position_override := Vector2.INF) -> void:
	var def: BossDef = def_override if def_override != null else definitions.get(state.stage.boss_id, ConfigManager.bosses.get(state.stage.boss_id))
	if def == null:
		return
	state.boss_spawned = true
	var distance := minf(1000.0, state.view_half.length() * 0.65)
	var p := state.ship_pos + Vector2.from_angle(state.rng.randf() * TAU) * distance
	if p.distance_to(field.planet.pos) < field.planet.r + 180.0:
		p = field.planet.pos + (state.ship_pos - field.planet.pos).normalized() * (field.planet.r + 220.0)
	if p.length() > cfg.field_radius - 160.0:
		p = p.normalized() * (cfg.field_radius - 160.0)
	if position_override != Vector2.INF:
		p = position_override
	boss_row = enemies.spawn_boss(def.id, p, def.radius * cfg.character_scale, cfg.boss_hp * cfg.enemy_hp_mult,
		cfg.boss_armor * cfg.enemy_armor_mult, def.xp, def.speed, def.weak_arc,
		(state.ship_pos - p).angle(), Color("#ff526e"))
	boss_id = enemies.table.id[boss_row]
	var scene := load(def.scene_path) as PackedScene
	actor = scene.instantiate() as BossActor
	actor_parent.add_child(actor)
	actor.bind(self, boss_row, def)
	state.emit(&"boss_spawn", {"pos": p})
	boss_spawned.emit(actor)

## ボスの HP が0になった（CombatManager から呼ばれる）。撃破の演出は RunManager が始める。
func on_boss_defeated(i: int, opts: Dictionary) -> void:
	if state.lab_mode:
		for instance in lab_instances:
			if instance.has_boss() and instance.boss_row == i:
				instance.on_boss_defeated(i, opts)
				return
		if has_boss() and boss_row == i:
			state.emit(&"boss_defeated", {"pos": enemies.table.pos[i]})
			remove_boss()
		return
	if state.boss_dead:
		return
	enemies.table.hp[i] = 0.0
	state.boss_dead = true
	state.emit(&"boss_defeated", {"pos": enemies.table.pos[i], "dir": opts.get("dir", Vector2.ZERO), "cause": opts.get("cause", &"")})

## 撃破の演出が終わったら、ボスを片付ける。
func remove_boss() -> void:
	for instance in lab_instances:
		instance.remove_boss()
		instance.queue_free()
	lab_instances.clear()
	if has_boss():
		enemies.mark_dead(boss_row)
	boss_row = -1
	if actor != null:
		actor.queue_free()
		actor = null

## 役者から呼ぶ：弾を撃つ。
func fire(angle: float, speed: float, params: Dictionary) -> void:
	projectiles.fire_enemy(boss_row, angle, speed, &"bullet", params)

## ラン単位のボス所有者を増やす。通常ランでは呼び出せない。
func spawn_lab(type: StringName, pos: Vector2) -> int:
	if not state.lab_mode or not ConfigManager.bosses.has(type):
		return -1
	var instance := BossManager.new()
	add_child(instance)
	instance.enemies = enemies
	instance.projectiles = projectiles
	instance.field = field
	instance.actor_parent = actor_parent
	instance.setup(state, cfg)
	lab_instances.append(instance)
	instance.definitions = definitions
	instance.spawn(definitions.get(type, ConfigManager.bosses[type]), pos)
	return instance.boss_row

## 技を構える前に、必要な分類を同時取得する。
func admit(key: String, cats: Array, row: int, duration: float) -> bool:
	if projectiles.director == null:
		return true
	return projectiles.director.request(key, cats, row, enemies.table.id[row], duration, 1.5)
