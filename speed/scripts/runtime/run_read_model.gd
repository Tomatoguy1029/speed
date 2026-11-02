## C++の読取値だけから作る表示用の投影。ゲーム状態として書き戻さない。
extends RefCounted
signal frame_events(events: Array[Dictionary])
var input_source: Callable
class Values extends RefCounted:
	var data := {}
	func _get(key: StringName): return data.get(key)
	func gauge_amount() -> float: return float(data.get("gauge",0.0))*float(data.get("stats",{}).get("capacity",1.0))
	func body_gap(at: Vector2, radius: float) -> float:
		var gap := INF
		for body in data.get("bodies",[]): gap = minf(gap,at.distance_to(body.pos)-body.r-radius)
		return gap
	func budget(amount: float) -> float: return float(data.get("base_length",0.0))*amount*float(data.get("length_mult",1.0))
	func attack_power() -> float: return data.get("attack_power",0.0)
	func count() -> int:
		var t: Dictionary = data.get("table",{})
		return t.get("dead",[]).filter(func(dead): return not dead).size()
	func is_same(row: int, id: int) -> bool:
		var t: Dictionary = data.get("table",{})
		return row>=0 and row<t.get("id",[]).size() and t.id[row]==id and t.alive[row]
	func def_of(id: StringName) -> EnemyDef: return data.get("definitions",{}).get(id)
	func used_cost() -> float: return data.get("used",0.0)
	func categories(behavior: StringName) -> Array:
		return {&"shooter":["aimed"],&"beam":["beam"],&"missile":["homing"],&"dash":["dash"]}.get(behavior,[])
	func guard_active() -> bool: return data.get("guard_active",false)
	func flood_half(i: int, distance: float) -> float: return data.hazard_width[i]*0.5+tan(data.hazard_arc[i])*distance
	func wave_radius(i: int) -> float: return data.wave_radii.get(i,data.hazard_len[i])
var state := Values.new()
var enemies := Values.new()
var projectiles := Values.new()
var field := Values.new()
var combat := Values.new()
var draw := Values.new()
var ship := Values.new()
var bosses := {"definitions":{},"actors":[]}
var cfg: GameConfig
var input: InputRouter
var view_size := Vector2(1280,720)
var options := {"view_size":Vector2(1280,720)}
func _base_zoom() -> float:
	var size := _view_size()
	var factor := pow(cfg.zoom_ref_speed/maxf(cfg.zoom_ref_speed,state.data.get("stats",{}).get("max_speed",cfg.base_max_speed)),cfg.zoom_exp)
	return minf(size.x,size.y)/cfg.base_view*clampf(factor,cfg.zoom_min,1.0)
func _view_size() -> Vector2:
	return input.get_viewport().get_visible_rect().size if is_instance_valid(input) else view_size
const META_IDS := ["atk","charge","hp","length","pickup","reroll","speed","xp"]
func refresh(snapshot: Dictionary, ui: Dictionary) -> void:
	var meta := {}
	for i in snapshot.meta_levels.size(): meta[META_IDS[i]] = snapshot.meta_levels[i]
	var weapons := {}
	var traits := {}
	for item: Dictionary in snapshot.loadout.weapon_levels: weapons[StringName(item.id)] = item.level
	for item: Dictionary in snapshot.loadout.trait_levels: traits[StringName(item.id)] = item.level
	var values: Dictionary = snapshot.ship.duplicate(true)
	values.merge(snapshot.draw,true)
	values.merge({"phase":ui.phase,"time":snapshot.clock.time,"world_time":snapshot.clock.world_time,"camera_zoom":snapshot.camera_zoom,"cinematic_bars":snapshot.cinematic_bars,"view_half":snapshot.view_half,"view_center":snapshot.view_center,"stats":{"capacity":snapshot.capacity,"max_speed":snapshot.max_speed,"length_mult":snapshot.length_mult},"level":snapshot.loadout.level,"weapons":weapons,"traits":traits,"hero_power":StringName(snapshot.hero.power),"hero_active_t":snapshot.hero.active,"meta_override":meta,"lab_mode":snapshot.lab_mode},true)
	values.merge({"post_max_stacks":snapshot.loadout.post_max_stacks,"pending_levels":snapshot.loadout.pending_levels,"cards":snapshot.loadout.cards.candidates},true)
	values.stage = state.data.get("stage")
	state.data = values
	ship.data = {"invincible":snapshot.invincible}
	var table := {}
	for key in ["id","type","pos","vel","hp","max_hp","armor","speed","r","facing","dead","elite","gate","mode","charge","parent","is_boss","alive","def","parts","links","attack_managed","attack_value","attack_priority"]: table[key] = []
	for enemy: Dictionary in snapshot.enemies:
		for key in enemy: table[key].append(StringName(enemy[key]) if key=="type" else int(enemy[key]) if key in ["dead","elite","is_boss"] else enemy[key])
		table.alive.append(true)
		table.def.append(enemies.def_of(StringName(enemy.type)))
		table.parts.append([])
		table.links.append([])
		table.attack_managed.append(false)
		table.attack_value.append(0.0)
		table.attack_priority.append(0.0)
	enemies.data.table = table
	field.data = {"bodies":snapshot.bodies,"rocks":[],"wells":[]}
	combat.data = {"attack_power":snapshot.attack_power}
	draw.data = {"base_length":cfg.draw_length,"length_mult":snapshot.length_mult}
	var director := Values.new()
	var groups := {}
	for group: Dictionary in snapshot.director.groups:
		groups[group.token] = group
	var waiting := {}
	for request: Dictionary in snapshot.director.waiting: waiting[request.owner] = request
	director.data = {"groups":groups,"waiting":waiting,"reasons":{},"now":snapshot.director.now,"used":snapshot.director.used,"settings":snapshot.director.settings,"enabled":snapshot.director.enabled,"guard_active":snapshot.director.guard_active}
	var p := {"director":director,"lab_hazard_group":{},"lab_hostile_group":{},"wave_radii":{}}
	for key in ["hazard_alive","hazard_t","hazard_delay","hazard_pos","hazard_kind","hazard_arc","hazard_angle","hazard_len","hazard_width","hazard_gap_w","hazard_gap","hostile_alive","hostile_pos"]: p[key] = []
	for hazard: Dictionary in snapshot.hazards:
		p.hazard_alive.append(true)
		p.hazard_t.append(hazard.time)
		p.hazard_delay.append(hazard.delay)
		p.hazard_pos.append(hazard.pos)
		p.hazard_kind.append(hazard.get("kind",ProjectileSystem.HazardKind.ZONE))
		p.hazard_arc.append(hazard.get("arc",0.0))
		p.hazard_angle.append(hazard.get("angle",0.0))
		p.hazard_len.append(hazard.get("length",hazard.radius))
		p.hazard_width.append(hazard.get("half_width",0.0)*2.0)
		p.hazard_gap_w.append(hazard.get("gap_arc",0.0))
		p.hazard_gap.append(hazard.get("gap_angle",0.0))
		p.wave_radii[p.hazard_alive.size()-1] = hazard.radius
		p.lab_hazard_group[p.hazard_alive.size()-1] = hazard.token
	for shot: Dictionary in snapshot.hostiles:
		p.hostile_alive.append(true)
		p.hostile_pos.append(shot.pos)
	projectiles.data = p
