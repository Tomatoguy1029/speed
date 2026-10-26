## 機体の移動・速さの減り方・地形との衝突・被弾（仕様書 5・7.2）。
##
## なぞり中（state.tracing）は DrawSystem が機体を動かすので、ここでは動かさない。
class_name ShipSystem
extends RunSystem

## 記録中だけ購読する実被弾。表示待ちのフレームをまたぐ前に通知する。
signal hurt_recorded(hit: Dictionary)

var field: FieldSystem:
	get: return ctx.field
var combat: CombatSystem:
	get: return ctx.combat
var build: LoadoutSystem:
	get: return ctx.loadout

## RunManager が更新ごとに入れる入力の意図
var intent: Intent = Intent.new()
## 調整パネルの「無敵」
var invincible := false

func setup(context: RunContext) -> void:
	super(context)
	state.ship_pos = Vector2(-cfg.start_radius, 0.0)
	state.ship_vel = Vector2(0.0, -cfg.base_max_speed * 0.3)
	state.ship_hp = state.stats.max_hp
	state.ship_heading = Vector2.UP

func tick(real_dt: float, world_dt: float) -> void:
	if state.ship_hurt > 0.0:
		state.ship_hurt -= real_dt
	if state.ship_invuln > 0.0:
		state.ship_invuln -= world_dt
	state.ship_shield_flash = maxf(0.0, state.ship_shield_flash - world_dt)
	if state.ship_shield_t > 0.0:
		state.ship_shield_t = maxf(0.0, state.ship_shield_t - world_dt)
		if state.ship_shield_t <= 0.0:
			state.emit(&"shield_expired", {"pos": state.ship_pos})
	if state.tracing or state.drawing:
		return
	if world_dt <= 0.0:
		return
	_steer(world_dt)
	var from := state.ship_pos
	_step(world_dt, field.boundary_accel(from))
	combat.wall_bounce(from)
	combat.collide_ship(from, cfg.ship_radius, null)
	if state.phase != RunState.Phase.PLAY:
		return
	_collide_bodies()
	if not state.ship_vel.is_zero_approx():
		state.ship_heading = state.ship_vel.normalized()
	state.peak_speed = maxf(state.peak_speed, state.ship_vel.length())

# ── 操舵（仕様書 5.1） ────────────────────────────────────────────

func _steer(dt: float) -> void:
	if intent.touch:
		if not intent.stick_active or intent.stick.length() < cfg.stick_dead_zone:
			return
		# スティックは向きだけを決める（倒し具合で速さは変えない）
		_steer_toward(intent.stick.angle(), dt, cfg.steer_cruise)
		return
	if not intent.has_cursor:
		return
	var d := intent.cursor - state.ship_pos
	if d.length_squared() < cfg.mouse_dead_zone * cfg.mouse_dead_zone:
		return
	_steer_toward(d.angle(), dt, cfg.steer_cruise)

## 進む向きを want へ毎秒 steer_rate で回す（速さは保つ）。巡航速度より遅ければ want へ加速する。
func _steer_toward(want: float, dt: float, cruise_share: float) -> void:
	var sp := state.ship_vel.length()
	if sp > 1.0:
		var cur := state.ship_vel.angle()
		var turn := clampf(Geom.angle_diff(want, cur), -state.stats.turn_rate * dt, state.stats.turn_rate * dt)
		state.ship_vel = state.ship_vel.rotated(turn)
	var cruise := state.stats.max_speed * cruise_share
	if sp < cruise:
		state.ship_vel += Vector2.from_angle(want) * minf(state.stats.acceleration * dt, cruise - sp)
	if state.ship_vel.is_zero_approx():
		state.ship_heading = Vector2.from_angle(want)

# ── 速さの減り方（仕様書 5.2・6.6） ───────────────────────────────

