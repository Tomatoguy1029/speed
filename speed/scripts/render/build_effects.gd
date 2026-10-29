## ビルドの共通演出。戦闘と図鑑が同じshader・粒・時間を使う。
## 固定の画像は読み込みだけを行い、動く粒は1つのMultiMeshへまとめる。
class_name BuildEffects
extends Node2D
const SETTINGS := preload("res://data/visuals/effect_settings.tres")
const EFFECT := preload("res://shaders/build_effect.gdshader")
const SHOT := preload("res://shaders/build_shot.gdshader")
const VALUE_NOISE := preload("res://assets/effects/build/value_noise.png")
const NOISE := preload("res://assets/effects/build/aura_noise.png")
const SHADER_PALETTE := [Color.WHITE, Color(0.85, 0.96, 1.0), Color(0.5, 0.85, 1.0), Color(0.23, 0.61, 0.94)]
var pixel := 2.36
var effects: Array[Dictionary] = []
var sparks: Array[Dictionary] = []
var _particles: InstanceBatch
var _shots: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var clock := 0.0
var texture_provider: Callable
var _captures: Array[Dictionary] = []
var _last_world_delta := 0.0
var _needles: Dictionary = {}

func _ready() -> void:
	_rng.seed = 121
	_particles = InstanceBatch.new()
	_particles.setup_shader_quad()
	add_child(_particles)
	for key in ["weapon/forward", "weapon/scatter", "weapon/rear", "weapon/interceptor", "weapon/knockback"]:
		var batch := InstanceBatch.new()
		batch.setup_shader_quad()
		var mat := ShaderMaterial.new()
		mat.shader = SHOT
		mat.set_shader_parameter("style", 1 if key == "weapon/scatter" else 2 if key == "weapon/interceptor" else 3 if key == "weapon/knockback" else 0)
		batch.material = mat
		add_child(batch)
		_shots[key] = batch

func effect(mode: int, pos: Vector2, radius: float, life: float, key: String, options := {}) -> Dictionary:
	var node := MeshInstance2D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE * 2.0
	node.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = EFFECT
	node.material = material
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.position = (pos / pixel).round() * pixel
	var r := radius * SETTINGS.number(key, "effect_scale", 1.0)
	node.scale = Vector2.ONE * (r + pixel * 2.0)
	material.set_shader_parameter("mode", mode)
	material.set_shader_parameter("pixel", pixel * SETTINGS.number(key, "pixel_scale", 1.0))
	material.set_shader_parameter("extent", node.scale * 2.0)
	material.set_shader_parameter("duration", life * SETTINGS.number(key, "duration_scale", 1.0))
	material.set_shader_parameter("noise_tex", NOISE)
	material.set_shader_parameter("value_noise", VALUE_NOISE)
	material.set_shader_parameter("noise_origin", pos/pixel)
	material.set_shader_parameter("noise_seed", _rng.randf_range(0,30))
	material.set_shader_parameter("tint", SETTINGS.tinted(key, Color.WHITE))
	for name in options: material.set_shader_parameter(name, options[name])
	var values := SETTINGS.values_for(key)
	for index in SHADER_PALETTE.size():
		var setting := "shader_c" + str(index)
		if values.has(setting):
			var uniform := "c" + str(index)
			var original: Color = options.get(uniform, SHADER_PALETTE[index])
			var multiplier: Color = values[setting]
			material.set_shader_parameter(uniform, original * multiplier)
	add_child(node)
	var item := {"node": node, "material": material, "age": 0.0, "life": life * SETTINGS.number(key, "duration_scale", 1.0), "key": key, "follow": false}
	effects.append(item)
	if effects.size() > 160:
		effects.pop_front().node.queue_free()
	return item

func burst(pos: Vector2, count: int, angle: float, spread: float, low: float, high: float, life: float, colors: Array, key: String, size_value := 1.0, scale_count := true) -> void:
	if scale_count: count = roundi(count * SETTINGS.number(key, "particle_count_scale", 1.0))
	var visual_scale := SETTINGS.number(key, "effect_scale", 1.0)
	var cell_scale := SETTINGS.number(key, "pixel_scale", 1.0)
	life *= SETTINGS.number(key, "duration_scale", 1.0)
	for i in mini(count, 4096 - sparks.size()):
		var direction := Vector2.from_angle(angle + _rng.randf_range(-spread * 0.5, spread * 0.5))
		sparks.append({"pos": pos, "velocity": direction * _rng.randf_range(low, high) * pixel * visual_scale,
			"age": 0.0, "life": life * _rng.randf_range(0.7, 1.0), "color": SETTINGS.tinted(key, colors[i % colors.size()]),
			"size": size_value * visual_scale * cell_scale * _rng.randf_range(0.7, 1.4), "delay": 0.0})

