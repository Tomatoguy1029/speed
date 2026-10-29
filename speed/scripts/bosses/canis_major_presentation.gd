## Asepriteから書き出したパーツの大型の猟犬。攻撃の向き・時間は役者から読み、演出だけを差し替える。
extends Node2D
@export var pixel_size := 3.0
@onready var parts: Node2D = $Parts
var actor: CanisMajorBoss
var hit := 0.0
var pulse := 0.0
var gait := 0.0
const SIRIUS := Color("#e8f6ff")
const WARNING := Color("#f2b567")
const DANGER := Color("#ff667d")
const OPEN := Color("#9fe8ff")
## 号令で飛び出している猟犬の軌跡に残す位置の数
const LUNGE_TRAIL := 6
## 号令で飛び出している猟犬の光と軌跡を描く層。本体の回転に付いていかないよう、ワールド座標で描く。
func bind_canis_major(owner_actor: CanisMajorBoss) -> void:
	actor = owner_actor
	actor.presentation_event.connect(_event)
	actor.presentation_advanced.connect(_advance)
	z_index = 1
	_sync_parts()

func _event(event: Dictionary) -> void:
	if event.cue == &"hit": hit = 0.18
	if event.cue in [&"aim_locked", &"pounce", &"command", &"sirius", &"phase_changed", &"howl"]: pulse = 0.35
	queue_redraw()

func _advance(dt: float) -> void:
	hit = maxf(0.0, hit - dt)
	pulse = maxf(0.0, pulse - dt)
	gait += dt * (18.0 if actor.mode == &"active" else 9.0)
	_sync_parts()
	queue_redraw()

func _sync_parts() -> void:
	parts.visible = actor != null and actor.has_body()
	if not parts.visible: return
	var k := actor.table.r[actor.body] / 100.0
	var crouch: float = actor.technique_pose.get("crouch", 0.0)
	var stretch: float = actor.technique_pose.get("stretch", 1.0)
	parts.scale = Vector2(k * (1.0 + crouch * 0.15), k * stretch)
	var moving := actor.table.vel[actor.body].length() > 5.0
	var legs := ["RearLeftLeg", "RearRightLeg", "FrontLeftLeg", "FrontRightLeg"]
	for i in legs.size():
		var leg := parts.get_node(legs[i]) as Node2D
		leg.rotation = sin(gait + (0.0 if i == 0 or i == 3 else PI)) * (0.16 if moving else 0.015)
	parts.get_node("Tail").rotation = sin(gait * 0.4) * 0.07

## シリウスの輝きの強さ（0〜1）。第2形態への移行の間に強め、そのあとは強いまま。
func blaze() -> float:
	if actor.phase < 2: return 0.0
	if actor.mode != &"phase": return 1.0
	var f := 1.0 - actor.phase_time / maxf(float(actor.def.params.phase_time), 0.001)
	return 1.0 - pow(1.0 - clampf(f, 0.0, 1.0), 3.0)

func _draw() -> void:
	if actor == null or not actor.has_body(): return
	var r := actor.table.r[actor.body]
	var k := r / 100.0
	var charge := actor.table.charge[actor.body]
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * k)
	modulate = Color(1.6, 1.6, 1.6) if hit > 0.0 else Color.WHITE
	var stretch: float = actor.technique_pose.get("stretch", 1.0)
	# 口元のシリウス。号令の構えでは強く瞬き、輪を広げる。
	var mouth := Vector2(99 * stretch, 0)
	var shout: bool = actor.technique_pose.get("shout", false)
	var howl: bool = actor.technique_pose.get("howl", false)
	var gather: bool = actor.technique_pose.get("gather", false)
	var strong := blaze()
	var glow := 6.0 + 6.0 * strong + (8.0 * charge if shout else 18.0 * charge if gather else (1.5 + 2.0 * strong) * sin(actor.clock * 5.0))
	# 第2形態では、口元のまわりに大きな光の暈と十字の光芒を足す。
	if strong > 0.0:
		var flare := (1.0 + 0.15 * sin(actor.clock * 9.0)) * strong
		draw_circle(mouth, glow + 18.0 * flare, Color(OPEN, 0.18))
		for ray in 4:
			var u := Vector2.from_angle(ray * PI / 2.0 + actor.clock * 0.6) * (glow + 34.0 * flare)
			draw_line(mouth - u, mouth + u, Color(SIRIUS, 0.55 * strong), pixel_size)
	draw_circle(mouth, glow + 4.0, Color(OPEN, 0.35))
	draw_circle(mouth, glow, SIRIUS)
	# 移行の間は、口元から光の輪を広げる。
	if actor.mode == &"phase":
		for ring in 2:
			var grow := fmod(strong * 1.5 + ring * 0.5, 1.0)
			draw_arc(mouth, 20.0 + grow * 140.0, 0.0, TAU, 32, Color(SIRIUS, 0.9 * (1.0 - grow)), pixel_size * 2.0)
	if actor.mode == &"recovery":
		var a := 0.45 + sin(actor.clock * 14.0) * 0.25
		draw_arc(Vector2(-6, 0), 106.0, 0.0, TAU, 32, Color(OPEN, a), pixel_size * 2.0)
	if pulse > 0.0:
		draw_arc(mouth, 24.0 + (0.35 - pulse) * 120.0, 0.0, TAU, 24, Color(SIRIUS, pulse * 2.4), pixel_size)
	draw_set_transform(Vector2.ZERO)
