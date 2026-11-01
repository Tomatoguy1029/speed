## 固定の輪郭接点・枝分かれ経路を共有し、個体ごとの短い局所放電だけを更新する。
extends Node2D

const ASSETS := "res://assets/effects/landmark/elite_contacts.tres"
const RUNTIME := "res://data/visuals/elite_runtime.tres"
const MAX_SEGMENTS := 8192
const STRIDE := 16 # transform 8, normalized appearance 4, source segment 4
var _rm: RunPresentation
var _assets: Resource
var _entries: Dictionary
var _runtime: Resource
var _interval_min := 0.0
var _interval_random := 0.0
var _interval_max := 0.0
var _arc_count := 0
var _spark_count := 0
var _states: Dictionary = {}
var _stale: Array[int] = []
var _batches: Array[MultiMeshInstance2D] = []
var _buffer := PackedFloat32Array()
var _count := 0
var _capacity := 0
var _epoch := 0
var _clock := -INF

func setup(render: RunPresentation) -> void:
	_rm = render
	var scope := render.run.ctx.resources
	for path in [ASSETS, RUNTIME]:
		if not scope.resources.has(path) and render.state.lab_mode: scope.provide(path, load(path))
		assert(scope.resources.has(path), "エリート描画の事前準備が必要: " + path)
	_assets = scope.resources.get(ASSETS)
	_runtime = scope.resources.get(RUNTIME)
	if _assets == null or _runtime == null: return
	_timing(_runtime.get_meta("values"))
	_entries = _assets.get_meta("entries", {})
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0,1,2,0,2,3])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	for shadow in [true, false]:
		var batch := MultiMeshInstance2D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = mesh
		mm.custom_aabb = AABB(Vector3(-20000,-20000,-1),Vector3(40000,40000,2))
		batch.multimesh = mm
		var material := ShaderMaterial.new()
		material.shader = _runtime.get_meta("shader") as Shader
		material.set_shader_parameter("shadow_pass", shadow)
		material.set_shader_parameter("linear_colors", RenderingServer.get_current_rendering_method() != "gl_compatibility")
		batch.material = material
		add_child(batch)
		_batches.append(batch)

## 編集画面だけが元の可変shaderと未保存値を渡す。
func set_settings(value: Resource, shader: Shader) -> void:
	if value == null or shader == null: return
	var values := {}
	for key in ["interval_min", "interval_random", "interval_max", "arc_count", "spark_count"]: values[key] = value.get(key)
	_timing(values)
	for n in _batches.size():
		var material := _batches[n].material as ShaderMaterial
		material.shader = shader
		material.set_shader_parameter("shadow_pass", n == 0)
		value.call("apply_to", material)
	_states.clear()

func _timing(values: Dictionary) -> void:
	_interval_min = float(values.interval_min)
	_interval_random = float(values.interval_random)
	_interval_max = float(values.interval_max)
	_arc_count = int(values.arc_count)
	_spark_count = int(values.spark_count)

func begin() -> void:
	_count = 0
	_epoch += 1
	if _rm.state.world_time < _clock: _states.clear()
	_clock = _rm.state.world_time

func add_enemy(t: EnemyTable, row: int, deformation: Dictionary) -> void:
	if _runtime == null: return
	if t.def[row].behavior == &"triangle":
		for k in range(0,t.parts[row].size(),2):
			var child: int = t.parts[row][k]
			if _rm.run.enemies.is_same(child,t.parts[row][k+1]) and t.dead[child] == 0: _add_body(t,child,{})
	else:
		_add_body(t,row,deformation)