func event(ev: Dictionary) -> bool:
	var key := String(ev.get("visual_key", ""))
	if ev.type==&"kill" and _needles.has(ev.id):
		_needles[ev.id].node.queue_free()
		_needles.erase(ev.id)
	if ev.type==&"flash_slash" and _needles.has(ev.get("id",-1)):
		_needles[ev.id].node.queue_free()
		_needles.erase(ev.id)
	match ev.type:
		&"kill":
			return ev.get("cause", &"")==&"vortex"
		&"hole_capture":
			if texture_provider.is_valid() and _captures.size()<128:
				var sprite := Sprite2D.new()
				sprite.texture=texture_provider.call(ev.enemy_type)
				if sprite.texture!=null:
					sprite.position=ev.pos
					sprite.rotation=ev.facing
					var base := float(ev.radius)*3.0/maxf(sprite.texture.get_width(),sprite.texture.get_height())
					sprite.scale=Vector2.ONE*base
					add_child(sprite)
					_captures.append({"sprite":sprite,"from":ev.pos,"age":0.0,"delay":_rng.randf()*0.08,"duration":0.12+_rng.randf()*0.12,"swirl":_rng.randf_range(-0.6,0.6),"scale":base,"color":ev.color})
		&"escort_deploy":
			for target in ev.targets:
				var d:Vector2=target-ev.pos
				effect(8,(target+ev.pos)*0.5,d.length()*0.5,0.12,"weapon/dashRangeDrone",{"angle":d.angle(),"c1":Color("#9ffff4")})
				effect(3,target,6.0*pixel,0.12,"weapon/dashRangeDrone",{"width":0.0})
		&"escort_slash":
			effect(4,ev.pos,12.0*pixel,0.16,"weapon/dashRangeDrone",{"angle":ev.dir.angle(),"width":1.5,"c2":Color("#69fff0"),"c3":Color("#1f7f86")})
			burst(ev.pos,8,ev.dir.angle()+PI*0.5,TAU,10,45,0.16,[Color.WHITE,Color("#69fff0")],"weapon/dashRangeDrone")
		&"anchor_capture":
			effect(0,ev.pos,12.0*pixel,0.14,"weapon/massTow",{"c1":Color("#ffbe65")})
			burst(ev.pos,12,(ev.to-ev.pos).angle(),0.3,40,80,0.45,[Color("#fff2c0"),Color("#ffbe65")],"weapon/massTow")
		&"anchor_fire":
			effect(1,ev.pos,14.0*pixel,0.45,"weapon/massTow",{"c1":Color("#fff2a8"),"c2":Color("#ffb030"),"c3":Color("#d2461c")})
			effect(0,ev.pos,28.0*pixel,0.16,"weapon/massTow",{"c1":Color("#ffbe65")})
			burst(ev.pos,9,ev.dir.angle(),1.3,60,120,0.25,[Color.WHITE,Color("#fff2c0"),Color("#ffbe65")],"weapon/massTow")
		&"ring":
			if key!="weapon/bipolar":return false
			effect(0,ev.pos,ev.radius,0.2,key,{"c1":Color("#cffff9"),"c2":Color("#69fff0")})
		&"bipolar_charge":
			for pos in [ev.from,ev.to]:
				for i in 20:
					var radial:=Vector2.from_angle(_rng.randf()*TAU)*_rng.randf_range(10,30)*pixel
					sparks.append({"pos":pos+radial,"center":pos,"inward":radial,"swirl":0.0,"velocity":Vector2.ZERO,"age":0.0,"life":0.18,"delay":0.0,"color":Color("#cffff9"),"size":1.0})
		&"beam":
			if key!="weapon/bipolar":return false
			var delta: Vector2=ev.to-ev.from
			effect(6,(ev.from+ev.to)*0.5,delta.length()*0.5,0.7,key,{"angle":delta.angle(),"width":float(ev.width)/pixel,"c1":Color("#cffff9"),"c2":Color("#69fff0"),"c3":Color("#1f7f86")})
			for pos in [ev.from,ev.to]:
				effect(1,pos,20.0*pixel,0.45,key,{"c1":Color("#cffff9"),"c2":Color("#69fff0"),"c3":Color("#1f7f86")})
				burst(pos,16,0,TAU,35,140,0.4,[Color.WHITE,Color("#69fff0")],key)
			burst((ev.from+ev.to)*0.5,70,delta.angle()+PI*0.5,TAU,20,80,0.35,[Color("#cffff9"),Color("#69fff0")],key)
			for i in range(maxi(0,sparks.size()-70),sparks.size()):
				sparks[i].delay=0.7
				sparks[i].pos=ev.from.lerp(ev.to,_rng.randf())

		&"weapon_fire":
			if not ev.has("pos"): return false
			if key == "weapon/interceptor": return true
			effect(2, ev.pos, pixel * 17.0, 0.1, key, {"angle": ev.angle, "width": 1.0 if key == "weapon/scatter" else 2.0})
			if key == "weapon/scatter":
				burst(ev.pos, 15, ev.angle, 1.4, 60.0, 120.0, 0.1, [Color("#ffffff"), Color("#7fd8ff"), Color("#d8f6ff")], key)
			if key == "weapon/rear": burst(ev.pos, 1, ev.angle + PI * 0.5, 0.3, 30.0, 50.0, 0.35, [Color("#ffd27a"), Color("#b07a14")], key, 1.5)
		&"shot_hit":
			if key=="weapon/massTow":
				effect(1,ev.pos,13.0*pixel,0.45,key,{"c1":Color("#fff2a8"),"c2":Color("#ffb030"),"c3":Color("#d2461c")})
				return true
			var big := key != "weapon/scatter" and key != "weapon/interceptor"
			effect(3, ev.pos, 16.0 * pixel, 0.18 if big else 0.14, key, {"width": 2.0 if big else 0.0})
			burst(ev.pos, 13 if big else 5, ev.dir.angle() + PI, 2.6 if big else 2.0, 30, 120 if big else 90, 0.22,
				[Color.WHITE, Color("#8fffe2") if key == "weapon/interceptor" else Color("#bff3ff"), Color("#3e9eaa") if key == "weapon/interceptor" else Color("#4fb8ff")], key)
		&"duplicate":
			effect(3, ev.pos, pixel * 8.0, 0.14, "trait/duplicator", {"width": 0.0})
			for velocity in ev.directions: burst(ev.pos, 4, velocity.angle(), 0.6, 20, 70, 0.16, [Color.WHITE, Color("#bff3ff")], "trait/duplicator")
		&"explode":
			var cause := String(ev.get("cause", ""))
			if cause not in ["mine", "endBlast", "runUp"]: return false
			key = "weapon/mines" if cause == "mine" else "weapon/endBlast" if cause == "endBlast" else "trait/runUp"
			if cause == "runUp": return true
			var palette := {"c0": Color.WHITE, "c1": Color("#fff2a8"), "c2": Color("#ffb030"), "c3": Color("#d2461c")}
			if cause == "endBlast": palette = {"c0": Color.WHITE, "c1": Color("#e6d2ff"), "c2": Color("#b070ff"), "c3": Color("#5a1eb0")}
			effect(1, ev.pos, ev.radius, 0.6 if cause=="mine" else 0.55, key, palette)
			if cause=="endBlast": burst(ev.pos,36,0,TAU,50,170,0.5,[Color.WHITE,Color("#b48cff")],key)
		&"chain_shock": effect(0, ev.pos, ev.radius, ev.life, "trait/killSonic", {"c1": Color("#d8f6ff"), "c2": Color("#7fd8ff")})
		&"space_quake":
			_distortion(ev.pos, ev.radius, 0.58, "weapon/contactWave", 0)
			burst(ev.pos, 9, 0, TAU, 80, 180, 0.14, [Color.WHITE], "weapon/contactWave")
		&"barrier_hit":
			var life: float = 0.26 + ceil(float(ev.radius) / (sqrt(3.0) * 4.0 * pixel) - 4.0) * 0.05 + 0.1
			effect(5, ev.pos, ev.radius, life, "weapon/barrier", {"angle": ev.angle, "broken": ev.broken, "c1": Color("#e6f3ff"), "c2": Color("#76aaff")})
			if ev.broken:
				var count := roundi(TAU * float(ev.radius) / (sqrt(3.0) * 4.0 * pixel) * 6.0 * SETTINGS.number("weapon/barrier","particle_count_scale",1.0))
				for i in count:
					var a := _rng.randf() * TAU
					var p: Vector2 = ev.pos + Vector2.from_angle(a) * float(ev.radius) * _rng.randf_range(0.92, 1.04)
					burst(p, 1, a, 1.1, 35, 145, _rng.randf_range(0.25, 0.55), [Color.WHITE, Color("#76aaff"), Color("#bfe0ff")], "weapon/barrier", _rng.randf_range(1, 3), false)
					if not sparks.is_empty(): sparks.back().delay = life - 0.1 + _rng.randf() * 0.05
		&"barrier_restore":
			var item := effect(5, ev.pos, 26.0 * pixel, 0.5, "weapon/barrier", {"width": -1.0, "angle": 0.0, "c2": Color("#76aaff")})
			item.follow = true
		&"flash_slash": effect(4, ev.pos, float(ev.length) * pixel * 0.5, 0.7, "weapon/flashSlash", {"angle": ev.angle, "width": ev.width, "c2": Color("#dcaaff"), "c3": Color("#8f52d0")})
		&"slash_mark":
			var item:=effect(4,ev.pos,float(ev.radius)*1.6,1.0,"weapon/flashSlash",{"angle":ev.angle,"width":1.6,"c2":Color("#dcaaff")})
			effects.erase(item)
			item.center=ev.pos
			item.angle=ev.angle
			item.radius=ev.radius
			item.row=ev.row
			item.release=false
			_needles[ev.id]=item
		&"slash_release":
			for needle in _needles.values(): needle.release=true
			if ev.path.size() >= 2:
				for i in int(ev.count):
					var f := _rng.randf()
					var index := mini(ev.path.size() - 2, floori(f * (ev.path.size() - 1)))
					var direction: Vector2 = (ev.path[index + 1] - ev.path[index]).normalized()
					var p: Vector2 = ev.path[index].lerp(ev.path[index + 1], fmod(f * (ev.path.size() - 1), 1.0)) + direction.orthogonal() * _rng.randf_range(-40, 40) * pixel
					var item := effect(4, p, _rng.randf_range(30, 210) * pixel * 0.5, 0.7, "weapon/flashSlash", {"angle": direction.angle() + _rng.randf_range(-1.3, 1.3), "width": _rng.randf_range(1.4, 3.6), "c2": Color("#dcaaff"), "c3": Color("#8f52d0")})
					item.age = -float(ev.pause) - f * float(ev.sweep)
		&"hull_scatter":
			effect(3, ev.pos, 16.0 * pixel, 0.18, "weapon/knockback", {"width": 2.0})
			burst(ev.pos, 20, 0, TAU, 10, 70, 0.3, [Color.WHITE, Color("#dcaaff"), Color("#8e62df")], "weapon/knockback")
		&"end_hole":
			var item := _distortion(ev.pos, 60.0 * pixel, float(ev.life), "trait/vortex", 1)
			item.follow = true
			for i in roundi(140 * SETTINGS.number("trait/vortex","particle_count_scale",1.0)):
				var radial:=Vector2.from_angle(_rng.randf()*TAU)*_rng.randf_range(40,180)*pixel
				sparks.append({"pos":ev.pos+radial,"inward":radial,"swirl":_rng.randf_range(-0.8,0.8),"velocity":Vector2.ZERO,"age":0.0,"life":_rng.randf_range(0.08,0.24),"delay":_rng.randf()*0.18,"color":Color.WHITE if i%3==0 else Color("#be78ff"),"size":_rng.randf_range(0.8,2.6)})
		&"hole_recover":
			var item := effect(0, ev.pos, 52.0 * pixel, 0.7, "trait/vortex", {"c0": Color("#dcffe6"), "c1": Color("#8fffbe"), "c2": Color("#6effaa")})
			item.follow = true
			burst(ev.pos, 14, -PI * 0.5, 2.0, 14, 40, 0.7, [Color("#8fffbe")], "trait/vortex")
		&"sonic_push", &"sonic_impact":
			effect(3, ev.pos, 14.0 * pixel, 0.16, "weapon/sonic", {"width": 0.0})
			if ev.type == &"sonic_impact": burst(ev.pos, 10 if ev.dead else 5, ev.dir.angle(), 1.3, 50, 130, 0.26, [Color.WHITE, Color("#cfe4ff"), Color("#8a96b0")], "weapon/sonic")
		&"run_up_hit": burst(ev.pos, 16, 0, TAU, 30, 60, 0.2, [Color.WHITE, Color("#ffd040"), Color("#ff9a1e")], "trait/runUp")
		&"full_burst_ready": burst(ev.pos, 12, 0, TAU, 25, 90, 0.3, [Color.WHITE, Color("#7fd8ff")], "trait/fullBurst")
		_: return false
	return true

