## ボマーの自爆表示。判定の寿命と独立した、既存ピクセル炎の専用設定。
extends AttackVisual
const KEY := "res://scenes/attacks/zone_bomber.tscn"
const FIRE_BURSTS := preload("res://scripts/render/fx/fire_bursts.gd")
const TUNED_SHADERS := [preload("res://shaders/fire_burst.gdshader")]
@export_range(0.05, 2.0, 0.01) var visible_seconds := 0.65
@export_range(0.5, 4.0, 0.05) var pixel_scale := 1.0
@export_range(0.25, 3.0, 0.05) var effect_scale := 0.8333333333333333
var _fires: FireBursts
var _seen: Dictionary = {}
var _world_time := 0.0
var preview_paused := false
var _preview_age := 0.0
var _preview_shape := Vector3.ZERO

func setup(render: RunPresentation) -> void:
	super.setup(render)
	_world_time = state.world_time
	_create_fires()

func _ready() -> void:
	if rm == null: preview_restart()

func _create_fires() -> void:
	_fires = FIRE_BURSTS.new()
	_fires.key = KEY
	_fires.setup(1.82 * (rm.cfg.character_scale if rm != null else 1.3) * pixel_scale)
	if rm != null:
		_fires.visibility_layer = 1 | RenderPipeline.GLOW_LAYER
		_fires.modulate = RenderPipeline.plain_color(rm._layers.fx)
		rm._layers.fx.add_child(_fires)
	else: add_child(_fires)

func update(_dt: float) -> void:
	var now := state.world_time
	_fires.step(maxf(0.0, now - _world_time))
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
	if age >= visible_seconds: return
	_fires.add(at, radius / _fires.px * effect_scale, visible_seconds, FireBursts.EMBER, -age)
	_fires.step(0.0)

## 実行時はRunPresentationから世界時間で更新。単独シーンのときだけ反復プレビューする。
func _process(dt: float) -> void:
	if rm == null: preview_step(0.0 if preview_paused else dt)

func preview_restart(age := 0.0) -> void:
	if is_instance_valid(_fires):
		remove_child(_fires)
		_fires.queue_free()
	_create_fires()
	_preview_age = age
	_preview_shape = Vector3(visible_seconds, pixel_scale, effect_scale)
	_spawn(Vector2.ZERO, 110.0, age)

func preview_step(dt: float) -> void:
	var shape := Vector3(visible_seconds, pixel_scale, effect_scale)
	if shape != _preview_shape:
		var phase := clampf(_preview_age / maxf(_preview_shape.x, 0.01), 0.0, 0.99)
		# 位置・半径・ドット幅を作り直し、停止中も同じ進行割合で表示する。
		preview_restart(phase * visible_seconds)
	_preview_age += dt
	_fires.step(dt)
	if _preview_age >= visible_seconds + 0.45: preview_restart()

func _exit_tree() -> void:
	if rm != null and is_instance_valid(_fires): _fires.queue_free()