func _step(dt: float, accel: Vector2) -> void:
	if state.glide:
		# 勢い：glide_hold の間は速さを保ち、そのあと glide_fade かけて巡航の速さまで落として終える（仕様書 6.6）
		state.glide_t += dt
		var cruise := state.stats.max_speed * cfg.steer_cruise
		var sp := state.glide_speed
		var hold := cfg.glide_hold * state.stats.glide_duration_mult
		var fade := cfg.glide_fade * state.stats.glide_duration_mult
		if state.glide_t > hold:
			var k := (state.glide_t - hold) / maxf(0.001, fade)
			if k >= 1.0:
				state.glide = false
				sp = cruise
			else:
				sp = lerpf(state.glide_speed, cruise, k)
		if not state.ship_vel.is_zero_approx():
			state.ship_vel = state.ship_vel.normalized() * sp
		state.ship_boost_t = maxf(0.0, state.ship_boost_t - dt)
		state.ship_fade_t = 0.0
		state.ship_pos += state.ship_vel * dt
		return
	state.ship_vel += accel * dt
	var sp := state.ship_vel.length()
	if sp > 0.0:
		var max_speed := state.stats.max_speed
		var target := sp
		if state.ship_boost_t > 0.0:
			state.ship_boost_t -= dt
			if state.ship_boost_t <= 0.0:
				state.ship_fade_t = 0.3
		else:
			if state.ship_fade_t > 0.0:
				state.ship_fade_t -= dt
				if target > max_speed * cfg.cruise_floor:
					target *= pow(cfg.energy_cut, dt / 0.3)
			var floor_speed := max_speed * cfg.cruise_floor
			if target > floor_speed:
				target = floor_speed + (target - floor_speed) * exp(-cfg.cruise_drag * dt)
		if target > max_speed:
			target = max_speed + (target - max_speed) * exp(-cfg.overcap_decay * dt)
		state.ship_vel *= target / sp
	state.ship_pos += state.ship_vel * dt
	if not state.ship_vel.is_zero_approx():
		state.ship_heading = state.ship_vel.normalized()

# ── 地形との衝突（仕様書 7.2） ────────────────────────────────────

func _collide_bodies() -> void:
	var R := cfg.ship_radius
	for b in field.bodies:
		var d := state.ship_pos - b.pos
		var dist := d.length()
		var min_d := b.r + R
		if dist >= min_d or dist == 0.0:
			continue
		var n := d / dist
		state.ship_pos = b.pos + n * min_d
		var vn := state.ship_vel.dot(n)
		if vn < 0.0:
			state.glide = false
			state.ship_vel -= n * vn * (1.0 + cfg.crash_restitution)
			state.emit(&"crash", {"pos": state.ship_pos, "power": -vn})
	# 天体からの押し出しが固定外周を越えた場合も、機体を内側に保つ。
	for bounds: Rect2 in field.battle_arenas.values():
		var safe := bounds.grow(-R)
		var inside := state.ship_pos.clamp(safe.position,safe.end)
		if inside != state.ship_pos:
			var inward := (inside-state.ship_pos).normalized()
			state.ship_pos = inside
			var vn := state.ship_vel.dot(inward)
			if vn < 0.0: state.ship_vel -= inward*vn*(1.0+cfg.crash_restitution)
			state.glide = false
	var r := state.ship_pos.length()
	var wall := cfg.field_radius + 500.0
	if r > wall and field.battle_arenas.is_empty():
		state.glide = false
		var n := state.ship_pos / r
		state.ship_pos = n * wall
		var vn := state.ship_vel.dot(n)
		if vn > 0.0:
			state.ship_vel -= n * 2.0 * vn

# ── 被弾（仕様書 5・7.2） ─────────────────────────────────────────

## 背後から貫いたたて座の盾を装備する。取り直したときは持続時間を更新する。
func steal_shield(i: int) -> void:
	var t := combat.enemies.table
	var duration := maxf(0.0, float(t.def[i].params.shield_time))
	state.ship_shield_t = duration
	state.ship_shield_max = duration
	state.ship_shield_flash = 0.2
	state.emit(&"shield_stolen", {"pos": t.pos[i], "facing": t.facing[i], "r": t.r[i],
		"arc": float(t.def[i].params.front_arc)})

## HP を amount 減らし、速さを slow の割合だけ落とす。無敵中なら何もしない。
## source は攻撃した敵の種類（分かるときだけ。プレイの記録が読む）。
func damage(amount: float, slow: float, cause: StringName, source := &"") -> bool:
	# 最終勝利が通知されたフレームの残りの接触・弾でも HP を減らさない。
	if state.phase != RunState.Phase.PLAY or state.boss_dead or state.controls_locked or state.encounter_protected:
		return false
	if state.ship_shield_t > 0.0:
		if state.ship_shield_flash <= 0.0:
			state.emit(&"shield_block", {"pos": state.ship_pos})
		state.ship_shield_flash = 0.12
		return false
	if state.ship_invuln > 0.0 or invincible:
		return false
	state.ship_hp -= amount
	if slow > 0.0:
		state.glide = false
	state.ship_vel *= 1.0 - minf(0.9, slow)
	state.ship_invuln = state.stats.invulnerability
	state.ship_hurt = cfg.ship_hurt_time
	var hit := {"pos": state.ship_pos, "amount": amount, "cause": cause, "source": source,
		"t": state.time, "world_t": state.world_time, "hp_after": state.ship_hp}
	state.emit(&"hurt", hit)
	if OS.is_debug_build() and hurt_recorded.has_connections(): hurt_recorded.emit(hit)
	if state.ship_hp > 0.0:
		build.on_hurt()
	return true

func heal(amount: float) -> void:
	state.ship_hp = minf(state.stats.max_hp, state.ship_hp + amount)