func _distortion(pos: Vector2, radius: float, life: float, key: String, kind: int) -> Dictionary:
	var item := effect(0, pos, radius, life, key)
	item.material.shader = preload("res://shaders/build_distortion.gdshader")
	item.material.set_shader_parameter("mode", kind)
	item.material.set_shader_parameter("pixel", pixel * SETTINGS.number(key, "pixel_scale", 1.0))
	item.material.set_shader_parameter("extent", item.node.scale * 2.0)
	item.material.set_shader_parameter("duration", item.life)
	item.material.set_shader_parameter("strength", SETTINGS.number(key, "distortion_strength", 1.0))
	item["distortion"] = true
	return item

func step(dt: float, ship_pos := Vector2.ZERO) -> void:
	captures_step(dt,ship_pos)
	clock += dt
	_last_world_delta=dt
	for needle in _needles.values():
		needle.age+=dt
		var progress:=minf(1.0,float(needle.age)/0.06)
		needle.node.visible=progress>=0.6
		needle.node.position=needle.center+Vector2.from_angle(float(needle.angle))*(float(needle.radius)*0.6+170.0*pixel*(1.0-progress))
		needle.material.set_shader_parameter("age",0.0)
		needle.material.set_shader_parameter("width",2.4 if needle.release else 1.6)
	for item in effects:
		item.age += dt
		item.node.visible = item.age >= 0.0
		if item.follow: item.node.position = ship_pos
		item.material.set_shader_parameter("age", maxf(0.0, item.age))
		if item.get("distortion", false):
			item.material.set_shader_parameter("screen_scale", get_global_transform_with_canvas().get_scale().abs())
		if item.age >= item.life: item.node.queue_free()
	effects = effects.filter(func(e): return e.age < e.life)
	_particles.begin()
	for particle in sparks:
		particle.age += dt
		if particle.age < particle.delay: continue
		if particle.has("inward"):
			var progress:=clampf((float(particle.age)-float(particle.delay))/float(particle.life),0,1)
			particle.pos=particle.get("center",ship_pos)+particle.inward.rotated(float(particle.swirl)*progress)*(1.0-pow(progress,3.0))
		else: particle.pos += particle.velocity * dt
		particle.velocity *= pow(0.1, dt)
		var q: float = (particle.age - particle.delay) / particle.life
		if q >= 1.0: continue
		var cell: Vector2 = (particle.pos / pixel).round()
		if q > 0.6 and int(cell.x + cell.y) % 2 != 0: continue
		var color: Color = particle.color
		if particle.has("palette"): color = particle.palette[mini(5, floori(q * 6.0))]
		_particles.add_upright(cell * pixel, particle.size * pixel * 0.5, color)
	sparks = sparks.filter(func(p): return p.age < p.life + p.delay)
	_particles.end()

