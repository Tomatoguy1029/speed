## ビルドの共通演出。戦闘と図鑑が同じshader・粒・時間を使う。
## 固定の画像は読み込みだけを行い、動く粒は1つのMultiMeshへまとめる。
class_name BuildEffects
extends Node2D
const SETTINGS := preload("res://data/visuals/effect_settings.tres")
const EFFECT := preload("res://shaders/build_effect.gdshader")
const SONIC_WAVE := preload("res://shaders/build_sonic_wave.gdshader")
const SHOT := preload("res://shaders/build_shot.gdshader")
const VALUE_NOISE := preload("res://assets/effects/build/value_noise.png")
const NOISE := preload("res://assets/effects/build/aura_noise.png")
const SHADER_PALETTE := [Color.WHITE, Color(0.85, 0.96, 1.0), Color(0.5, 0.85, 1.0), Color(0.23, 0.61, 0.94)]
var pixel := 2.36
var effects: Array[Dictionary] = []
var sparks: Array[Dictionary] = []
var _particles: InstanceBatch
var _needle_trails: InstanceBatch
var _mine_trails: InstanceBatch
var _shots: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var clock := 0.0
var texture_provider: Callable
var _captures: Array[Dictionary] = []
var _last_world_delta := 0.0
var _needles: Dictionary = {}
var preview_editable := false
var _wave_mesh: ArrayMesh
var _effect_mesh: ArrayMesh

## 音の輪に四角い面を持たせない。形とUVは生成時だけ用意し、全ての輪で共有する。
func _sonic_mesh() -> ArrayMesh:
	if _wave_mesh != null: return _wave_mesh
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in 64:
		for point in [Vector2.ZERO, Vector2.from_angle(i * TAU / 64.0), Vector2.from_angle((i + 1) * TAU / 64.0)]:
			vertices.append(point)
			uvs.append(point * 0.5 + Vector2.ONE * 0.5)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	_wave_mesh = ArrayMesh.new()
	_wave_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _wave_mesh

func _ready() -> void:
	_rng.seed = 121
	_particles = InstanceBatch.new()
	_particles.setup_shader_quad()
	add_child(_particles)
	_needle_trails = InstanceBatch.new()
	_needle_trails.setup_shader_quad()
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_needle_trails.material = additive
	add_child(_needle_trails)
	_mine_trails = InstanceBatch.new()
	_mine_trails.setup_shader_quad()
	add_child(_mine_trails)
	for key in []:
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
	if _effect_mesh == null:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)])
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO,Vector2(1,0),Vector2.ONE,Vector2(0,1)])
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0,1,2,0,2,3])
		_effect_mesh = ArrayMesh.new()
		_effect_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	node.mesh = _effect_mesh
	if mode == 7: node.mesh = _sonic_mesh()
	var material := ShaderMaterial.new()
	material.shader = SONIC_WAVE if mode == 7 else EFFECT
	node.material = material
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.position = (pos / pixel).round() * pixel
	var r := radius * SETTINGS.number(key, "effect_scale", 1.0)
	node.scale = Vector2.ONE * (r + pixel * (8.0 if mode==5 else 2.0))
	material.set_shader_parameter("mode", mode)
	if mode==5: material.set_shader_parameter("barrier_radius",r/(pixel*SETTINGS.number(key,"pixel_scale",1.0)))
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
	var item := {"node": node, "material": material, "age": 0.0, "life": life * SETTINGS.number(key, "duration_scale", 1.0), "key": key, "follow": false, "padding":8.0 if mode==5 else 2.0}
	if preview_editable: item.merge({"base_radius": radius, "base_life": life, "base_options": options.duplicate()})
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
		var velocity := direction * _rng.randf_range(low, high) * pixel * visual_scale
		var particle_life := life * _rng.randf_range(0.7, 1.0)
		var base_size := size_value * _rng.randf_range(0.7, 1.4)
		var base_color: Color = colors[i % colors.size()]
		var particle := {"pos": pos, "velocity": velocity,
			"age": 0.0, "life": particle_life, "color": SETTINGS.tinted(key, base_color),
			"size": base_size * visual_scale * cell_scale, "delay": 0.0}
		if preview_editable: particle.merge({"base_size": base_size, "base_color": base_color, "visual_key": key})
		sparks.append(particle)

