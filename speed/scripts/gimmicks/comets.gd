extends FieldGimmick
const Rock = FieldSystem.Rock
var _comet_t := 0.0

func initialize() -> void:
	_comet_t = state.rng.randf_range(cfg.comet_interval_min, cfg.comet_interval_max)

func tick(_real_dt: float, world_dt: float) -> void:
	if world_dt > 0.0:
		_tick_comets(world_dt)

func _tick_comets(dt: float) -> void:
	_comet_t -= dt
	if _comet_t > 0.0:
		return
	_comet_t = state.rng.randf_range(cfg.comet_interval_min, cfg.comet_interval_max)
	if state.bonus_t <= 0.0 and not state.boss_spawned and field.warp_gone < 0.0 and state.time >= cfg.rare_comet_after \
			and state.rng.randf() < cfg.warp_chance:
		field.spawn_warp()
		return
	spawn_comet(state.time >= cfg.rare_comet_after and state.rng.randf() < cfg.rare_comet_chance)

func spawn_comet(rare: bool) -> void:
	var rng := state.rng
	var vc := state.view_center
	var vh := state.view_half
	var lead := vh.length() + 700.0
	for attempt in 12:
		var u := Vector2.from_angle(rng.randf() * TAU)
		var side := Vector2(-u.y, u.x) * (1.0 if rng.randf() < 0.5 else -1.0)
		var edge := absf(side.x) * vh.x + absf(side.y) * vh.y
		var start := vc - u * lead + side * edge * rng.randf_range(0.55, 0.9)
		var end := start + u * lead * 2.0
		if Geom.seg_circle_t(start, end, Vector2.ZERO, cfg.planet_radius + 150.0) >= 0.0 and attempt < 11:
			continue
		var r := Rock.new()
		r.kind = &"comet"
		r.pos = start
		r.vel = u * cfg.comet_speed
		r.born = state.world_time
		r.gone = state.world_time + lead * 2.0 / cfg.comet_speed
		r.size = rng.randf_range(35.0, 55.0)
		r.facing = u.angle()
		if rare:
			# まだ持っていない彗星限定の武器から選ぶ。すべて持っていれば普通の彗星にする
			var ids: Array = ContentManager.catalog.table(&"weapons").keys().filter(func(id):
				return ContentManager.catalog.find(&"weapons", id).comet_only and not state.weapons.has(id))
			if not ids.is_empty():
				r.rare_weapon = ids[rng.randi_range(0, ids.size() - 1)]
		field.rocks.append(r)
		field.gimmick(&"meteors")._stream_t = 0.0
		return

func comet_at(index: int) -> Rock:
	if index < 0 or index >= field.rocks.size() or field.rocks[index].kind != &"comet":
		return null
	return field.rocks[index]

func rare_comet_positions() -> PackedVector2Array:
	var out := PackedVector2Array()
	var t := state.world_time
	for rock in field.rocks:
		if rock.kind == &"comet" and rock.rare_weapon != &"" and not rock.destroyed and t < rock.gone:
			out.append(field.rock_at(rock, t)[0])
	return out

func comet_weapon(index: int) -> StringName:
	var c := comet_at(index)
	return c.rare_weapon if c != null else &""