func projectiles(pr: ProjectileSystem) -> void:
	for key in _shots:
		_shots[key].begin()
		var mat: ShaderMaterial = _shots[key].material
		mat.set_shader_parameter("tint", SETTINGS.tinted(key, Color.WHITE))
		mat.set_shader_parameter("pixel_scale", SETTINGS.number(key, "pixel_scale", 1.0))
		mat.set_shader_parameter("length_scale", SETTINGS.number(key, "shot_length_scale", 1.0))
		mat.set_shader_parameter("width_scale", SETTINGS.number(key, "shot_width_scale", 1.0))
	for i in pr.friend_alive.size():
		if pr.friend_alive[i] == 0: continue
		var key := String(pr.friend_visual[i])
		if key=="weapon/massTow" and _last_world_delta>0.0:
			burst(pr.friend_pos[i],1,pr.friend_vel[i].angle()+PI,0.3,5,15,0.18,[Color("#ffb030")],key)
		if not _shots.has(key): continue
		var a := fposmod(pr.friend_vel[i].angle(), TAU) / TAU
		_shots[key].add_upright((pr.friend_pos[i] / pixel).round() * pixel, 18.0 * pixel * SETTINGS.number(key,"effect_scale",1.0), Color(a, 1.0 if key == "weapon/scatter" and pr.friend_life[i] < 0.09 else 0.0, clock, 1.0))
		if _last_world_delta>0.0 and key=="weapon/knockback":
			burst(pr.friend_pos[i],1,pr.friend_vel[i].angle()+PI,0.3,5,15,0.18,[Color("#b46bff") if key=="weapon/knockback" else Color("#ffb030")],key)
	for batch in _shots.values(): batch.end()