## 停止中の画面を作り直さず、既存の粒とシェーダに編集値だけを反映する。
func refresh_preview() -> void:
	for item in effects:
		var key: String = item.key
		var node: MeshInstance2D = item.node
		var material: ShaderMaterial = item.material
		if item.has("base_radius"):
			var radius: float = item.base_radius * SETTINGS.number(key, "effect_scale", 1.0)
			node.scale = Vector2.ONE * (radius + pixel * float(item.get("padding",2.0)))
			if int(material.get_shader_parameter("mode"))==5: material.set_shader_parameter("barrier_radius",radius/(pixel*SETTINGS.number(key,"pixel_scale",1.0)))
			material.set_shader_parameter("extent", node.scale * 2.0)
			material.set_shader_parameter("duration", item.base_life * SETTINGS.number(key, "duration_scale", 1.0))
		material.set_shader_parameter("pixel", pixel * SETTINGS.number(key, "pixel_scale", 1.0))
		material.set_shader_parameter("tint", SETTINGS.tinted(key, Color.WHITE))
		material.set_shader_parameter("age", maxf(0.0, item.age))
		var options: Dictionary = item.get("base_options", {})
		for index in SHADER_PALETTE.size():
			var field := "shader_c" + str(index)
			material.set_shader_parameter("c" + str(index), options.get("c" + str(index), SHADER_PALETTE[index]) * SETTINGS.values_for(key).get(field, Color.WHITE))
		if item.get("distortion", false): material.set_shader_parameter("strength", SETTINGS.number(key, "distortion_strength", 1.0))
	for particle in sparks:
		if not particle.has("visual_key"): continue
		var key: String = particle.visual_key
		particle.color = SETTINGS.tinted(key, particle.base_color)
		particle.size = particle.base_size * SETTINGS.number(key, "effect_scale", 1.0) * SETTINGS.number(key, "pixel_scale", 1.0)

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
			if ev.get("cause", &"")==&"bipolar":
				var fire := effect(1,ev.pos,7.0*pixel,0.5,"weapon/bipolar",{"c1":Color("#cffff9"),"c2":Color("#69fff0"),"c3":Color("#1f7f86")})
				fire.age=-_rng.randf()*0.08
				for sign_side in [-1.0,1.0]:
					burst(ev.pos,4,ev.dir.angle()+PI*0.5*sign_side,1.0,40,100,0.3,[Color.WHITE,Color("#ff7a6b")],"weapon/bipolar")
				return true
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
		&"escort_deploy", &"escort_slash": pass  # 表示は render/equipment/dashRangeDrone.gd
		&"anchor_capture":
			effect(0,ev.pos,12.0*pixel,0.14,"weapon/massTow",{"c1":Color("#ffbe65")})
			burst(ev.pos,12,(ev.to-ev.pos).angle(),0.3,40,80,0.45,[Color("#fff2c0"),Color("#ffbe65")],"weapon/massTow")
		&"anchor_fire":
			effect(1,ev.pos,14.0*pixel,0.45,"weapon/massTow",{"c1":Color("#fff2a8"),"c2":Color("#ffb030"),"c3":Color("#d2461c")})
			effect(0,ev.pos,28.0*pixel,0.16,"weapon/massTow",{"c1":Color("#ffbe65")})
			burst(ev.pos,9,ev.dir.angle(),1.3,60,120,0.25,[Color.WHITE,Color("#fff2c0"),Color("#ffbe65")],"weapon/massTow")
		&"ring":
			# 双極の両端はbeamで二重輪を描く。
			return key=="weapon/bipolar"
		&"bipolar_charge":
			for pos in [ev.from,ev.to]:
				for i in 20:
					var radial:=Vector2.from_angle(_rng.randf()*TAU)*_rng.randf_range(10,30)*pixel
					sparks.append({"pos":pos+radial,"center":pos,"inward":radial,"swirl":0.0,"velocity":Vector2.ZERO,"age":0.0,"life":0.18,"delay":0.0,"color":Color("#cffff9"),"size":1.0})
		&"beam":
			if key!="weapon/bipolar":return false
			var delta: Vector2=ev.to-ev.from
			var visual_width := 16.0*float(ev.get("width_scale",1.0))
			var beam := effect(6,(ev.from+ev.to)*0.5,delta.length()*0.5+visual_width*pixel*0.6,0.7,key,{"angle":delta.angle(),"width":visual_width,"beam_length":delta.length()/pixel,"phase":clock,"c1":Color("#cffff9"),"c2":Color("#69fff0"),"c3":Color("#1f7f86")})
			beam["beam"]={"from":ev.from,"to":ev.to,"width":visual_width,"acc":0.0}
			for pos in [ev.from,ev.to]:
				effect(20,pos,36.0*pixel,0.35,key,{"c1":Color("#cffff9"),"c2":Color("#69fff0")})
				effect(1,pos,20.0*pixel,0.5,key,{"c1":Color("#cffff9"),"c2":Color("#69fff0"),"c3":Color("#1f7f86")})
				burst(pos,16,0,TAU,35,140,0.4,[Color.WHITE,Color("#69fff0")],key)
			burst((ev.from+ev.to)*0.5,70,delta.angle()+PI*0.5,0.0,10,40,0.5,[Color("#cffff9"),Color("#69fff0")],key)
			for i in range(maxi(0,sparks.size()-70),sparks.size()):
				sparks[i].delay=0.55
				sparks[i].life=_rng.randf_range(0.3,0.5)
				sparks[i].fade=true
				sparks[i].color=Color("#cffff9")
				sparks[i].late_color=Color("#69fff0")
				if _rng.randf()<0.5: sparks[i].velocity=-sparks[i].velocity
				sparks[i].pos=ev.from.lerp(ev.to,_rng.randf())

		&"weapon_fire":
			if not ev.has("pos"): return false
			# 射撃の武器の砲口・当たりは各武器の表示（render/equipment）が描く。
			if key in ["weapon/interceptor", "weapon/forward", "weapon/scatter", "weapon/rear"]: return true
			effect(2, ev.pos, pixel * 17.0, 0.1, key, {"angle": ev.angle, "width": 1.0 if key == "weapon/scatter" else 2.0})
			if key == "weapon/scatter":
				burst(ev.pos, 15, ev.angle, 1.4, 60.0, 120.0, 0.1, [Color("#ffffff"), Color("#7fd8ff"), Color("#d8f6ff")], key)
			if key == "weapon/rear": burst(ev.pos, 1, ev.angle + PI * 0.5, 0.3, 30.0, 50.0, 0.35, [Color("#ffd27a"), Color("#b07a14")], key, 1.5)
		&"shot_hit":
			if key=="weapon/massTow":
				effect(1,ev.pos,13.0*pixel,0.45,key,{"c1":Color("#fff2a8"),"c2":Color("#ffb030"),"c3":Color("#d2461c")})
				return true
			# 射撃の武器の当たりは各武器の表示（render/equipment）が描く。
			if key in ["weapon/interceptor", "weapon/forward", "weapon/scatter", "weapon/rear"]: return true
			var big := key != "weapon/scatter"
			effect(3, ev.pos, 16.0 * pixel, 0.18 if big else 0.14, key, {"width": 2.0 if big else 0.0})
			burst(ev.pos, 13 if big else 5, ev.dir.angle() + PI, 2.6 if big else 2.0, 30, 120 if big else 90, 0.22,
				[Color.WHITE, Color("#bff3ff"), Color("#4fb8ff")], key)
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
		&"chain_shock": pass  # 表示は render/equipment/killSonic.gd
		&"space_quake": pass  # 表示は render/equipment/contactWave.gd と RenderPipeline.add_ripple
		&"barrier_hit":
			var last := roundi(float(ev.radius)*SETTINGS.number("weapon/barrier","effect_scale",1.0)/(sqrt(3.0)*4.0*pixel*SETTINGS.number("weapon/barrier","pixel_scale",1.0)))
			var life: float = 0.21+(last-3)*0.05+0.1
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
		&"flash_slash", &"slash_mark", &"slash_release": pass  # 表示は render/equipment/flashSlash.gd
		&"hull_scatter":
			# 星砕きの破片の割れ方は render/equipment/knockback.gd が描く。
			if key == "weapon/knockback": return true
			effect(3, ev.pos, 16.0 * pixel, 0.18, "weapon/knockback", {"width": 2.0})
			burst(ev.pos, 20, 0, TAU, 10, 70, 0.3, [Color.WHITE, Color("#dcaaff"), Color("#8e62df")], "weapon/knockback")
		&"end_hole":
			var item := _distortion(ev.pos, 98.0 * pixel, float(ev.life), "trait/vortex", 1)
			item.follow = true
			for i in roundi(140 * SETTINGS.number("trait/vortex","particle_count_scale",1.0)):
				var radial:=Vector2.from_angle(_rng.randf()*TAU)*_rng.randf_range(40,180)*pixel
				sparks.append({"pos":ev.pos+radial,"inward":radial,"swirl":_rng.randf_range(-0.8,0.8),"velocity":Vector2.ZERO,"age":0.0,"life":_rng.randf_range(0.08,0.24),"delay":_rng.randf()*0.18,"color":Color.WHITE if i%3==0 else Color("#be78ff"),"size":_rng.randf_range(0.8,2.6)})
		&"hole_recover":
			var item := effect(0, ev.pos, 52.0 * pixel, 0.7, "trait/vortex", {"c0": Color("#dcffe6"), "c1": Color("#8fffbe"), "c2": Color("#6effaa")})
			item.follow = true
			burst(ev.pos, 14, -PI * 0.5, 2.0, 14, 40, 0.7, [Color("#8fffbe")], "trait/vortex")
		&"sonic_push", &"sonic_impact": pass  # 表示は render/equipment/sonic.gd
		&"run_up_hit": pass  # 表示は render/equipment/runUp.gd
		&"full_burst_ready": pass  # 表示は render/equipment/fullBurst.gd
		_: return false
	return true

