## おおいぬ座だけが持つ、技の終了後も残る炎。更新・判定は世界時間、描画は同じ状態を読む。
extends Node2D
const COMPONENTS := preload("res://scripts/render/fx/visual_effect_components.gd")
const VISUAL_SETTINGS := preload("res://data/visuals/effect_settings.tres")
const NOVA_KEY := "res://scenes/bosses/canis_major/nova_visual.tscn"
var tints: Dictionary = {}
var nova: RefCounted
var flash: ColorRect
var burning: Dictionary = {}
var transfers: Array = []
var particles: Array = []
const FIRE_DISPLAY := preload("res://scripts/bosses/canis_major/pixel_fire_display.gd")
const IGNITE_FIRE := preload("res://data/visuals/canis_fire_ignite.tres")
const HOUND_FIRE := preload("res://data/visuals/canis_fire_hound.tres")
var fire_displays: Dictionary = {}
const FLAME_FIRE := preload("res://data/visuals/canis_fire_flame.tres")
const TRAIL_FIRE := preload("res://data/visuals/canis_fire_trail.tres")
var jets: Array = []
var bursts: Array = []
var _burst_id := 0
var actor: CanisMajorBoss
var trails: Array = []
var warnings: Array = []

func bind(host: CanisMajorBoss) -> void:
	actor = host
	top_level = true
	position = Vector2.ZERO
	rotation = 0.0
	var layer := CanvasLayer.new()
	layer.layer = 80
	add_child(layer)
	flash = ColorRect.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(1,1,1,0)
	layer.add_child(flash)

## 射程は保ち、口元で生まれた炎だけが順に前へ進む。
func start_jet(from: Vector2, angle: float, length: float, width: float, duration: float, damage: float, preset: PixelFireSettings, source := -1) -> Dictionary:
	var jet := {"from":from,"angle":angle,"length":length,"width":width,"duration":duration,"damage":damage,"preset":preset,
		"particle_life": float(actor.rule().get("beam_particle_life", 0.65)), "age":0.0,"emit":0.0,"source":source,"id":actor.table.id[source] if source>=0 else 0,"attack":actor.technique,"hit":false}
	if source>=0: jet.from = actor.table.pos[source]+Vector2.from_angle(angle)*actor.table.r[source]
	jets.append(jet)
	_emit_jet_particle(jet)
	return jet

func _emit_jet_particle(jet: Dictionary) -> void:
	var life: float = maxf(0.1, float(jet.particle_life))
	var drag := 0.7
	var spread := rad_to_deg(atan2(float(jet.width)*1.4,maxf(1.0,float(jet.length))))*2.0
	var r := {"spread":spread,"particle_speed":float(jet.length)*drag/(1.0-exp(-drag*life)),"life":life,"drag":drag,
		"r_start":float(jet.width)*0.5,"r_end":float(jet.width)*1.6,"hit_scale":0.85,"damage":jet.damage}
	flame_particle(jet.from,float(jet.angle),r,true,jet.preset)
	var particle: Dictionary = particles.back()
	particle.attack = jet.attack
	particle.visual_owner = jet.attack
	particle.shot = jet
	particle.range = jet.length
	particle.origin = jet.from
	if jet.has("trail"): particle.trail = jet.trail

func _tick_jets(dt: float) -> void:
	for jet in jets:
		if int(jet.source)>=0 and not _valid(jet.source,jet.id):
			jet.age = jet.duration
			continue
		if int(jet.source)>=0: jet.from = actor.table.pos[jet.source]+Vector2.from_angle(float(jet.angle))*actor.table.r[jet.source]
		var elapsed := minf(dt,maxf(0.0,float(jet.duration)-float(jet.age)))
		jet.age = float(jet.age)+dt
		jet.emit = float(jet.emit)+elapsed*100.0
		while float(jet.emit)>=1.0:
			jet.emit = float(jet.emit)-1.0
			_emit_jet_particle(jet)
	jets = jets.filter(func(jet): return float(jet.age)<float(jet.duration))

func add_trail(jet: Dictionary, r: Dictionary) -> void:
	var trail := {"from":jet.from,"angle":jet.angle,"length":0.0,"maximum":jet.length,"age":0.0,
		"delay":r.trail_delay,"life":r.trail_time,"width":r.trail_width,"damage":r.trail_damage}
	jet.trail = trail
	trails.append(trail)