var _aura: Sprite2D
var _gear_acc := 0.0
var _sonic_nodes: Array[Dictionary] = []
var _runup: Dictionary = {}
var _mines: InstanceBatch
func sample(ctx: RunContext, dt: float) -> void:
	_continuous(ctx,dt)
	var state := ctx.state
	for id in _needles.keys():
		var needle: Dictionary=_needles[id]
		if not ctx.enemies.is_same(needle.row,id) or ctx.enemies.table.dead[needle.row]!=0 or not state.weapons.has(&"W28"):
			needle.node.queue_free()
			_needles.erase(id)
		else:needle.center=ctx.enemies.table.pos[needle.row]
	var rampage = ctx.loadout.trait_behaviors.get(&"T33")
	if _aura == null:
		_aura = Sprite2D.new()
		_aura.texture = preload("res://assets/effects/build/airship_aura_mask.png")
		_aura.position = Vector2.ZERO
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://shaders/build_aura.gdshader")
		mat.set_shader_parameter("noise_tex", NOISE)
		_aura.material = mat
		add_child(_aura)
	_aura.visible = rampage != null
	if rampage != null:
		_aura.position = state.ship_pos + Vector2(0, 5.0 * ctx.cfg.character_scale).rotated(state.ship_heading.angle() + PI * 0.5)
		_aura.rotation = state.ship_heading.angle() + PI * 0.5
		_aura.scale = Vector2.ONE * ctx.cfg.character_scale * SETTINGS.number("trait/rampage", "effect_scale", 1.0)
		var mat: ShaderMaterial = _aura.material
		mat.set_shader_parameter("strength", minf(1.0, float(rampage.kills) / 150.0) if state.tracing else rampage.strength)
		mat.set_shader_parameter("pop", rampage.pop)
		mat.set_shader_parameter("clock", clock / maxf(0.01, SETTINGS.number("trait/rampage", "duration_scale", 1.0)))
		mat.set_shader_parameter("pixel_scale", SETTINGS.number("trait/rampage", "pixel_scale", 1.0))
		mat.set_shader_parameter("tint", SETTINGS.tinted("trait/rampage", Color.WHITE))
	var gear = ctx.loadout.trait_behaviors.get(&"T04")
	if gear != null and state.tracing:
		var x := clampf(ctx.loadout.boost_distance / ctx.cfg.draw_length, 0, 1)
		var ex := (exp(3.0 * x) - 1.0) / (exp(3.0) - 1.0)
		_gear_acc += dt * (40.0 + 600.0 * ex) * SETTINGS.number("trait/fullCharge", "particle_count_scale", 1.0)
		while _gear_acc >= 1.0 and sparks.size() < 4096:
			_gear_acc -= 1.0
			var nose := _rng.randf() < 0.55
			var p := state.ship_pos + state.ship_heading * (9.0 if nose else 2.0 - _rng.randf() * 6.0) * pixel + state.ship_heading.orthogonal() * _rng.randf_range(-0.5, 0.5) * (2.0 if nose else 5.0 + 10.0 * ex) * pixel
			burst(p, 1, state.ship_heading.angle() + PI, 0.9 + 0.8 * ex, 60.0 + 160.0 * ex, 60.0 + 160.0 * ex, 0.16 + 0.24 * ex * _rng.randf(), [Color.WHITE], "trait/fullCharge", 2.0 if _rng.randf() < 0.35 + 0.4 * ex else 1.0, false)
			if not sparks.is_empty(): sparks.back().palette = [Color.WHITE, Color("#fff2a8"), Color("#ffd040"), Color("#ff9a1e"), Color("#e9561c"), Color("#9a2a14")]
	var sonic = ctx.loadout.weapon_behaviors.get(&"W08")
	var frames: Array = sonic.frames if sonic != null else []
	while _sonic_nodes.size() < frames.size():
		var item := effect(7, Vector2.ZERO, 1.0, 1.0, "weapon/sonic")
		effects.erase(item)
		_sonic_nodes.append(item)
	for i in _sonic_nodes.size():
		var item := _sonic_nodes[i]
		item.node.visible = i < frames.size()
		if i >= frames.size(): continue
		var radius: float = sonic.wave_speed() * sonic.wave_life() * SETTINGS.number("weapon/sonic","effect_scale",1.0)
		item.node.position = frames[i].pos
		item.node.scale = Vector2.ONE * (radius + 2.0 * pixel)
		item.material.set_shader_parameter("extent", Vector2.ONE * (radius + 2.0 * pixel) * 2.0)
		item.material.set_shader_parameter("duration", sonic.wave_life())
		item.material.set_shader_parameter("age", frames[i].age / maxf(0.01,SETTINGS.number("weapon/sonic","duration_scale",1.0)))
		item.material.set_shader_parameter("width", float(sonic.pulse) / 0.25)
	if _mines == null:
		_mines = InstanceBatch.new()
		_mines.setup_shader_quad()
		var mat := ShaderMaterial.new()
		mat.shader = SHOT
		mat.set_shader_parameter("style", 4)
		_mines.material = mat
		add_child(_mines)
	_mines.material.set_shader_parameter("tint",SETTINGS.tinted("weapon/mines",Color.WHITE))
	_mines.material.set_shader_parameter("pixel_scale",SETTINGS.number("weapon/mines","pixel_scale",1.0))
	_mines.begin()
	var launcher = ctx.loadout.weapon_behaviors.get(&"W07")
	if launcher != null:
		for mine in launcher.mines:
			_mines.add_upright((mine.pos / pixel).round() * pixel, 18.0 * pixel * SETTINGS.number("weapon/mines","effect_scale",1.0), Color(0, 0, 0, 1))
	_mines.end()