func _distortion(pos: Vector2, radius: float, life: float, key: String, kind: int) -> Dictionary:
	# 波の帯（片側8ドット）が最外周でも切れない範囲を取る。
	var item := effect(0, pos, radius + (8.0 * pixel if kind == 0 else 0.0), life, key)
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
	_needle_trails.begin()
	for needle in _needles.values():
		needle.age+=dt
		var progress:=minf(1.0,float(needle.age)/0.06)
		needle.node.visible=progress>=0.6
		needle.node.position=needle.center+Vector2.from_angle(float(needle.angle))*(float(needle.radius)*0.6+170.0*pixel*(1.0-progress))
		needle.material.set_shader_parameter("age",0.0)
		needle.material.set_shader_parameter("width",2.4 if needle.release else 1.6)
		var tail_alpha := maxf(0.0,(progress-0.6)/0.4) if needle.age<0.06 else maxf(0.0,1.0-(float(needle.age)-0.06)/0.08)
		if tail_alpha>0.0:
			var length_px := 60.0 if needle.age<0.06 else 60.0*tail_alpha
			var direction := Vector2.from_angle(float(needle.angle))
			var center: Vector2 = needle.node.position+direction*length_px*pixel*0.5
			_needle_trails.add_rect(center,Vector2(length_px,2.2*tail_alpha+0.4)*pixel*0.5,needle.angle,SETTINGS.tinted("weapon/flashSlash",Color(Color("#c8a0ff"),0.55*tail_alpha)))
			_needle_trails.add_rect(center,Vector2(length_px,0.8)*pixel*0.5,needle.angle,SETTINGS.tinted("weapon/flashSlash",Color(1,1,1,0.7*tail_alpha)))
	_needle_trails.end()
	for item in effects:
		item.age += dt
		item.node.visible = item.age >= 0.0
		if item.follow: item.node.position = ship_pos
		item.material.set_shader_parameter("age", maxf(0.0, item.age))
		if item.get("distortion", false):
			item.material.set_shader_parameter("screen_scale", get_global_transform_with_canvas().get_scale().abs())
		if item.has("beam") and item.age<0.3:
			var beam: Dictionary = item.beam
			beam.acc+=dt*48.0
			while beam.acc>=1.0:
				beam.acc-=1.0
				var side: Vector2 = (beam.to-beam.from).normalized().orthogonal()*(1.0 if _rng.randf()<0.5 else -1.0)
				var pos: Vector2 = beam.from.lerp(beam.to,_rng.randf())+side*float(beam.width)*pixel*0.5
				burst(pos,2,side.angle(),0.8,30,90,0.2,[Color.WHITE,Color("#cffff9"),Color("#69fff0")],item.key)
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
		if particle.has("late_color") and q>0.4: color=particle.late_color
		if particle.get("fade",false): color.a*=1.0-q
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
	# 快進撃のオーラは render/equipment/rampage.gd が描く。
	# ギアアップの炎は render/equipment/fullCharge.gd が描く。
	# ソニックブームの音の輪は render/equipment/sonic.gd が描く。
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
	_mine_trails.begin()
	var launcher = ctx.loadout.weapon_behaviors.get(&"W07")
	if launcher != null:
		for mine in launcher.mines:
			_mines.add_upright((mine.pos / pixel).round() * pixel, 18.0 * pixel * SETTINGS.number("weapon/mines","effect_scale",1.0), Color(0, mine.age, clock+float(mine.id)*0.17, 1))
			if mine.age<0.3:
				var ease := 1.0-pow(1.0-minf(1.0,float(mine.age)/0.14),3.0)
				var start: Vector2 = mine.from.lerp(mine.to,maxf(0.0,ease-0.5))
				var count := ceili(start.distance_to(mine.pos)/pixel)
				for dot in range(count+1):
					if mine.age>0.12 and (dot+floori(clock*60.0))%3==0: continue
					var pos: Vector2 = start.lerp(mine.pos,float(dot)/maxi(1,count))
					var color := Color("#cfeaff") if mine.age<0.15 else Color("#6fa8e8")
					_mine_trails.add_upright((pos/pixel).round()*pixel,pixel*0.5,SETTINGS.tinted("weapon/mines",color))
	_mines.end()
	_mine_trails.end()

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
var _runup_node: Dictionary = {}
var _tow_node: Dictionary = {}
var _steam_opacity := 0.0
var _steam_pulse := 0.0
var _previous_sonic_pulse := 0.0
var _sonic_tracks: Dictionary = {}
func _continuous(ctx: RunContext, dt: float) -> void:
	var state:=ctx.state
	# ソニックブームの蒸気と押された敵の筋は render/equipment/sonic.gd が描く。
	# エスコートウィングの機体の光跡は render/dash_range_drone.gd が描く。
	# 助走の尾は render/equipment/runUp.gd が描く。
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
