## Opt-in combat observations. No game state, RNG, or presentation queue is modified.
## Runtime data only; bounded event serialization belongs to the existing recorder.
extends RefCounted
signal recorded(event: Dictionary)
var level := 0
var max_per_second := 120
var max_events := 30000
var emitted := 0
var dropped := 0
var generation := 0
var serial := 0
var run_id := "%d-%d" % [Time.get_ticks_usec(), get_instance_id()]
var _window := -1
var _count := 0
var state: RunState

func configure(value: int, per_second := 120, total := 30000) -> void:
	level = clampi(value, 0, 2) if OS.is_debug_build() else 0
	max_per_second = clampi(per_second, 1, 1000)
	max_events = clampi(total, 1, 1000000)
	emitted = 0
	dropped = 0
	_count = 0
	_window = -1
	generation += 1

func enabled(detail := 1) -> bool:
	return level >= detail and recorded.has_connections()

func next_id() -> int:
	serial += 1
	return serial

func _reserve(detail := 1) -> bool:
	if not enabled(detail): return false
	var window := int(Time.get_ticks_msec() / 1000)
	if _window != window:
		_window = window
		_count = 0
	if _count >= max_per_second or emitted >= max_events:
		dropped += 1
		return false
	_count += 1
	emitted += 1
	return true

func record(kind: String, data: Dictionary, detail := 1) -> void:
	if _reserve(detail): _publish(kind, data)

func _publish(kind: String, data: Dictionary) -> void:
	var row := data.duplicate()
	row.merge({"type": kind, "combat_version": 1, "run_id": run_id, "stage": state.stage_index,
		"t": state.time, "world_t": state.world_time, "sequence": emitted}, true)
	recorded.emit(row)

func player_damage(amount: float, cause: StringName, source: StringName, reason: String, hp_before: float, context: Dictionary) -> void:
	if not _reserve(): return
	var row := context.duplicate()
	row.merge({"target": "player", "cause": String(cause), "source": String(source), "reason": reason,
		"requested": amount, "applied": maxf(0.0, hp_before - maxf(0.0, state.ship_hp)),
		"hp_before": hp_before, "hp_after": state.ship_hp, "player_pos": point(state.ship_pos)}, true)
	_publish("combat_damage", row)

static func point(value: Vector2) -> Array:
	return [value.x, value.y]