func _add_body(t: EnemyTable, row: int, deformation: Dictionary) -> void:
	var look := _rm.look_of(t.type[row])
	var key: String = look.source_path if look != null else "sprite:" + String(t.type[row])
	if look != null and look.split_other != null:
		if t.buds[row] == 1: key = look.split_other.source_path
		elif t.buds[row] == 0: key += ":joined"
	if not _entries.has(key): key = "shape:" + String(t.def[row].shape)
	assert(_entries.has(key), "エリート接点のベイクが必要: " + key)
	if not _entries.has(key): return
	var entry: Dictionary = _entries[key]
	var patterns: Array = entry.patterns
	var id: int = t.id[row]
	if not _states.has(id) or _states[id].key != key:
		var rng := RandomNumberGenerator.new()
		rng.seed = id * 104729 + 17041
		_states[id] = {"key":key,"rng":rng,"next":_clock+rng.randf_range(0.02,0.24),"events":[],"seen":_epoch}
	var state: Dictionary = _states[id]
	state.seen = _epoch
	var events: Array = state.events
	for n in range(events.size()-1,-1,-1):
		if _clock-events[n].born >= 0.3: events.remove_at(n)
	if _clock >= float(state.next):
		if events.size() < 4: events.append(_event(state.rng,patterns,entry.origin))
		var wait := _interval_min-log(maxf(0.001,1.0-state.rng.randf()))*_interval_random
		state.next = _clock+minf(maxf(_interval_min,_interval_max),wait)
	var visual := _rm._visual_of(t,row)
	var scale_px := _rm.enemy_sprite_radius(t.type[row],t.r[row])/float(entry.source_radius)
	if entry.pump: scale_px = visual._source_scale(t,row)
	var pose := Transform2D(_rm._enemy_sprite_angle(t.type[row],t.facing[row]),t.pos[row]).scaled_local(Vector2.ONE*scale_px)
	if not deformation.is_empty() and deformation.direction.length_squared() > 0.0001:
		var normal: Vector2 = deformation.direction.normalized()
		var side := normal.orthogonal()
		for column in 2:
			pose[column] = normal*pose[column].dot(normal)*(1.0-0.5*deformation.amount)+side*pose[column].dot(side)*(1.0+0.6*deformation.amount)
	pose.origin -= pose.basis_xform(entry.origin)
	var remaining := 4
	for event: Dictionary in events:
		var age := _clock-float(event.born)
		var frame := floori(age*30.0)
		if frame < int(event.frames):
			var power: float = (0.75 if frame%2 else 0.95)*event.power
			for index in event.paths:
				if remaining <= 0: break
				remaining -= 1
				var path: Dictionary = patterns[index]
				var path_pose := _part_pose(pose,entry,visual,t,row,path.part,deformation)
				var segments: PackedVector2Array = path.frames[mini(frame,3)]
				for n in range(0,segments.size(),3):
					var a := _point(segments[n],path.part,entry,visual,t,row)
					var b := _point(segments[n+1],path.part,entry,visual,t,row)
					_segment(a,b,path_pose,1.0,power*float(segments[n+2].x),false)
		var anchor: Dictionary = patterns[event.paths[0]]
		var spark_pose := _part_pose(pose,entry,visual,t,row,anchor.part,deformation)
		var sparks: PackedFloat32Array = event.sparks
		for n in range(0,sparks.size(),5):
			var life := float(sparks[n])
			var spark_age := age-float(sparks[n+1])
			if spark_age < 0.0 or spark_age >= life: continue
			var start: Vector2 = anchor.a if sparks[n+2] < 0.7 else anchor.b
			var velocity := Vector2(sparks[n+3],sparks[n+4])
			var drag := exp(-2.2*spark_age)
			var point := start+velocity*((1.0-drag)/2.2)
			var tail := point-velocity.normalized()*minf(9.0,1.0+velocity.length()*drag*0.022)
			_segment(_point(tail,anchor.part,entry,visual,t,row),_point(point,anchor.part,entry,visual,t,row),spark_pose,1.0-spark_age/life,0.9,true)