func tick(dt: float) -> void:
	if nova != null:
		nova.update_effect(actor,dt)
		if nova.finished(actor): nova = null
	flash.size = get_viewport_rect().size
	var flash_age: float = actor.clock - nova.started - float(nova.values.warn) if nova != null else -1.0
	var flash_duration := VISUAL_SETTINGS.number(NOVA_KEY,"flash_duration",0.08)
	flash.color.a = VISUAL_SETTINGS.number(NOVA_KEY,"flash_opacity",0.12) * (1.0-flash_age/maxf(flash_duration,0.001)) if flash_age >= 0.0 and flash_age < flash_duration else 0.0
	_tick_burning(dt)
	_tick_tints()
	_tick_jets(dt)
	_tick_particles(dt)
	for burst in bursts: burst.age = float(burst.age)+dt
	bursts = bursts.filter(func(burst): return float(burst.age)<_visual_preset(&"blaze", burst.preset).lifetime)
	for trail in trails:
		trail.age = float(trail.age) + dt
		if float(trail.age) < float(trail.delay) or float(trail.age) >= float(trail.life): continue
		actor.combat_trace.evaluate()
		var end: Vector2 = trail.from + Vector2.from_angle(float(trail.angle)) * float(trail.length)
		var reach := float(trail.width) * 0.5 + actor.ctx.cfg.ship_radius
		if Geometry2D.get_closest_point_to_segment(actor.run_state.ship_pos, trail.from, end).distance_to(actor.run_state.ship_pos) < reach:
			actor.combat_trace.damage(float(trail.damage) * actor.ctx.cfg.atk_scale, 0.0, &"sirius_trail", &"canis_major")
	trails = trails.filter(func(trail): return float(trail.age) < float(trail.life))
	_sync_fire_displays()
	queue_redraw()

func clear() -> void:
	if nova != null: nova.cancel(actor)
	for i: int in tints:
		if _valid(i,tints[i].id): actor.table.color[i] = tints[i].base
	tints.clear()
	if flash != null: flash.color.a = 0.0
	for i: int in burning:
		var entry: Dictionary = burning[i]
		if _valid(i, entry.id):
			actor._hounds().release_order(i)
			actor._set_max_hp(i, float(entry.base_hp))
			actor.table.color[i] = entry.base_color
	burning.clear()
	transfers.clear()
	trails.clear()
	particles.clear()
	jets.clear()
	bursts.clear()
	for fire in fire_displays.values(): fire.queue_free()
	fire_displays.clear()
	warnings.clear()
	queue_redraw()

func _draw() -> void:
	_draw_nova()
	for warning in warnings:
		var direction := Vector2.from_angle(float(warning.angle))
		var length := float(warning.length)
		var hit = actor.ctx.field.first_body_hit(warning.from, warning.from + direction * length)
		if hit != null: length *= float(hit.t)
		var color := Color("#ff667d") if warning.locked else actor.SIRIUS_COLOR
		color.a = 0.35 if warning.locked else lerpf(0.12, 0.45, float(warning.progress))
		draw_line(warning.from, warning.from + direction * length, color, float(warning.width) if warning.locked else lerpf(1.0, 3.0, float(warning.progress)))

func flame_particle(at: Vector2, angle: float, r: Dictionary, harmful: bool, preset: PixelFireSettings = FLAME_FIRE) -> void:
	var spread := actor.run_state.rng.randf_range(-float(r.spread), float(r.spread)) * 0.5 if harmful else sin(actor.clock * 39.0) * 20.0
	var speed := float(r.particle_speed) * actor.run_state.rng.randf_range(0.9, 1.1) if harmful else 100.0
	particles.append({"pos": at, "vel": Vector2.from_angle(angle + deg_to_rad(spread)) * speed, "age": 0.0, "life": float(r.life) if harmful else 0.3, "r_start": float(r.r_start) if harmful else 4.0, "r_end": float(r.r_end) if harmful else 9.0, "drag": r.drag, "hit_scale": r.hit_scale, "damage": r.damage, "harmful": harmful, "preset":preset, "attack":&"sirius_flame", "visual_owner": actor.technique})

