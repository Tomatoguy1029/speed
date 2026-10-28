## シーンから生成した星弾の絵を1つのMeshにまとめ、多数の弾をまとめて描く。
extends AttackVisual
var batch: InstanceBatch

func setup(render: RunPresentation) -> void:
	super(render)
	var library: Resource = rm.run.ctx.resources.resources.get("res://.content/attack_visuals.res")
	if library == null and rm.state.lab_mode: library = load("res://.content/attack_visuals.res")
	assert(library != null, "弾の見た目の生成物が必要です")
	var look: Dictionary = library.get_meta("looks", {}).get(scene_file_path, {}) if library != null else {}
	var mesh: Mesh = look.get("Flight")
	assert(mesh != null, "星弾のFlightに生成済みの図形が必要です")
	if mesh == null: return
	batch = InstanceBatch.new()
	batch._setup_mesh(mesh)
	rm._layers.projectiles.add_child(batch)

func begin_batch() -> void:
	if batch != null: batch.begin()
func end_batch() -> void:
	if batch != null: batch.end()
func draw_shot(_c: CanvasItem, _pr: ProjectileSystem, _i: int, pos: Vector2) -> bool:
	if batch != null: batch.add_upright(pos, 1.0, Color.WHITE)
	return true