func captures_step(dt: float, center: Vector2) -> void:
	for capture in _captures:
		capture.age+=dt
		var q:=clampf((float(capture.age)-float(capture.delay))/float(capture.duration),0,1)
		var radial: Vector2=capture.from-center
		capture.sprite.position=center+radial.rotated(float(capture.swirl)*q*q)*(1.0-q*q)
		capture.sprite.scale=Vector2.ONE*float(capture.scale)*(1.0-0.65*q)
		capture.sprite.modulate=SETTINGS.tinted("trait/vortex", Color(1,1,1,1.0-0.85*q))
		if q>0.0 and q<1.0 and dt>0.0:burst(capture.sprite.position,1,(center-capture.sprite.position).angle(),0.4,40,70,0.08,[capture.color],"trait/vortex")
		if q>=1.0:capture.sprite.queue_free()
	_captures=_captures.filter(func(c):return c.age<c.delay+c.duration)

var _tether: InstanceBatch
var _steam: InstanceBatch
var _escort: InstanceBatch
var _escort_samples: Array[Dictionary] = []
var _runup_node: Dictionary = {}
var _tow_node: Dictionary = {}
func _continuous(ctx: RunContext, dt: float) -> void:
	var state:=ctx.state
	if _steam==null:
		_steam=InstanceBatch.new()
		_steam.setup_shader_quad()
		add_child(_steam)
	_steam.begin()
	if state.weapons.has(&"W08") and (state.tracing or state.glide):
		var sonic=ctx.loadout.weapon_behaviors[&"W08"]
		var speed:=maxf(state.ship_vel.length()/pixel,float(sonic.at_level("speed_by_level")))
		var tangent:=tan(asin(minf(0.99,float(sonic.at_level("speed_by_level"))/maxf(speed,float(sonic.at_level("speed_by_level"))+1.0))))
		for i in 40:
			var u:=float((i*37)%40)/40.0
			var along:=4.0+u*20.0
			var half:=along*tangent*(0.35+0.65*float((i*53)%10)/10.0)
			var pos:=state.ship_pos-state.ship_heading*along*pixel+state.ship_heading.orthogonal()*half*(1.0 if i%2 else -1.0)*pixel
			_steam.add_upright((pos/pixel).round()*pixel,pixel*0.5,SETTINGS.tinted("weapon/sonic", Color(0.92,0.95,1.0,0.28*(1.0-u*0.6))))
	_steam.end()
	if _escort==null:
		_escort=InstanceBatch.new()
		_escort.setup_shader_quad()
		add_child(_escort)
	for p in _escort_samples:p.age+=dt
	_escort_samples=_escort_samples.filter(func(p):return p.age<0.3)
	if state.weapons.has(&"W26") and state.tracing and dt>0.0:
		if _escort_samples.is_empty() or state.ship_pos.distance_to(_escort_samples.back().pos)>pixel*2.0:
			_escort_samples.append({"pos":state.ship_pos,"age":0.0})
	_escort.begin()
	var remaining:=80.0*pixel
	for i in range(_escort_samples.size()-1,0,-1):
		var a:Vector2=_escort_samples[i].pos
		var b:Vector2=_escort_samples[i-1].pos
		var distance:=a.distance_to(b)
		if distance<=0.01:continue
		b=a.move_toward(b,minf(distance,remaining))
		var fade:=1.0-float(_escort_samples[i].age)/0.3
		for k in 3:
			var width_value:float=[6.0,3.0,2.0][k]
			var color:Color=[Color(0.35,0.85,1.0,0.25*fade),Color(0.5,0.95,1.0,0.65*fade),Color(1,1,1,fade)][k]
			_escort.add_rect((a+b)*0.5,Vector2(a.distance_to(b)*0.5,width_value*pixel*0.5),(a-b).angle(),SETTINGS.tinted("weapon/dashRangeDrone", color))
		remaining-=distance
		if remaining<=0.0:break
	_escort.end()
	var runup=ctx.loadout.trait_behaviors.get(&"T32")
	if _runup_node.is_empty():
		_runup_node=effect(14,Vector2.ZERO,110.0*pixel,1.0,"trait/runUp")
		effects.erase(_runup_node)
	_runup_node.node.visible=runup!=null and state.tracing and runup.first
	if _runup_node.node.visible:
		var x:=clampf(ctx.loadout.boost_distance/600.0,0,1)
		_runup_node.node.position=state.ship_pos
		_runup_node.material.set_shader_parameter("age",clock / maxf(0.01,SETTINGS.number("trait/runUp","duration_scale",1.0)))
		_runup_node.material.set_shader_parameter("streak_count",roundi(16 * SETTINGS.number("trait/runUp","particle_count_scale",1.0)))
		_runup_node.material.set_shader_parameter("angle",state.ship_heading.angle())
		_runup_node.material.set_shader_parameter("width",(exp(3*x)-1)/(exp(3.0)-1))
	if _tether==null:
		_tether=InstanceBatch.new()
		_tether.setup_shader_quad()
		add_child(_tether)
	_tether.begin()
	var bipolar=ctx.loadout.weapon_behaviors.get(&"W22")
	if bipolar!=null and bipolar.origin!=null:
		var origin:Vector2=bipolar.origin
		var d:=state.ship_pos-origin
		var side:=d.normalized().orthogonal()
		var count:=mini(512,maxi(1,ceili(d.length()/pixel)))
		for i in count:
			var f:=float(i)/count
			for sign_side in [-1.0,1.0]:
				var pos:Vector2=origin+d*f+side*sin(f*TAU*3.0-clock*8.0)*2.5*pixel*sign_side
				_tether.add_upright((pos/pixel).round()*pixel,pixel*0.5,SETTINGS.tinted("weapon/bipolar", Color("#69fff0") if sign_side<0 else Color("#cffff9")))
		for i in 4:
			var f:=fposmod(clock*1.5+i*0.25,1.0)
			_tether.add_upright(((origin+d*f)/pixel).round()*pixel,pixel*0.5,SETTINGS.tinted("weapon/bipolar", Color.WHITE))
		for y in range(-4,5):
			for x in range(-4,5):
				if abs(x)+abs(y)>4:continue
				_tether.add_upright((origin/pixel).round()*pixel+Vector2(x,y)*pixel,pixel*0.5,SETTINGS.tinted("weapon/bipolar", Color.WHITE if abs(x)+abs(y)<2 else Color("#69fff0")))
	_tether.end()
	var tow=ctx.loadout.weapon_behaviors.get(&"W21")
	if _tow_node.is_empty():
		_tow_node=effect(1,Vector2.ZERO,30.0*pixel,1.0,"weapon/massTow",{"c0":Color("#ffbe65"),"c1":Color("#ffbe65"),"c2":Color("#c86a1e"),"c3":Color("#c86a1e")})
		_tow_node.node.z_index=-1
		effects.erase(_tow_node)
	_tow_node.node.visible=tow!=null and not tow.cargo.is_empty()
	if _tow_node.node.visible:
		_tow_node.node.position=tow.cargo[0].pos
		var radius:float=(12.0+sqrt(tow.cargo.size())*3.0)*pixel
		_tow_node.node.scale=Vector2.ONE*(radius+2.0*pixel)
		_tow_node.material.set_shader_parameter("extent",_tow_node.node.scale*2.0)
		_tow_node.material.set_shader_parameter("age",0.15)
