## 導入の星・練習相手・見本線。線との一致や失敗回数は判定しない。
extends RefCounted

var run: RefCounted
var sequence: RefCounted
var presentation: IntroPresentation
var stars := PackedVector2Array()
## 敵の ID → {row, star}。行が解放されても撃破イベントを照合できる。
var enemies: Dictionary = {}
var released: Array[Dictionary] = []
var guide_points := PackedVector2Array()

func setup(owner: RefCounted, visuals: IntroPresentation, origin: Vector2) -> void:
	sequence = owner
	run = owner.run
	presentation = visuals
	var arrival: Vector2 = origin + Vector2(32, 0) * presentation.flight_time
	for offset: Vector2 in presentation.practice_offsets:
		stars.append(arrival + offset + Vector2(80, 0))

func relocate(origin: Vector2) -> void:
	stars.clear()
	for offset: Vector2 in presentation.practice_offsets: stars.append(origin+offset+Vector2(80,0))

func spawn() -> void:
	for star in stars:
		var result: Dictionary = sequence.command("dev_spawn",{"definition_id":String(presentation.practice_enemy.id),"position":star,"facing":(run.state.ship_pos-star).angle()})
		if not result.ok: return
		enemies[int(result.value)] = {"row":row_for_id(int(result.value)),"star":star}

func row_for_id(id: int) -> int:
	return run.enemies.table.id.find(id)

func approach(progress: float) -> void:
	var i := 0
	for id in enemies:
		var record: Dictionary = enemies[id]
		var target: Vector2 = run.state.ship_pos + presentation.practice_offsets[i]
		sequence.command("dev_edit",{"kind":"move","payload":{"entity_id":int(id),"position":record.star.lerp(target,progress)}})
		i += 1

func update() -> void:
	for id in enemies:
		var row := row_for_id(int(id))
		if row<0: continue
		var distant: bool = run.enemies.table.pos[row].distance_to(run.state.ship_pos)>950.0
		var speed: float = maxf(presentation.practice_enemy.speed,run.state.stats.max_speed*0.9) if distant else presentation.practice_enemy.speed
		sequence.command("dev_edit",{"kind":"enemy_motion","payload":{"entity_id":int(id),"speed":speed}})
	if not run.state.drawing and not run.state.tracing: build_guide()

func build_guide() -> void:
	var points := PackedVector2Array([run.state.ship_pos + Vector2(80, -20)])
	for id in enemies:
		var row := row_for_id(int(id))
		if row>=0: points.append(run.enemies.table.pos[row])
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
	sequence = null
	presentation = null
