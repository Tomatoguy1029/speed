## 演出が所有したラン状態だけを保存する。別ランや保存設定へ触れない。
extends RefCounted
var saved: Dictionary = {}
func capture(a: BossActor) -> void:
	var s := a.run_state
	saved = {"controls_locked":s.controls_locked,"encounter_protected":s.encounter_protected,
		"cinematic_bars":s.cinematic_bars,"cinematic_camera":s.cinematic_camera,
		"cinematic_hide_enemies":s.cinematic_hide_enemies,"view_center":s.view_center,
		"view_half":s.view_half,"camera_zoom":s.camera_zoom,"world_scale":s.world_scale,
		"ship_heading":s.ship_heading}
func restore(a: BossActor) -> void:
	if saved.is_empty(): return
	for key in saved: a.run_state.set(key,saved[key])
	a.run_state.drawing=false
	a.run_state.tracing=false
	a.run_state.ship_vel=Vector2.ZERO
	saved.clear()
static func frame(a: BossActor, center: Vector2, zoom: float) -> void:
	a.run_state.view_center=center
	a.run_state.camera_zoom=maxf(0.01,zoom)
	var size: Vector2=a.ctx.options.get("view_size",a.get_viewport().get_visible_rect().size)
	if size.x<=0.0 or size.y<=0.0: size=Vector2(1280,720)
	a.run_state.view_half=size/(2.0*a.run_state.camera_zoom)
