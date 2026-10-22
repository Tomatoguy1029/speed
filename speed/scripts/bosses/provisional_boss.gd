## 仮のボス戦艦（仕様書 12.2）。設計書 6.1 の3層で作る。
##   形態：LimboHSM（仮のボスは形態1つ）
##   判断：形態の BTState が持つ Behavior Tree（攻撃を出せるなら、攻撃の振り付けを再生する）
##   攻撃：AnimationPlayer のタイムライン「volley」（予告のあと fire_volley を呼ぶ）
## 移動（機体を直接追う）は形態に関係なく常に行う。LimboAI とタイムラインは世界の時間で進める。
extends BossActor

@onready var hsm: LimboHSM = $LimboHSM
@onready var timeline: AnimationPlayer = $Timeline

var _cooldown := 0.0
## 制限時間の一撃の経過時間（負なら使っていない。ランの時計で数える）、始めた時刻、溜めの長さ、光
var final_strike_t := -1.0
var _final_start := 0.0
var _final_charge := 1.0
var _final_beam: Line2D

func _on_bound() -> void:
	# 手動の固定更新中に技の処理を確定し、描画フレームへ持ち越さない。
	timeline.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
	_cooldown = float(def.params.fire_interval) * 0.5
	hsm.initialize(self)
	hsm.set_active(true)

func sim_tick(_real_dt: float, dt: float) -> void:
	if dt <= 0.0:
		return
	if final_strike_t >= 0.0:
		_final_strike_tick(dt)
		return
	_move(dt)
	_cooldown -= dt
	hsm.update(dt)
	if timeline.is_playing():
		timeline.advance(dt)
		table.charge[body] = timeline.current_animation_position / maxf(timeline.current_animation_length, 0.001)
	else:
		table.charge[body] = 0.0

func _move(dt: float) -> void:
	var t := table
	var i := body
	var aim := run_state.enemy_aim
	var from := t.pos[i]
	var d := aim - from
	var dist := maxf(d.length(), 1.0)
	t.vel[i] += (d / dist * t.speed[i] - t.vel[i]) * minf(1.0, def.accel * dt)
	t.facing[i] += clampf(Geom.angle_diff(d.angle(), t.facing[i]), -def.turn * dt, def.turn * dt)
	t.pos[i] += t.vel[i] * dt
	ctx.field.collide_enemy(i, from)
	if t.hit_cd[i] > 0.0:
		t.hit_cd[i] -= dt
	if t.flash[i] > 0.0:
		t.flash[i] -= dt

# ── 制限時間の一撃（仕様書 4.1・16） ─────────────────────────────────

## 攻撃と移動を止めて機体へ向き、光を溜める。溜め終わりに光が太くなって画面を埋める。
## 当たりの判定は RunSimulation が溜めの終わりに行う。溜めの間は無敵。
func begin_final_strike(charge: float) -> void:
	if final_strike_t >= 0.0:
		return
	final_strike_t = 0.0
	_final_start = run_state.time
	_final_charge = maxf(0.1, charge)
	hsm.set_active(false)
	timeline.stop()
	_final_beam = Line2D.new()
	_final_beam.top_level = true
	_final_beam.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	_final_beam.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_final_beam.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_final_beam.end_cap_mode = Line2D.LINE_CAP_ROUND
	var pixels := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	pixels.fill(Color.WHITE)
	_final_beam.texture = ImageTexture.create_from_image(pixels)
	_final_beam.material = ShaderMaterial.new()
	_final_beam.material.shader = preload("res://shaders/hydra_energy.gdshader")
	add_child(_final_beam)

func _final_strike_tick(dt: float) -> void:
	final_strike_t = run_state.time - _final_start
	var widen_time := float(def.params.final_widen_time)
	var widen := clampf((final_strike_t - (_final_charge - widen_time)) / widen_time, 0.0, 1.0)
	var t := table
	var i := body
	var d := run_state.ship_pos - t.pos[i]
	t.vel[i] = Vector2.ZERO
	t.facing[i] += clampf(Geom.angle_diff(d.angle(), t.facing[i]), -def.turn * dt, def.turn * dt)
	t.guard[i] = 1.0
	t.charge[i] = clampf(final_strike_t / _final_charge, 0.0, 1.0)
	var points := PackedVector2Array([t.pos[i], t.pos[i] + d.normalized() * float(def.params.final_reach)])
	var width := lerpf(float(def.params.final_warn_width), float(def.params.final_beam_width), widen * widen)
	_final_beam.points = points
	_final_beam.width = width
	var mat := _final_beam.material as ShaderMaterial
	mat.set_shader_parameter("tint", Color(1, 0.25, 0.4))
	mat.set_shader_parameter("clock", run_state.time)
	mat.set_shader_parameter("warning", final_strike_t < _final_charge - widen_time)
	mat.set_shader_parameter("span", points[0].distance_to(points[1]))
	mat.set_shader_parameter("thickness", width)

func _process(delta: float) -> void:
	super(delta)
	# 一撃が当たったら、敗北の停止の間に光を消し、爆発と GAME OVER を見せる。
	if _final_beam != null and run_state.phase != RunState.Phase.PLAY:
		_final_beam.modulate.a = move_toward(_final_beam.modulate.a, 0.0, delta / maxf(0.01, ctx.cfg.death_freeze_time))

# ── 判断の層から呼ばれる ──────────────────────────────────────────

func attack_ready(_attack: StringName) -> bool:
	return _cooldown <= 0.0 and not timeline.is_playing() and ctx.bosses.admit("boss:" + str(table.id[body]), ["aimed"], body, 2.0)

func start_attack(attack: StringName) -> void:
	timeline.play(attack)
	timeline.advance(0.0)

func attack_playing() -> bool:
	return timeline.is_playing()

# ── タイムラインから呼ばれる ──────────────────────────────────────

## 扇状に弾を撃つ（予告の終わりに、タイムラインのメソッドトラックが呼ぶ）。
func fire_volley() -> void:
	_cooldown = def.params.fire_interval
	var n: int = def.params.volley
	var spread: float = def.params.spread
	var base := (run_state.enemy_aim - table.pos[body]).angle()
	for i in n:
		ctx.projectiles.fire_enemy(body, base + (float(i) / maxi(1, n - 1) - 0.5) * spread, def.params.bullet_speed, &"bullet", def.params)
