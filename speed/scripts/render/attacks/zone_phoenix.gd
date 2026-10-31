## ほうおう座の着地の炎。判定の寿命と独立した、ドット単位の爆発で描く。表示時間は爆発の調整値から決まる。
## 着地前の影・予告の輪・降る火の粉は、敵の表示（render/enemies/phoenix.gd）が描く。
extends AttackVisual
const KEY := "enemy/phoenix"
const BLAST_BURSTS := preload("res://scripts/render/fx/blast_bursts.gd")
const TUNED_SHADERS := [preload("res://shaders/blast_burst.gdshader")]
var _blasts: BlastBursts
var _seen: Dictionary = {}
var _world_time := 0.0

func setup(render: RunPresentation) -> void:
	super.setup(render)
	_world_time = state.world_time
	_blasts = BLAST_BURSTS.new()
	_blasts.key = KEY
	_blasts.setup(1.82 * rm.cfg.character_scale)
	_blasts.visibility_layer = 1 | RenderPipeline.GLOW_LAYER
	_blasts.modulate = RenderPipeline.plain_color(rm._layers.fx)
	rm._layers.fx.add_child(_blasts)

func update(_dt: float) -> void:
	var now := state.world_time
	_blasts.step(maxf(0.0, now - _world_time))
	_world_time = now
	var pr := rm.run.projectiles
	for row in _seen.keys():
		if row >= pr.hazard_alive.size() or pr.hazard_alive[row] == 0 or not is_same(_seen[row], pr.hazard_enemy_hit[row]):
			_seen.erase(row)

func draw_hazard(_c: CanvasItem, pr: ProjectileSystem, i: int, view: Rect2) -> void:
	rm._visual_for_type(&"phoenix")
	if pr.hazard_t[i] < pr.hazard_delay[i]: return
	# spawnごとに新しくなる命中辞書の参照で、行番号再利用と同じ炎の再描画を区別する。
	if is_same(_seen.get(i), pr.hazard_enemy_hit[i]): return
	if not view.grow(pr.hazard_len[i] * 1.2).has_point(pr.hazard_pos[i]): return
	_seen[i] = pr.hazard_enemy_hit[i]
	_blasts.add(pr.hazard_pos[i], pr.hazard_len[i] / _blasts.px, pr.hazard_delay[i] - pr.hazard_t[i])
	_blasts.step(0.0)

func _exit_tree() -> void:
	if is_instance_valid(_blasts): _blasts.queue_free()