func _tick_particles(dt: float) -> void:
	for particle in particles:
		particle.age = float(particle.age) + dt
		var from: Vector2 = particle.pos
		var elapsed := minf(dt,maxf(0.0,float(particle.life)-float(particle.age)+dt))
		particle.vel *= exp(-float(particle.drag) * elapsed)
		particle.pos += particle.vel * elapsed
		var ratio := clampf(float(particle.age) / float(particle.life), 0.0, 1.0)
		particle.radius = lerpf(float(particle.r_start), float(particle.r_end), ratio)
		var obstruction = actor.ctx.field.first_body_hit(from, particle.pos, float(particle.radius) * float(particle.hit_scale))
		if obstruction != null:
			particle.pos = from.lerp(particle.pos,float(obstruction.t))
			particle.age = particle.life
		if particle.has("range") and Vector2(particle.pos).distance_to(particle.origin)>=float(particle.range):
			particle.pos = Vector2(particle.origin)+Vector2(particle.pos-particle.origin).normalized()*float(particle.range)
			particle.age = particle.life
		if particle.has("trail"):
			var trail: Dictionary = particle.trail
			var distance := (Vector2(particle.pos)-Vector2(trail.from)).dot(Vector2.from_angle(float(trail.angle)))
			trail.length = clampf(maxf(float(trail.length),distance),0.0,float(trail.maximum))
		if particle.harmful and (not particle.has("shot") or not particle.shot.hit):
			actor.combat_trace.evaluate()
			if Geometry2D.get_closest_point_to_segment(actor.run_state.ship_pos,from,particle.pos).distance_to(actor.run_state.ship_pos) < float(particle.radius) * float(particle.hit_scale) + actor.ctx.cfg.ship_radius:
				if particle.has("shot"): particle.shot.hit = true
				actor.combat_trace.damage(float(particle.damage) * actor.ctx.cfg.atk_scale, 0.0, particle.attack, &"canis_major")
	particles = particles.filter(func(particle): return float(particle.age) < float(particle.life))

func _valid(i: int, id: int) -> bool:
	return actor.table.alive[i] != 0 and actor.table.dead[i] == 0 and actor.table.id[i] == id

func ignite(i: int, values: Dictionary) -> void:
	clear_tint(i, actor.table.id[i])
	actor.led.erase(i)
	actor._led_ids.erase(i)
	actor._toughen_pack()
	var entry := {"id": actor.table.id[i], "base_hp": actor.table.max_hp[i], "base_color": actor.table.color[i], "age": 0.0, "blink_age": -1.0, "r": values}
	burning[i] = entry
	actor._set_max_hp(i, actor.ram_power() * 0.5)
	actor.table.color[i] = actor.SIRIUS_COLOR
	actor._hounds().release_order(i)
	actor._cue(&"blaze_ignite", actor.table.pos[i])

func _tick_burning(dt: float) -> void:
	for transfer in transfers: transfer.age = float(transfer.age) + dt
	transfers = transfers.filter(func(t): return float(t.age) < float(t.life)+IGNITE_FIRE.lifetime and _valid(t.row,t.id))
	for i: int in burning.keys():
		var entry: Dictionary = burning[i]
		if not _valid(i, entry.id):
			burning.erase(i)
			continue
		var r: Dictionary = entry.r
		entry.age = float(entry.age) + dt
		var cfg: Dictionary = actor._rules[&"bay"].duplicate()
		cfg.max_speed = r.run_speed
		var blinking := float(entry.blink_age) >= 0.0
		if not blinking and (actor.table.pos[i].distance_to(actor.run_state.ship_pos) < float(r.stop_dist) or float(entry.age) >= float(r.max_run)):
			entry.blink_age = 0.0
			blinking = true
			actor._cue(&"blaze_blink", actor.table.pos[i])
		var goal: Vector2 = actor.table.pos[i] if blinking else actor.run_state.ship_pos
		actor._hounds().steer_follow(i, goal, actor.run_state.ship_pos, actor.run_state.world_time + actor.FOLLOW_HOLD, cfg)
		if not blinking: continue
		entry.blink_age = float(entry.blink_age) + dt
		var progress := clampf(float(entry.blink_age) / maxf(float(r.blink),0.001),0,1)
		actor.table.flash[i] = 0.05 if sin(progress * (3.0 + progress * 5.0) * TAU) > 0 else 0.0
		if float(entry.blink_age) >= float(r.blink):
			var at: Vector2 = actor.table.pos[i]
			# 表示は短い判定や猟犬の死亡に結び付けず、炎の寿命まで残す。
			_burst_id += 1
			bursts.append({"key":_burst_id,"pos":at,"radius":r.explode_radius,"age":0.0,"preset":r.explosion_fire})
			actor.combat_trace.evaluate()
			if at.distance_to(actor.run_state.ship_pos)<=float(r.explode_radius)+actor.ctx.cfg.ship_radius:
				actor.combat_trace.damage(float(r.damage)*actor.ctx.cfg.atk_scale,0.0,&"blaze",&"canis_major")
			actor._cue(&"blaze_explode", actor.table.pos[i])
			actor.ctx.enemies.mark_dead(i)
			burning.erase(i)

