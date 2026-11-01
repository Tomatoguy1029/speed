## pixelfxのLaser boltに沿った、白い芯・緑の色帯・流れる光点。ノードは同時表示数の範囲で再利用する。
extends AttackVisual
const SHADER := preload("res://shaders/pump_shell.gdshader")
const RUNTIME_SHADER := preload("res://shaders/pump_shell_runtime.gdshader")
const RUNTIME_DATA := preload("res://data/visuals/pump_shell_runtime.tres")
const TUNED_SHADERS := [SHADER]
const KEY := "res://scenes/attacks/shell.tscn"
var _mesh: QuadMesh
var _nodes: Array[MeshInstance2D] = []
var _content_types: Array[PackedStringArray] = []
var _content_full: Array[float] = []
var _trail_reach: Array[float] = []
var _textures: Dictionary = {}
var _preview_images: Dictionary = {}
var _preview_contents := PackedStringArray(["bomber", "splitter", "splitling", "bomber", "splitter", "splitling", "bomber",
	"splitter", "splitling", "bomber", "splitter", "splitling", "bomber", "splitter", "splitling", "bomber", "splitter", "splitling", "bomber", "splitter"])
var _count := 0
var preview_paused := false
var _preview_age := 0.0

func _apply_effect_settings() -> void:
	if ShaderTuning.previewing():
		super._apply_effect_settings()
		return
	var fixed: Dictionary = RUNTIME_DATA.get_meta("values")
	flight_scale = float(fixed.flight_scale)
	effect_tint = fixed.effect_tint

func setup(render: RunPresentation) -> void:
	super.setup(render)
	_prepare_mesh()

func _prepare_mesh() -> void:
	if _mesh != null: return
	_mesh = QuadMesh.new()
	# vertex shaderが132x48の描画域を作る。上限倍率まで収めるculling用の寸法。
	_mesh.size = Vector2(800, 256)

func _ready() -> void:
	if rm == null:
		_prepare_mesh()
		preview_restart()

func begin_batch() -> void:
	_count = 0
func end_batch() -> void:
	for n in range(_count, _nodes.size()): _nodes[n].hide()
func draw_shot(c: CanvasItem, pr: ProjectileSystem, i: int, pos: Vector2) -> bool:
	var payload: Dictionary = pr.pump_shells.get(i, {})
	var angle := pr.hostile_vel[i].angle()
	var direction := Vector2.from_angle(angle)
	var mouth: Vector2 = payload.get("mouth", pos - direction * 1000.0)
	var reach := maxf(0.0, (pos - mouth).dot(direction))
	_present(c, pos, angle, pr.hostile_r[i], state.world_time, payload.get("types", PackedStringArray()), float(payload.get("full", 0.0)), reach)
	return true

## 通常ランはScopeで準備済みの塗装画像を共有する。編集用の単独プレビューも生成済み画像を読む。
func _contents_texture(type: StringName) -> Texture2D:
	if not _textures.has(type):
		if rm != null:
			_textures[type] = rm._enemy_texture(type)
		else:
			var look := RunPresentation.load_look(type)
			var def := load("res://data/enemies/%s.tres" % type) as EnemyDef
			_textures[type] = RunPresentation.look_texture(look, _preview_images, def.armor_colors) if look != null and def != null else null
	return _textures[type]

func _present(c: CanvasItem, pos: Vector2, angle: float, radius: float, clock: float, contents: PackedStringArray, full: float, reach := 1000000.0) -> void:
	if _count == _nodes.size():
		var created := MeshInstance2D.new()
		created.mesh = _mesh
		var created_material := ShaderMaterial.new()
		var editable := rm == null or ShaderTuning.previewing()
		created_material.shader = SHADER if editable else RUNTIME_SHADER
		if not editable:
			created_material.set_shader_parameter("linear_colors", RenderingServer.get_current_rendering_method() != "gl_compatibility")
		created.material = created_material
		created.visibility_layer = 1 | RenderPipeline.GLOW_LAYER
		c.add_child(created)
		_nodes.append(created)
		_content_types.append(PackedStringArray())
		_content_full.append(-1.0)
		_trail_reach.append(-1.0)
	var slot := _count
	var node := _nodes[_count]
	_count += 1
	var scale_px := radius / 38.0 * flight_scale
	var dir := Vector2.from_angle(angle)
	node.position = pos - dir * 55.0 * scale_px
	node.rotation = angle
	node.scale = Vector2.ONE * scale_px
	node.modulate = RenderPipeline.plain_color(rm._layers.projectiles, effect_tint) if rm != null else Color.WHITE
	node.show()
	var material := node.material as ShaderMaterial
	if _content_types[slot] != contents or _content_full[slot] != full:
		# 最初に各種類を1枚ずつ拾い、残りは収納順で詰める。画像のない仮図形は白い矩形にしない。
		var samples := PackedStringArray()
		var distinct := {}
		for type in contents:
			if samples.size() == 7: break
			if not distinct.has(type) and _contents_texture(StringName(type)) != null:
				distinct[type] = true
				samples.append(type)
		var skipped := {}
		for type in contents:
			if samples.size() == 7: break
			if not distinct.has(type): continue
			if not skipped.has(type):
				skipped[type] = true
				continue
			samples.append(type)
		for k in samples.size(): material.set_shader_parameter("enemy%d" % k, _contents_texture(StringName(samples[k])))
		material.set_shader_parameter("contents_count", float(samples.size()))
		material.set_shader_parameter("contents_fill", full)
		_content_types[slot] = contents
		_content_full[slot] = full
	var local_reach := minf(432.0, reach / maxf(scale_px, 0.001))
	if _trail_reach[slot] != local_reach:
		material.set_shader_parameter("trail_reach", local_reach)
		_trail_reach[slot] = local_reach
	material.set_shader_parameter("clock", clock)
	if material.shader == SHADER: ShaderTuning.apply(material, KEY)

## 単独プレビューも同じ光弾・描画パラメータを使う。飛行を画面内へ縮尺表示する。
func _process(dt: float) -> void:
	if rm == null: preview_step(0.0 if preview_paused else dt)

func preview_restart(age := 0.0) -> void:
	_preview_age = age
	preview_step(0.0)

func preview_step(dt: float) -> void:
	_preview_age = fmod(_preview_age + dt, 640.0 / 900.0 + 0.35)
	begin_batch()
	if _preview_age < 640.0 / 900.0:
		var at := Vector2((-320.0 + 900.0 * _preview_age) * 0.6, 0.0)
		_present(self, at, 0.0, 26.0 * 0.6, _preview_age, _preview_contents, 1.0)
	end_batch()
