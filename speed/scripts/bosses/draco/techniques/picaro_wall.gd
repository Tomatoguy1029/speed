## ピカロ隊列と光の矢の値と動き。
@tool
extends BossTechnique

## 予告（秒）
@export_range(0,100000,0.01) var warn := 1.0
## 攻撃の継続時間
@export_range(0,100000,0.01) var active := 6.0
## 攻撃後の待ち
@export_range(0,100000,0.01) var recover := 1.2
## ダメージ
@export_range(0,100000,0.01) var damage := 28.0
## 隊列に使う敵
@export var wall_candidates: Array[StringName] = []
## 弾数
@export_range(0,100000,1) var count := 3
## 矢の数
@export_range(0,100000,1) var arrows := 5
## 矢の間隔（秒）
@export_range(0,100000,0.01) var interval := 0.45
## 飛行時間
@export_range(0,100000,0.01) var flight := 0.75
## 着弾の予告
@export_range(0,100000,0.01) var impact_warn := 1.0
## 半径
@export_range(0,100000,0.01) var radius := 85.0

func make_runner() -> RefCounted:
	return Runner.new()

class Runner extends BossTechnique.Runner:
	const ARROW = preload("res://scripts/attacks/cosmic_arrow.gd")
	const ARROW_VISUAL = preload("res://scripts/render/attacks/cosmic_arrow.gd")
	var shots := 0
	var impacts: Array = []
	func begin(a: BossActor) -> void:
		a.picaro.attacking = true
		var choices: Array = a.rule().get("wall_candidates", [&"telescope", &"lynx"])
		if choices.is_empty(): choices = [&"lynx"]
		var target: Vector2 = a.aim_target()
		var forward: Vector2 = (target - a.table.pos[a.body]).normalized()
		if forward.is_zero_approx(): forward = Vector2.RIGHT
		for j in int(a.rule().count):
			var side := float(j) - float(int(a.rule().count) - 1) * 0.5
			var position: Vector2 = a.table.pos[a.body].lerp(target, 0.45) + forward.orthogonal() * side * 180.0
			a.picaro.spawn_picaro(StringName(choices[j % choices.size()]), position)
	func tick(a: BossActor, dt: float) -> void:
		if shots < int(a.rule().arrows) and a.elapsed >= shots * float(a.rule().interval):
			var from: Vector2 = a.table.pos[a.body] + Vector2.from_angle(a.table.facing[a.body]) * 100.0 * a.head_scale
			a.ctx.projectiles.emit_attack(&"cosmic_arrow", [from, -PI * 0.5, 900.0, 12.0, maxf(1000.0, a.run_state.view_half.y * 2.5), 0.0, true])
			var top: float = a.run_state.view_center.y - a.run_state.view_half.y
			var leave_screen: float = maxf(0.0, from.y - top + 80.0) / 900.0
			impacts.append({"wait":maxf(float(a.rule().flight), leave_screen + 0.15), "warn":float(a.rule().impact_warn), "pos":Vector2.INF, "age":0.0})
			shots += 1
		for impact: Dictionary in impacts.duplicate():
			impact.age = float(impact.age) + dt
			if impact.pos == Vector2.INF and float(impact.age) >= float(impact.wait):
				impact.pos = a.aim_target()
				a.combat_trace.stage("lock", {"scope": "arrow_impact", "aim": [impact.pos.x, impact.pos.y]})
				a.presentation_event.emit({"cue":&"target_locked", "pos":impact.pos, "radius":a.rule().radius})
			if impact.pos != Vector2.INF and float(impact.age) >= float(impact.wait) + float(impact.warn):
				a.ctx.projectiles.fire_zone(impact.pos, float(a.rule().radius), 0.0, float(a.rule().damage) * a.ctx.cfg.atk_scale, ProjectileSystem.HazardStyle.BLAST, Color("#b7a3ff"))
				a.presentation_event.emit({"cue":&"arrow_impact", "pos":impact.pos, "radius":a.rule().radius})
				impacts.erase(impact)
	func end(a: BossActor, cancelled: bool) -> void:
		impacts.clear()
		a.picaro.pause(cancelled)

	func pose(a: BossActor) -> void:
		a.mouth_open = (1.35 if a.technique == &"inhale" else 1.0) if a.mode == &"active" else 0.8 if a.mode == &"windup" else 0.0