func _draw_nova() -> void:
	if nova == null: return
	var r: Dictionary = nova.values
	var age: float = actor.clock-float(nova.started)
	var source := actor.mouth()
	var light := clampf(age/maxf(float(r.warn),0.001),0,1) if age < float(r.warn) else maxf(0.0,1.0-(age-float(r.warn))/maxf(float(r.after),0.001))
	var light_alpha := VISUAL_SETTINGS.number(NOVA_KEY,"warning_glow_opacity",0.06)
	# 照明はなめらかな面にし、広がる攻撃の輪と同じ模様を作らない。
	var light_radius := maxf(900.0,float(r.ring_end))
	for k in 64:
		var a := Vector2.from_angle(k*TAU/64.0)*light_radius
		var b := Vector2.from_angle((k+1)*TAU/64.0)*light_radius
		draw_polygon(PackedVector2Array([source,source+a,source+b]),PackedColorArray([Color(actor.SIRIUS_COLOR,light*light_alpha),Color(actor.SIRIUS_COLOR,0.0),Color(actor.SIRIUS_COLOR,0.0)]))
	if age < float(r.warn):
		var progress := clampf(age/maxf(float(r.warn),0.001),0,1)
		var ray_length := VISUAL_SETTINGS.number(NOVA_KEY,"warning_ray_length",100.0)*lerpf(0.25,1.0,progress)
		var pulse := 0.7+0.3*sin(progress*PI*6.0)
		for k in 8:
			var u := Vector2.from_angle(k*TAU/8.0)
			draw_line(source+u*10.0,source+u*ray_length,Color(actor.SIRIUS_COLOR,pulse*progress),VISUAL_SETTINGS.number(NOVA_KEY,"warning_ray_width",4.0))
		draw_circle(source,12.0+progress*18.0,Color(1,1,1,0.2+progress*0.5))
	for shadow in nova.shadows:
		var polygon := PackedVector2Array()
		for k in 13:
			var angle := float(shadow.angle)+lerpf(-float(shadow.half),float(shadow.half),k/12.0)
			polygon.append(source+Vector2.from_angle(angle)*float(shadow.near))
		for k in range(12,-1,-1):
			var angle := float(shadow.angle)+lerpf(-float(shadow.half),float(shadow.half),k/12.0)
			polygon.append(source+Vector2.from_angle(angle)*maxf(900.0,float(r.ring_end)))
		draw_colored_polygon(polygon,Color(0.0,0.005,0.015,light*0.9))
	for ring in int(r.rings):
		var elapsed: float = age-float(r.warn)-ring*float(r.ring_gap)
		if elapsed < 0: continue
		var radius: float = 30.0+float(r.ring_speed)*elapsed
		if radius > float(r.ring_end): continue
		for k in 256:
			var a := TAU*k/256.0
			var b := TAU*(k+1)/256.0
			if nova.in_shadow(actor,source+Vector2.from_angle((a+b)*0.5)*radius,0.0): continue
			var from := source+Vector2.from_angle(a)*radius
			var to := source+Vector2.from_angle(b)*radius
			var width := float(r.ring_band)*2.0
			# 太い帯が判定の全幅。暗い縁で照明から分離し、白い先端で進む向きを示す。
			var outline := VISUAL_SETTINGS.number(NOVA_KEY,"ring_outline_width",3.0)
			var core := minf(width,VISUAL_SETTINGS.number(NOVA_KEY,"ring_core_width",8.0))
			draw_line(from,to,Color(actor.SIRIUS_COLOR,0.08),width*VISUAL_SETTINGS.number(NOVA_KEY,"ring_halo_scale",1.6))
			draw_line(from,to,Color(0.005,0.015,0.04,0.95),width+outline*2.0)
			draw_line(from,to,Color("#65baff"),width)
			draw_line(from,to,Color(0.95,0.99,1.0,1.0),core)
			var front := radius+float(r.ring_band)-1.0
			draw_line(source+Vector2.from_angle(a)*front,source+Vector2.from_angle(b)*front,Color.WHITE,minf(2.0,width))

func tint_hound(i: int, until: float, color: Color) -> void:
	var base: Color = tints[i].base if tints.has(i) and tints[i].id == actor.table.id[i] else actor.table.color[i]
	tints[i] = {"id": actor.table.id[i], "until": until, "color": color, "base": base}
	actor.table.color[i] = color

func _tick_tints() -> void:
	for i: int in tints.keys():
		var entry: Dictionary = tints[i]
		if not _valid(i,entry.id):
			tints.erase(i)
		elif actor.run_state.world_time >= float(entry.until):
			actor.table.color[i] = entry.base
			tints.erase(i)
		else: actor.table.color[i] = entry.color

