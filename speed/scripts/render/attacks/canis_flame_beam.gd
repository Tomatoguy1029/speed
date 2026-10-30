## 炎のビームと爆発。共通PixelFireと専用プリセットを使い、戦闘の長さ・半径へ合わせる。
extends AttackVisual
const DISPLAY := preload("res://scripts/bosses/canis_major/pixel_fire_display.gd")
@export var fire_preset: PixelFireSettings = preload("res://data/visuals/canis_fire_beam.tres")
var items: Dictionary = {}
var tails: Array = []
func begin_batch() -> void: pass
func draw_hazard(_c: CanvasItem, pr: ProjectileSystem, i: int, _view: Rect2) -> void:
	if pr.hazard_t[i] < pr.hazard_delay[i]: return
	if items.has(i) and float(pr.hazard_t[i])<float(items[i].get("last_time",0.0)):
		_retire(items[i])
		items.erase(i)
	if not items.has(i):
		var fire := DISPLAY.new()
		fire.setup(fire_preset)
		add_child(fire)
		items[i] = {"fire":fire,"born":state.world_time-pr.hazard_t[i],"zone":pr.hazard_kind[i]==ProjectileSystem.HazardKind.ZONE,"pos":pr.hazard_pos[i],"radius":pr.hazard_len[i]}
	var item: Dictionary = items[i]
	item.last_time = pr.hazard_t[i]
	if item.zone:
		item.fire.burst(item.pos,float(item.radius),clampf((state.world_time-float(item.born))/fire_preset.lifetime,0,1),state.world_time)
	else:
		var left := pr.hazard_delay[i]+pr.hazard_active[i]-pr.hazard_t[i]
		item.fire.beam(pr.hazard_pos[i],pr.hazard_angle[i],pr.hazard_len[i],pr.hazard_width[i],state.world_time,smoothstep(0.0,minf(0.08,pr.hazard_active[i]),left)*effect_tint.a)
func end_batch() -> void: pass

## 攻撃の線は通常弾のバッチ終了後に描かれるため、寿命は更新側で管理する。
func _retire(item: Dictionary) -> void:
	if item.zone and state.world_time-float(item.born)<fire_preset.lifetime: tails.append(item)
	else: item.fire.queue_free()

func update(_dt: float) -> void:
	for item in tails:
		var progress := (state.world_time-float(item.born))/fire_preset.lifetime
		if progress < 1.0: item.fire.burst(item.pos,float(item.radius),progress,state.world_time)
		else: item.fire.queue_free()
	tails = tails.filter(func(item): return state.world_time-float(item.born)<fire_preset.lifetime)
	var pr := rm.run.projectiles
	for i in items.keys():
		var item: Dictionary = items[i]
		var active: bool = i<pr.hazard_alive.size() and pr.hazard_alive[i]!=0 and String(pr.hazard_visual[i])==scene_file_path
		if active: continue
		var progress := (state.world_time-float(item.born))/fire_preset.lifetime
		if item.zone and progress < 1.0:
			item.fire.burst(item.pos,float(item.radius),progress,state.world_time)
		else:
			item.fire.queue_free()
			items.erase(i)

class BeamCanvas extends Node2D:
	const DISPLAY := preload("res://scripts/bosses/canis_major/pixel_fire_display.gd")
	var preset: PixelFireSettings = preload("res://data/visuals/canis_fire_trail.tres")
	var fires: Array = []
	func sync(beams: Array, clock: float) -> void:
		while fires.size() > beams.size(): fires.pop_back().queue_free()
		while fires.size() < beams.size():
			var fire := DISPLAY.new()
			fire.setup(preset)
			add_child(fire)
			fires.append(fire)
		for k in beams.size():
			var beam: Dictionary = beams[k]
			fires[k].beam(beam.from,float(beam.angle),float(beam.length),float(beam.width),clock,float(beam.alpha))
