## 導入の星・練習相手・見本線。線との一致や失敗回数は判定しない。
extends RefCounted

var run: RunSimulation
var presentation: IntroPresentation
var stars := PackedVector2Array()
## 敵の ID → {row, star}。行が解放されても撃破イベントを照合できる。
var enemies: Dictionary = {}
var released: Array[Dictionary] = []
var guide_points := PackedVector2Array()

func setup(simulation: RunSimulation, visuals: IntroPresentation, origin: Vector2) -> void:
	run = simulation
	presentation = visuals
	var arrival: Vector2 = origin + Vector2(32, 0) * presentation.flight_time
	for offset: Vector2 in presentation.practice_offsets:
		stars.append(arrival + offset + Vector2(80, 0))

func spawn() -> void:
	for star in stars:
		var row: int = run.enemies.spawn(presentation.practice_enemy, star,
			{"facing": (run.state.ship_pos - star).angle()})
		var id: int = run.enemies.table.id[row]
		enemies[id] = {"row": row, "star": star}

func approach(progress: float) -> void:
	var i := 0
	for record: Dictionary in enemies.values():
		var target: Vector2 = run.state.ship_pos + presentation.practice_offsets[i]
		run.enemies.table.pos[record.row] = record.star.lerp(target, progress)
		i += 1

func update() -> void:
	var state: RunState = run.state
	for record: Dictionary in enemies.values():
		var row: int = record.row
		if run.enemies.table.pos[row].distance_to(state.ship_pos) > 950.0:
			run.enemies.table.pos[row] = state.ship_pos + state.ship_heading * 700.0
	if not state.drawing and not state.tracing:
		build_guide()

func build_guide() -> void:
	var points := PackedVector2Array([run.state.ship_pos + Vector2(80, -20)])
	for record: Dictionary in enemies.values():
		points.append(run.enemies.table.pos[record.row])
	if points.size() < 2:
		guide_points.clear()
		return
	points.append(points[-1] + Vector2(85, 35))
	guide_points.clear()
	# 各敵の中心を通る、緩く折れたお手本。プレイヤーの実際の線とは独立する。
	for i in points.size() - 1:
		var a := points[maxi(0, i - 1)]
		var b := points[i]
		var c := points[i + 1]
		var d := points[mini(points.size() - 1, i + 2)]
		for step in 8:
			var t := float(step) / 8.0
			guide_points.append(0.5 * ((2.0 * b) + (-a + c) * t
				+ (2.0 * a - 5.0 * b + 4.0 * c - d) * t * t
				+ (-a + 3.0 * b - 3.0 * c + d) * t * t * t))
	guide_points.append(points[-1])

func record_kill(event: Dictionary) -> bool:
	var id := int(event.get("id", -1))
	if not enemies.has(id):
		return false
	released.append({"from": event.pos, "to": enemies[id].star})
	enemies.erase(id)
	return true

func dispose() -> void:
	run = null
	presentation = null
