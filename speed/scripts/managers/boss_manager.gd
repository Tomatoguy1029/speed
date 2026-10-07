## ボス（仕様書 10・21・23、設計書 6.1）。出現・役者の登録・撃破。
##
## ボスは役者（BossActor のシーン）としてノードで作り、当たり判定の円を Enemy として配列に登録する。
## ボスの行動（形態・判断・攻撃）は役者のシーンの側で持ち、この Manager は特定のボスを知らない。
class_name BossManager
extends RunSystem

signal boss_spawned(actor: Node)

var enemies: EnemyManager
var projectiles: ProjectileManager
var field: FieldManager
## ボスの役者を置く場所（World の子）
var actor_parent: Node

var actor: BossActor = null
var boss: Enemy = null

func tick(real_dt: float, world_dt: float) -> void:
	if not state.boss_spawned and not state.endless and state.time >= cfg.boss_time:
		spawn()
	if actor != null and boss != null and not boss.dead:
		actor.sim_tick(real_dt, world_dt)

## ボスを出す（仕様書 10）。機体から少し離れた位置に出し、惑星の中と外縁の外は避ける。
func spawn() -> void:
	var def: BossDef = ConfigManager.bosses.get(state.stage.boss_id)
	if def == null:
		return
	state.boss_spawned = true
	var distance := minf(1000.0, state.view_half.length() * 0.65)
	var p := state.ship_pos + Vector2.from_angle(state.rng.randf() * TAU) * distance
	if p.distance_to(field.planet.pos) < field.planet.r + 180.0:
		p = field.planet.pos + (state.ship_pos - field.planet.pos).normalized() * (field.planet.r + 220.0)
	if p.length() > cfg.field_radius - 160.0:
		p = p.normalized() * (cfg.field_radius - 160.0)
	boss = Enemy.new()
	boss.id = -1
	boss.is_boss = true
	boss.type = def.id
	boss.pos = p
	boss.r = def.radius
	boss.max_hp = cfg.boss_hp * cfg.enemy_hp_mult
	boss.hp = boss.max_hp
	boss.armor = cfg.boss_armor * cfg.enemy_armor_mult
	boss.contact = def.contact
	boss.xp = def.xp
	boss.speed = def.speed
	boss.weak_arc = def.weak_arc
	boss.facing = (state.ship_pos - p).angle()
	boss.color = Color("#ff526e")
	enemies.add(boss)
	var scene := load(def.scene_path) as PackedScene
	actor = scene.instantiate() as BossActor
	actor_parent.add_child(actor)
	actor.bind(self, boss, def)
	state.emit(&"boss_spawn", {"pos": p})
	boss_spawned.emit(actor)

## ボスの HP が0になった（CombatManager から呼ばれる）。撃破の演出は RunManager が始める。
func on_boss_defeated(e: Enemy, opts: Dictionary) -> void:
	if state.boss_dead:
		return
	e.hp = 0.0
	state.boss_dead = true
	state.emit(&"boss_defeated", {"pos": e.pos, "dir": opts.get("dir", Vector2.ZERO), "cause": opts.get("cause", &"")})

## 撃破の演出が終わったら、ボスを片付ける。
func remove_boss() -> void:
	if boss != null:
		boss.dead = true
	if actor != null:
		actor.queue_free()
		actor = null

## 役者から呼ぶ：弾を撃つ。
func fire(angle: float, speed: float, params: Dictionary) -> void:
	projectiles.fire_enemy(boss, angle, speed, &"bullet", params)
