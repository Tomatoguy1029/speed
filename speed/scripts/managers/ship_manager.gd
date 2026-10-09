## 機体の移動・速さの減り方・地形との衝突・被弾（仕様書 5・7.2）。
##
## なぞり中（state.tracing）は DrawManager が機体を動かすので、ここでは動かさない。
class_name ShipManager
extends RunSystem

var field: FieldManager
var combat: CombatManager
var build: BuildManager

## RunManager が更新ごとに入れる入力の意図
var intent: Intent = Intent.new()
## 調整パネルの「無敵」
var invincible := false

func setup(run_state: RunState, config: GameConfig) -> void:
	super(run_state, config)
	state.ship_pos = Vector2(-cfg.start_radius, 0.0)
	state.ship_vel = Vector2(0.0, -cfg.base_max_speed * 0.3)
	state.ship_hp = state.stats.max_hp
	state.ship_heading = Vector2.UP

func tick(real_dt: float, world_dt: float) -> void:
	if state.ship_hurt > 0.0:
		state.ship_hurt -= real_dt
	if state.ship_invuln > 0.0:
		state.ship_invuln -= world_dt
	if state.tracing or state.drawing:
		return
	if world_dt <= 0.0:
		return
	_steer(world_dt)
	var from := state.ship_pos
	var drag := field.dust_drag_at(from)
	_step(world_dt, field.boundary_accel(from), drag)
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
		var k := clampf((intent.stick.length() - cfg.stick_dead_zone) / maxf(1.0, cfg.stick_radius - cfg.stick_dead_zone), 0.0, 1.0)
		_steer_toward(intent.stick.angle(), dt, lerpf(cfg.steer_cruise, cfg.stick_cruise_max, k))
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
		var turn := clampf(Geom.angle_diff(want, cur), -cfg.steer_rate * dt, cfg.steer_rate * dt)
		state.ship_vel = state.ship_vel.rotated(turn)
	var cruise := state.stats.max_speed * cruise_share
	if sp < cruise:
		state.ship_vel += Vector2.from_angle(want) * minf(cfg.steer_accel * dt, cruise - sp)
	if state.ship_vel.is_zero_approx():
		state.ship_heading = Vector2.from_angle(want)

# ── 速さの減り方（仕様書 5.2・6.6） ───────────────────────────────

func _step(dt: float, accel: Vector2, extra_drag: float) -> void:
	if state.glide:
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
		if extra_drag > 0.0:
			target *= exp(-extra_drag * dt)
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
			var dmg := maxf(0.0, -vn - 200.0) * cfg.crash_damage
			if dmg > 0.0:
				damage(dmg, 0.0, &"planet" if b.is_planet else &"moon")
			if state.phase != RunState.Phase.PLAY:
				return
			state.emit(&"crash", {"pos": state.ship_pos, "power": -vn})
	var r := state.ship_pos.length()
	var wall := cfg.field_radius + 500.0
	if r > wall:
		state.glide = false
		var n := state.ship_pos / r
		state.ship_pos = n * wall
		var vn := state.ship_vel.dot(n)
		if vn > 0.0:
			state.ship_vel -= n * 2.0 * vn

# ── 被弾（仕様書 5・7.2） ─────────────────────────────────────────

## HP を amount 減らし、速さを slow の割合だけ落とす。無敵中なら何もしない。
func damage(amount: float, slow: float, cause: StringName) -> bool:
	if state.phase != RunState.Phase.PLAY or state.ship_invuln > 0.0 or invincible:
		return false
	state.ship_hp -= amount
	if slow > 0.0:
		state.glide = false
	state.ship_vel *= 1.0 - minf(0.9, slow)
	state.ship_invuln = cfg.invuln_time
	state.ship_hurt = cfg.ship_hurt_time
	state.emit(&"hurt", {"pos": state.ship_pos, "amount": amount, "cause": cause})
	if state.ship_hp > 0.0:
		build.on_hurt()
	return true

func heal(amount: float) -> void:
	state.ship_hp = minf(state.stats.max_hp, state.ship_hp + amount)
