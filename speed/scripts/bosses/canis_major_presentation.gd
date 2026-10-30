## Asepriteから書き出したパーツの大型の猟犬。攻撃の向き・時間は役者から読み、演出だけを差し替える。
extends Node2D
const EFFECT_SETTINGS := preload("res://data/visuals/effect_settings.tres")
@export var pixel_size := 3.0
@export var sirius_color := Color("#e8f6ff")
@export var sirius_halo_color := Color("#9fe8ff")
@export var sirius_glow_scale := 1.0
@onready var parts: Node2D = $Parts
var actor: CanisMajorBoss
var hit := 0.0
var pulse := 0.0
var gait := 0.0
const WARNING := Color("#f2b567")
const DANGER := Color("#ff667d")
func _ready() -> void:
	EFFECT_SETTINGS.apply_key(self, "boss/body/canis_major")
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
	if event.cue in [&"aim_locked", &"pounce", &"command", &"sirius", &"phase_changed", &"howl", &"call", &"called", &"stream_windup", &"bay_windup", &"entrance_bark"]: pulse = 0.35
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
	var charging: bool = actor.technique_pose.get("shout", false) or actor.technique_pose.get("gather", false) or actor.technique_pose.get("bay", false) or actor.technique_pose.get("call", false)
	parts.get_node("Head/Sirius").set_state(actor.clock, blaze(), actor.table.charge[actor.body] if charging else 0.0, pulse)

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
	if actor.mode == &"recovery":
		var a := 0.45 + sin(actor.clock * 14.0) * 0.25
		draw_arc(Vector2(-6, 0), 106.0, 0.0, TAU, 32, Color(sirius_halo_color, a), pixel_size * 2.0)
	if actor.technique_pose.get("call", false) or (actor.technique in [&"stream", &"bay", &"hunt_pounce"] and actor.technique_pose.get("shout", false)):
		for ring in 2:
			var grow := fmod(actor.clock * 2.5 + ring * 0.5, 1.0)
			draw_arc(Vector2(84, 0), 20.0 + grow * 90.0, 0.0, TAU, 32, Color(WARNING, 1.0 - grow), pixel_size)
	draw_set_transform(Vector2.ZERO)
