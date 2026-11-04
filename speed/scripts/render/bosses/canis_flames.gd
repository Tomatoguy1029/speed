## 炎の表示だけを持つ。表示プリセットの寿命を戦闘へ返さない。
extends Node2D
const FIRE := preload("res://scripts/bosses/canis_major/pixel_fire_display.gd")
const COMPONENTS := preload("res://scripts/render/fx/visual_effect_components.gd")
var presets := {}
var burning_preset: PixelFireSettings
var trail_preset: PixelFireSettings
var displays := {}
var fading := {}
var _clock := -1.0
func setup(scope: ContentResourceScope, assets: Dictionary) -> void:
	top_level = true
	for asset: Dictionary in assets.values():
		if asset.has("canis_flame"): presets[int(asset.canis_flame)] = COMPONENTS.fire("boss/move/canis_major/"+("sirius" if "jet" in asset.path else "blaze" if "ignite" in asset.path else "sirius_flame"),scope.resources[asset.path])
		if asset.get("canis_burning",false): burning_preset = COMPONENTS.fire("boss/move/canis_major/blaze",scope.resources[asset.path])
		if asset.get("canis_trail",false): trail_preset = COMPONENTS.fire("boss/move/canis_major/sirius",scope.resources[asset.path])
func clear() -> void:
	for display in displays.values(): display.queue_free()
	displays.clear()
	fading.clear()
func frame_event(event: Dictionary) -> void:
	if event.type==&"canis_ignite_arrived":
		var effect: Dictionary = event.duplicate(true)
		effect.started = _clock
		fading[event.id] = effect
func _cloud(key: String, preset: PixelFireSettings, samples: Array, clock: float, angle: float = 0.0, opacity: float = 1.0) -> void:
	if preset==null: return
	if not displays.has(key):
		var fire := FIRE.new()
		fire.setup(preset)
		add_child(fire)
		displays[key] = fire
	displays[key].cloud(samples,clock,angle)
	displays[key].modulate.a = opacity
func _transfer(effect: Dictionary, progress: float) -> Array:
	var to: Vector2 = effect.to-effect.from
	var side := to.normalized().orthogonal()
	var samples := []
	for k in 5:
		var p := clampf(progress-k*0.045,0.0,1.0)
		samples.append({"pos":effect.from+to*p+side*sin(p*PI)*minf(60.0,to.length()*0.15),"radius":lerpf(22.0,8.0,k/4.0),"seed":k})
	return samples
func apply_frame(rows: Array, clock: float, burning: Array = [], mouth: Dictionary = {}, fire_visual: Array = []) -> void:
	if _clock>clock: clear()
	_clock = clock
	var seen := {}
	var clouds := {}
	var replacement := {}
	for jet: Dictionary in fire_visual: replacement[int(jet.id)] = true
	for row: Dictionary in rows:
		if row.kind==1:
			if replacement.has(int(row.get("jet_id",0))): continue
			if not clouds.has(row.profile): clouds[row.profile] = []
			clouds[row.profile].append(row)
		elif row.kind==2 and row.length>0.0:
			var key := "焼け跡:%d" % row.id
			seen[key] = true
			var samples := []
			var count := maxi(2,ceili(row.length/18.0))
			for n in count: samples.append({"pos":row.pos+Vector2((n+0.5)/count*row.length,sin(n*2.4)*row.radius*0.3).rotated(row.angle),"radius":row.radius*(0.7+0.3*sin(n*1.7+clock*4.0)),"seed":n})
			_cloud(key,trail_preset,samples,clock,row.angle,0.8*(1.0-smoothstep(0.5,1.0,row.age/row.life)))
		elif row.kind==3:
			var key := "点火:%d" % row.id
			seen[key] = true
			_cloud(key,presets.get(row.profile),_transfer(row,clampf(row.age/maxf(row.life,0.001),0.0,1.0)),clock)
	for profile in clouds:
		var key := "放射:%d" % profile
		seen[key] = true
		_cloud(key,presets.get(profile),clouds[profile],clock)
	for id in fading.keys():
		var event: Dictionary = fading[id]
		var preset: PixelFireSettings = presets.get(event.profile)
		if preset==null or clock-float(event.started)>=preset.lifetime:
			fading.erase(id)
			continue
		var key := "点火:%d" % id
		seen[key] = true
		_cloud(key,preset,_transfer({"from":event.from,"to":event.pos},1.0),clock,0.0,1.0-smoothstep(0.0,preset.lifetime,clock-float(event.started)))
	for row: Dictionary in burning:
		var key := "猟犬:%d" % row.actor
		seen[key] = true
		_cloud(key,burning_preset,[{"pos":row.position,"radius":row.radius*1.6,"seed":row.actor}],clock,0.0,0.4 if row.flash>0.0 else 1.0)
	if not mouth.is_empty() and (mouth.get("active",false) or rows.any(func(row): return row.kind==3) or not fading.is_empty()):
		var key := "口元の点火"
		seen[key] = true
		_cloud(key,presets.get(mouth.get("profile",5)),[{"pos":mouth.position,"radius":28.0,"seed":0}],clock)
	for key in displays.keys():
		if not seen.has(key):
			displays[key].queue_free()
			displays.erase(key)
