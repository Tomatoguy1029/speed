## 炎の表示だけを持つ。表示プリセットの寿命を戦闘へ返さない。
extends Node2D
const FIRE := preload("res://scripts/bosses/canis_major/pixel_fire_display.gd")
const COMPONENTS := preload("res://scripts/render/fx/visual_effect_components.gd")
var presets := {}
var trail_preset: PixelFireSettings
var displays := {}
var _clock := -1.0
func setup(scope: ContentResourceScope, assets: Dictionary) -> void:
	top_level = true
	for asset: Dictionary in assets.values():
		if asset.has("canis_flame"): presets[int(asset.canis_flame)] = COMPONENTS.fire("boss/move/canis_major/"+("sirius" if "jet" in asset.path else "blaze" if "ignite" in asset.path else "sirius_flame"),scope.resources[asset.path])
		if asset.get("canis_trail",false): trail_preset = COMPONENTS.fire("boss/move/canis_major/sirius",scope.resources[asset.path])
func clear() -> void:
	for display in displays.values(): display.queue_free()
	displays.clear()
func frame_event(_event: Dictionary) -> void:
	pass
func _cloud(key: String, preset: PixelFireSettings, samples: Array, clock: float, angle: float = 0.0, opacity: float = 1.0) -> void:
	if preset==null: return
	if not displays.has(key):
		var fire := FIRE.new()
		fire.setup(preset)
		add_child(fire)
		displays[key] = fire
	displays[key].cloud(samples,clock,angle)
	displays[key].modulate.a = opacity
func apply_frame(rows: Array, clock: float, _burning: Array = [], _mouth: Dictionary = {}, fire_visual: Array = []) -> void:
	if _clock>clock: clear()
	_clock = clock
	var seen := {}
	var clouds := {}
	var replacement := {}
	var continuous := {}
	var replacement_trails := {}
	for jet: Dictionary in fire_visual:
		replacement[int(jet.id)] = true
		if int(jet.get("trail_id",0))!=0: replacement_trails[int(jet.trail_id)] = true
		if jet.get("continuous",false): continuous[int(jet.technique)] = true
	for row: Dictionary in rows:
		if row.kind==1:
			if replacement.has(int(row.get("jet_id",0))) or row.get("harmful",false) and continuous.has(int(row.get("technique",0))): continue
			if not clouds.has(row.profile): clouds[row.profile] = []
			clouds[row.profile].append(row)
		elif row.kind==2 and row.length>0.0:
			if replacement_trails.has(int(row.id)): continue
			var key := "焼け跡:%d" % row.id
			seen[key] = true
			var samples := []
			var count := maxi(2,ceili(row.length/18.0))
			for n in count: samples.append({"pos":row.pos+Vector2((n+0.5)/count*row.length,sin(n*2.4)*row.radius*0.3).rotated(row.angle),"radius":row.radius*(0.7+0.3*sin(n*1.7+clock*4.0)),"seed":n})
			_cloud(key,trail_preset,samples,clock,row.angle,0.8*(1.0-smoothstep(0.5,1.0,row.age/row.life)))
	for profile in clouds:
		var key := "放射:%d" % profile
		seen[key] = true
		_cloud(key,presets.get(profile),clouds[profile],clock)
	for key in displays.keys():
		if not seen.has(key):
			displays[key].queue_free()
			displays.erase(key)
