## 仮のボス戦艦（仕様書 10）。設計書 6.1 の3層で作る。
##   形態：LimboHSM（仮のボスは形態1つ）
##   判断：形態の BTState が持つ Behavior Tree（攻撃を出せるなら、攻撃の振り付けを再生する）
##   攻撃：AnimationPlayer のタイムライン「volley」（予告のあと fire_volley を呼ぶ）
## 移動（機体を直接追う）は形態に関係なく常に行う。LimboAI とタイムラインは世界の時間で進める。
extends BossActor

@onready var hsm: LimboHSM = $LimboHSM
@onready var timeline: AnimationPlayer = $Timeline

var _cooldown := 0.0

func _on_bound() -> void:
	_cooldown = float(def.params.fire_interval) * 0.5
	hsm.initialize(self)
	hsm.set_active(true)

func sim_tick(_real_dt: float, dt: float) -> void:
	if dt <= 0.0:
		return
	_move(dt)
	_cooldown -= dt
	hsm.update(dt)
	if timeline.is_playing():
		timeline.advance(dt)
		body.charge = timeline.current_animation_position / maxf(timeline.current_animation_length, 0.001)
	else:
		body.charge = 0.0

func _move(dt: float) -> void:
	var aim := run_state.enemy_aim
	var d := aim - body.pos
	var dist := maxf(d.length(), 1.0)
	body.vel += (d / dist * body.speed - body.vel) * minf(1.0, def.accel * dt)
	body.facing += clampf(Geom.angle_diff(d.angle(), body.facing), -def.turn * dt, def.turn * dt)
	var from := body.pos
	body.pos += body.vel * dt
	manager.field.collide_enemy(body, from)
	if body.hit_cd > 0.0:
		body.hit_cd -= dt
	if body.flash > 0.0:
		body.flash -= dt

# ── 判断の層から呼ばれる ──────────────────────────────────────────

func attack_ready(_attack: StringName) -> bool:
	return _cooldown <= 0.0 and not timeline.is_playing()

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
	var base := (run_state.enemy_aim - body.pos).angle()
	for i in n:
		manager.fire(base + (float(i) / (n - 1) - 0.5) * spread, def.params.bullet_speed, def.params)
