## HP0以後を実時間で所有する。通常戦闘と保存通知は終端で一度だけ接続する。
extends RefCounted
const MODULES: Array[StringName] = [&"legendary_stern",&"legendary_keel",&"legendary_sail",&"legendary_compass"]
const BEAR = [Vector2(0,-130),Vector2(-35,-65),Vector2(-80,-15),Vector2(-145,10),Vector2(-130,70),Vector2(-55,80),Vector2(-80,-15)]
var actor: BossActor
var stage: StringName = &""
var time := 0.0
var center := Vector2.ZERO
var core := Vector2.ZERO
var guide := PackedVector2Array()
var strokes := PackedVector2Array()
var began := false
var completed := false
var base_zoom := 1.0
var line := PackedVector2Array()
var dim := 0.0
var split := 0.0
func _init(a: BossActor) -> void: actor=a
func begin() -> void:
	var a = actor
	a.cancel_attack();a.cycle.cancel();a.picaro.pause(true)
	a.mode=&"finale";a.table.hp[a.body]=1.0;a.table.guard[a.body]=1.0
	stage=&"release";time=0.0
	center=a.table.pos[a.body]
	core=center+Vector2(-100,0)
	base_zoom=maxf(0.1,a.run_state.camera_zoom)
	a.run_state.controls_locked=true;a.run_state.cinematic_bars=1.0;a.run_state.cinematic_camera=true
	a.run_state.drawing=false;a.run_state.tracing=false;a.run_state.ship_vel=Vector2.ZERO
	a.run_state.world_scale=0.0
	a.presentation_event.emit({"cue":&"core_released","pos":core,"radius":100.0})
func advance(dt: float, intent: Intent) -> void:
	if stage==&"" or completed: return
	var a = actor
	time+=dt
	a.clock+=dt
	a.run_state.world_scale=0.0
	a.run_state.view_center=center
	a.run_state.camera_zoom=base_zoom*0.75
	match stage:
		&"release":
			core=center+Vector2(-100,-minf(200.0,time*120.0))
			if time>=2.0:
				a.presentation_event.emit({"cue":&"bear_roar","pos":core,"radius":180.0})
				stage=&"combine";time=0.0
		&"combine":
			if time>=2.0:
				a.run_state.final_modules=MODULES.duplicate()
				stage=&"pose";time=0.0
		&"pose":
			var pose := PackedVector2Array()
			for j in 13:
				var angle := -PI*0.25+j*TAU/15.0
				pose.append(center+Vector2.from_angle(angle)*(280.0+j*12.0))
			a.body_override=pose;a.table.pos[a.body]=pose[0]
			if time>=0.8:
				stage=&"input";time=0.0
				a.run_state.controls_locked=false;a.run_state.cinematic_bars=0.0
				for j in 49: guide.append(center+Vector2.from_angle(j*TAU/48.0)*430.0)
		&"input":
			if intent.press or intent.alt_press:
				if not began:
					began=true
					strokes.append(intent.pen)
			if began and intent.has_cursor and (strokes.is_empty() or strokes[-1].distance_to(intent.pen)>3.0): strokes.append(intent.pen)
			if began and intent.pen_release:
				stage=&"strikes";time=0.0
				a.run_state.controls_locked=true
				a.run_state.drawing=false
			else: a.run_state.drawing=began
	a._update_body();a._presentation.queue_redraw()
func dispose() -> void:
	actor.run_state.controls_locked=false;actor.run_state.cinematic_bars=0.0;actor.run_state.cinematic_camera=false
