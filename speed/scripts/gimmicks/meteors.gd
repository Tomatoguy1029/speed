extends FieldGimmick
const Rock = FieldSystem.Rock
var _stream_t := 0.0

func initialize() -> void:
	_place_rocks(state.rng)

func tick(_real_dt: float, world_dt: float) -> void:
	if world_dt > 0.0:
		_stream_rocks(world_dt)

func _place_rocks(rng: RandomNumberGenerator) -> void:
	var n := cfg.meteor_count
	for i in roundi(n * 0.45):
		var center := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(1100.0, cfg.field_radius - 650.0)
		for j in 8:
			_add_rock(rng, center + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * 380.0, &"belt", Vector2.ZERO)
	for i in roundi(n * 2.5):
		var d := sqrt(rng.randf_range(800.0 * 800.0, pow(cfg.field_radius - 300.0, 2.0)))
		var heading := rng.randf() * TAU
		_add_rock(rng, Vector2.from_angle(rng.randf() * TAU) * d, &"drift", Vector2.from_angle(heading) * rng.randf_range(15.0, 35.0))
	# 鉄のがれきと回る丸鋸（置き方は仮：フィールドの全体に散らす）
	for i in cfg.iron_count:
		var center := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(1100.0, cfg.field_radius - 650.0)
		for j in rng.randi_range(3, 5):
			_add_rock(rng, center + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * 240.0, &"iron", Vector2.ZERO)
	for i in cfg.saw_count:
		var d := sqrt(rng.randf_range(900.0 * 900.0, pow(cfg.field_radius - 400.0, 2.0)))
		_add_rock(rng, Vector2.from_angle(rng.randf() * TAU) * d, &"saw", Vector2.ZERO)

func _add_rock(rng: RandomNumberGenerator, p: Vector2, kind: StringName, vel: Vector2) -> void:
	var r := p.length()
	if r < cfg.planet_radius + 200.0 or r > cfg.field_radius - 100.0:
		return
	var rock := Rock.new()
	rock.kind = kind
	rock.pos = p
	rock.vel = vel
	rock.size = rng.randf_range(24.0, 65.0)
	rock.facing = rng.randf() * TAU
	rock.spin = rng.randf_range(-0.5, 0.5)
	if kind == &"iron":
		rock.size = rng.randf_range(30.0, 50.0)
	elif kind == &"saw":
		rock.size = 30.0
		rock.spin = 8.0
	field.rocks.append(rock)

func _rock_at(rock: Rock, t: float) -> Array:
	if rock.kind == &"comet":
		return [rock.pos + rock.vel * (t - rock.born), rock.vel]
	var diameter := cfg.field_radius * 2.0
	var p := rock.pos + rock.vel * t
	p = Vector2(fposmod(p.x + cfg.field_radius, diameter) - cfg.field_radius, fposmod(p.y + cfg.field_radius, diameter) - cfg.field_radius)
	return [p, rock.vel]

func _near(p: Vector2, extra: float) -> bool:
	var d := (p - state.view_center).abs()
	var r := p.length()
	return d.x < state.view_half.x + extra and d.y < state.view_half.y + extra \
		and r > cfg.planet_radius + 100.0 and r < cfg.field_radius + 100.0

func _stream_rocks(dt: float) -> void:
	var t := state.world_time
	var table := enemies.table
	for rock in field.rocks:
		var i := rock.row
		if i < 0:
			continue
		# 撃破されて空きに戻った行は、別の敵に使い回されていることがある
		if not enemies.is_same(i, rock.row_id) or table.dead[i] != 0:
			if not enemies.is_same(i, rock.row_id) or table.hull_scattered[i] == 0:
				rock.destroyed = true
			rock.row = -1
			continue
		var pv := _rock_at(rock, t)
		table.pos[i] = pv[0]
		table.vel[i] = pv[1]
		table.facing[i] = rock.facing + rock.spin * t
		if rock.kind == &"comet" and t >= rock.gone:
			rock.destroyed = true
		if rock.destroyed or (not rock.lab_manual and not _near(pv[0], 650.0)):
			enemies.mark_dead(i)
			rock.row = -1
	_stream_t -= dt
	if _stream_t > 0.0:
		return
	_stream_t = 0.2
	var defs := {&"iron": enemies.def_of(&"iron"), &"saw": enemies.def_of(&"saw")}
	var meteor: EnemyDef = enemies.def_of(&"meteor")
	for k in field.rocks.size():
		var rock := field.rocks[k]
		if rock.destroyed or rock.row >= 0:
			continue
		if rock.kind == &"comet" and t >= rock.gone:
			rock.destroyed = true
			continue
		var pv := _rock_at(rock, t)
		if not rock.lab_manual and not _near(pv[0], 300.0):
			continue
		var def: EnemyDef = defs.get(rock.kind, meteor)
		var sprite_radius := rock.size if def != meteor or rock.kind == &"comet" else (60.0 if k % 2 == 0 else 40.0)
		var i := enemies.spawn(def, pv[0], {"size": sprite_radius, "facing": rock.facing, "spin": rock.spin,
			"meteor_index": k, "vel": pv[1]})
		rock.row = i
		rock.row_id = table.id[i]
		if rock.rare_weapon != &"":
			table.max_hp[i] *= cfg.rare_comet_hp_mult
			table.hp[i] = table.max_hp[i]