func clear_tint(i: int, id: int) -> void:
	if not tints.has(i) or tints[i].id != id: return
	if _valid(i,id): actor.table.color[i] = tints[i].base
	tints.erase(i)

func _visual_preset(owner: StringName, preset: PixelFireSettings) -> PixelFireSettings:
	return COMPONENTS.fire("boss/move/canis_major/" + String(owner), preset)

func _fire_display(key: String, preset: PixelFireSettings, owner: StringName = &"blaze") -> Node2D:
	var visual := _visual_preset(owner, preset)
	if not fire_displays.has(key):
		var fire := FIRE_DISPLAY.new()
		fire.setup(visual)
		add_child(fire)
		fire_displays[key] = fire
	var display = fire_displays[key]
	if display.settings != visual: display.settings = visual
	return display

func _sync_fire_displays() -> void:
	var seen := {}
	var clock := actor.run_state.world_time
	for transfer in transfers:
		if not _valid(transfer.row,transfer.id): continue
		var key := "点火:"+str(transfer.id)
		seen[key] = true
		var start: Vector2 = transfer.from
		var to: Vector2 = actor.table.pos[transfer.row]-start
		var progress := clampf(float(transfer.age)/maxf(float(transfer.life),0.001),0,1)
		var samples: Array = []
		var heading := to.angle()
		var side := Vector2.from_angle(heading+PI*0.5)
		for k in 5:
			var p := clampf(progress-k*0.045,0.0,1.0)
			var point := start+to*p+side*sin(p*PI)*minf(60.0,to.length()*0.15)
			samples.append({"pos":point,"radius":lerpf(22.0,8.0,k/4.0),"seed":k})
		var fire := _fire_display(key,IGNITE_FIRE)
		fire.cloud(samples,clock,heading)
		fire.modulate.a = 1.0-smoothstep(float(transfer.life),float(transfer.life)+IGNITE_FIRE.lifetime,float(transfer.age))
	if not transfers.is_empty() or (actor.technique==&"blaze" and actor.mode in [&"windup",&"active"]):
		seen["口元の点火"] = true
		_fire_display("口元の点火",IGNITE_FIRE).cloud([{"pos":actor.mouth(),"radius":28.0,"seed":0}],clock)
	for i: int in burning:
		if not _valid(i,burning[i].id): continue
		var key := "猟犬:"+str(burning[i].id)
		seen[key] = true
		# 燃える猟犬の正式な見た目は未決。共通PixelFireの専用プリセットを使う。
		var fire := _fire_display(key,HOUND_FIRE)
		fire.cloud([{"pos":actor.table.pos[i],"radius":actor.table.r[i]*1.6,"seed":i}],clock)
		fire.modulate.a = 0.4 if actor.table.flash[i]>0 else 1.0
	var clouds := {}
	for particle in particles:
		var preset: PixelFireSettings = particle.preset
		var owner: StringName = particle.visual_owner
		var key := "放射:" + String(owner) + ":" + str(preset.get_instance_id())
		if not clouds.has(key): clouds[key] = {"preset": preset, "owner": owner, "samples": []}
		clouds[key].samples.append(particle)
	for key: String in clouds:
		var cloud: Dictionary = clouds[key]
		seen[key] = true
		_fire_display(key, cloud.preset, cloud.owner).cloud(cloud.samples, clock, actor.table.facing[actor.body])
	for k in trails.size():
		var trail: Dictionary = trails[k]
		if float(trail.length)<=0.0: continue
		var key := "焼け跡:"+str(k)
		seen[key] = true
		var samples: Array = []
		var count := maxi(2,ceili(float(trail.length)/18.0))
		for n in count:
			var distance := (n+0.5)/count*float(trail.length)
			var offset := sin(n*2.4)*float(trail.width)*0.3
			var pos: Vector2 = trail.from+Vector2(distance,offset).rotated(float(trail.angle))
			samples.append({"pos":pos,"radius":float(trail.width)*(0.7+0.3*sin(n*1.7+clock*4.0)),"seed":n})
		var fire := _fire_display(key,TRAIL_FIRE, &"sirius")
		fire.cloud(samples,clock,float(trail.angle))
		fire.modulate.a = 0.8*(1.0-smoothstep(0.5,1.0,float(trail.age)/float(trail.life)))
	for burst in bursts:
		var key := "爆発:"+str(burst.key)
		seen[key] = true
		_fire_display(key,burst.preset).burst(burst.pos,float(burst.radius),float(burst.age)/_visual_preset(&"blaze", burst.preset).lifetime,clock)
	for key in fire_displays.keys():
		if not seen.has(key):
			fire_displays[key].queue_free()
			fire_displays.erase(key)
