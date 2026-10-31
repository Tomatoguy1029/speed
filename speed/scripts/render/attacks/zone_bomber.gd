## ボマーの自爆表示。判定の寿命と独立した、ドット単位の爆発の専用設定。表示時間は爆発の調整値から決まる。
extends AttackVisual
const KEY := "res://scenes/attacks/zone_bomber.tscn"
const BLAST_BURSTS := preload("res://scripts/render/fx/blast_bursts.gd")
const TUNED_SHADERS := [preload("res://shaders/bomber_burst.gdshader")]
@export_range(0.5, 4.0, 0.05) var pixel_scale := 1.0
@export_range(0.25, 3.0, 0.05) var effect_scale := 0.8333333333333333
var _blasts: BlastBursts
var _seen: Dictionary = {}
var _world_time := 0.0
var preview_paused := false
var _preview_age := 0.0
var _preview_shape := Vector2.ZERO

func setup(render: RunPresentation) -> void:
	super.setup(render)
	_world_time = state.world_time
	_create_blasts()

func _ready() -> void:
	if rm == null: preview_restart()

## 派生する着弾表示は、所有するshaderをここで指定する。
func burst_shader() -> Shader:
	return TUNED_SHADERS[0]

func _create_blasts() -> void:
	_blasts = BLAST_BURSTS.new()
	_blasts.shader = burst_shader()
	_blasts.key = KEY
	_blasts.setup(1.82 * (rm.cfg.character_scale if rm != null else 1.3) * pixel_scale)
	if rm != null:
		_blasts.visibility_layer = 1 | RenderPipeline.GLOW_LAYER
		_blasts.modulate = RenderPipeline.plain_color(rm._layers.fx)
		rm._layers.fx.add_child(_blasts)
	else: add_child(_blasts)

func update(_dt: float) -> void:
	var now := state.world_time
	_blasts.step(maxf(0.0, now - _world_time))
	_world_time = now
	var pr := rm.run.projectiles
	for row in _seen.keys():
		if row >= pr.hazard_alive.size() or pr.hazard_alive[row] == 0 or not is_same(_seen[row], pr.hazard_enemy_hit[row]):
			_seen.erase(row)

func draw_hazard(_c: CanvasItem, pr: ProjectileSystem, i: int, view: Rect2) -> void:
	if pr.hazard_t[i] < pr.hazard_delay[i]: return
	# spawnごとに新しくなる命中辞書の参照で、行番号再利用と同じ爆発の再描画を区別する。
	if is_same(_seen.get(i), pr.hazard_enemy_hit[i]): return
	if not view.grow(pr.hazard_len[i] * effect_scale * 1.2).has_point(pr.hazard_pos[i]): return
	_seen[i] = pr.hazard_enemy_hit[i]
	_spawn(pr.hazard_pos[i], pr.hazard_len[i], pr.hazard_t[i] - pr.hazard_delay[i])

func _spawn(at: Vector2, radius: float, age: float) -> void:
	_blasts.add(at, radius / _blasts.px * effect_scale, -age)
	_blasts.step(0.0)

## 実行時はRunPresentationから世界時間で更新。単独シーンのときだけ反復プレビューする。
func _process(dt: float) -> void:
	if rm == null: preview_step(0.0 if preview_paused else dt)

func preview_restart(age := 0.0) -> void:
	if is_instance_valid(_blasts):
		remove_child(_blasts)
		_blasts.queue_free()
	_create_blasts()
	_preview_age = age
	_preview_shape = Vector2(pixel_scale, effect_scale)
	_spawn(Vector2.ZERO, 110.0, age)

func preview_step(dt: float) -> void:
	if Vector2(pixel_scale, effect_scale) != _preview_shape:
		# 位置・半径・ドット幅を作り直し、停止中も同じ時刻で表示する。
		preview_restart(_preview_age)
	_preview_age += dt
	_blasts.step(dt)
	if _preview_age >= _preview_life() + 0.45: preview_restart()

func _preview_life() -> float:
	var mat := ShaderMaterial.new()
	mat.shader = burst_shader()
	ShaderTuning.apply(mat, KEY)
	return BlastBursts._life(mat)

func _exit_tree() -> void:
	if rm != null and is_instance_valid(_blasts): _blasts.queue_free()