func _event(rng: RandomNumberGenerator, patterns: Array, origin: Vector2) -> Dictionary:
	var amount := rng.randf()
	var count := clampi(_arc_count+(-1 if amount<0.15 else 1 if amount>0.85 else 0),1,4)
	var paths := PackedInt32Array()
	for _n in count: paths.append(rng.randi_range(0,patterns.size()-1))
	var power := rng.randf_range(0.68,1.0)
	var sparks := PackedFloat32Array()
	var spark_count := mini(_spark_count,0 if rng.randf()<0.32 else 1 if rng.randf()<0.73 else rng.randi_range(2,3))
	var anchor: Dictionary = patterns[paths[0]]
	for _n in spark_count:
		var endpoint := rng.randf()
		var start: Vector2 = anchor.a if endpoint<0.7 else anchor.b
		var direction := (start-origin).angle()+rng.randf_range(-0.7,0.7)
		var velocity := Vector2.from_angle(direction)*rng.randf_range(60,150)*power*0.65-Vector2(0,30)
		sparks.append_array(PackedFloat32Array([rng.randf_range(0.10,0.24),rng.randf_range(0,0.025),endpoint,velocity.x,velocity.y]))
	return {"born":_clock,"frames":rng.randi_range(2,4),"power":power,"paths":paths,"sparks":sparks}

func _part_pose(pose: Transform2D, entry: Dictionary, visual: EnemyVisual, t: EnemyTable, row: int, part: int, deformation: Dictionary) -> Transform2D:
	if entry.biter and visual != null and visual.has_method("elite_pose"): return visual.call("elite_pose",t,row,part,deformation)
	return pose

func _point(point: Vector2, _part: int, entry: Dictionary, visual: EnemyVisual, t: EnemyTable, row: int) -> Vector2:
	if entry.pump and point.y >= 18.0:
		var full := 1.0 if t.mode[row] == EnemyTable.Mode.WINDUP else clampf((t.r[row]/maxf(visual._base_radius(t,row),0.001)-1.0)/maxf(float(t.def[row].params.grow),0.001),0.0,1.0)
		var delta := point-Vector2(12,27)
		var index := posmod(roundi(fposmod(delta.angle(),TAU)/TAU*72.0),72)
		var original: float = _assets.get_meta("pump_outline")[index]
		return Vector2(12,27)+delta*(lerpf(original,16.5,full)/original)
	return point

func _segment(a: Vector2, b: Vector2, pose: Transform2D, opacity: float, power: float, spark: bool) -> void:
	if _count >= MAX_SEGMENTS: return
	var delta := b-a
	var length := delta.length()
	if length < 0.05: return
	var direction := delta/length
	var xf := (pose*Transform2D(direction.angle(),(a+b)*0.5)).scaled_local(Vector2((length+6.0)*0.5,3.0))
	var offset := _count*STRIDE
	if _buffer.size() < offset+STRIDE: _buffer.resize(mini(MAX_SEGMENTS,maxi(256,_count*2))*STRIDE)
	_buffer[offset]=xf.x.x; _buffer[offset+1]=xf.y.x; _buffer[offset+2]=0; _buffer[offset+3]=xf.origin.x
	_buffer[offset+4]=xf.x.y; _buffer[offset+5]=xf.y.y; _buffer[offset+6]=0; _buffer[offset+7]=xf.origin.y
	_buffer[offset+8]=opacity; _buffer[offset+9]=power; _buffer[offset+10]=1.0 if spark else 0.0; _buffer[offset+11]=1.0
	_buffer[offset+12]=a.x; _buffer[offset+13]=a.y; _buffer[offset+14]=delta.x; _buffer[offset+15]=delta.y
	_count += 1

func end() -> void:
	if _count > _capacity:
		_capacity = mini(MAX_SEGMENTS,maxi(_count,maxi(256,_capacity*2)))
		for batch in _batches: batch.multimesh.instance_count = _capacity
	if _capacity > 0:
		_buffer.resize(_capacity*STRIDE)
		for batch in _batches:
			batch.multimesh.visible_instance_count = _count
			if _count > 0: batch.multimesh.buffer = _buffer
	_stale.clear()
	for id: int in _states:
		if _states[id].seen != _epoch: _stale.append(id)
	for id in _stale: _states.erase(id)
