## 共通PixelFireの密度・輪郭・発光を、戦闘の炎の粒の位置へ合わせる表示用アダプター。
## 判定は変更しない。各プリセットはビジュアル編集の「炎」で保存する。
@tool
extends PixelFire

var _paint_frame := -1

func apply_settings() -> void:
	super()
	_paint_frame = -1

func setup(preset: PixelFireSettings) -> void:
	settings = preset
	manual = true
	emitting = false

## 1つの炎の場へまとめ、粒ごとのNode・Viewportを作らない。
func cloud(samples: Array, clock: float, heading := 0.0) -> void:
	if not is_instance_valid(density_view): return
	if _settings_dirty: apply_settings()
	visible = not samples.is_empty()
	if not visible: return
	var frame := floori(clock * maxf(1.0,settings.update_fps))
	if frame == _paint_frame: return
	_paint_frame = frame
	var angle := heading + PI * 0.5
	var low := Vector2(INF,INF)
	var high := Vector2(-INF,-INF)
	for sample in samples:
		var point: Vector2 = Vector2(sample.pos).rotated(-angle)
		var radius := float(sample.radius)
		low = low.min(point-Vector2.ONE*radius*1.4)
		high = high.max(point+Vector2.ONE*radius*1.4)
	var center := (low+high)*0.5
	var size := settings.field_size
	var units := maxf(0.25,maxf((high.x-low.x)/size.x,(high.y-low.y)/size.y))
	var offset := size*0.5-_origin
	rotation = angle
	scale = Vector2.ONE*units
	position = (center-offset*units).rotated(angle)
	particles.clear()
	var sample_count := mini(samples.size(),maxi(1,settings.capacity/3))
	for slot in sample_count:
		var index := roundi(slot/maxf(1.0,sample_count-1)*(samples.size()-1))
		var sample: Dictionary = samples[index]
		var seed_value := float(sample.get("seed",index))
		var center_point: Vector2 = (Vector2(sample.pos).rotated(-angle)-center)/units+offset
		for layer in 3:
			if settings.layer_sizes[layer] <= 0 or settings.layer_lifetimes[layer] <= 0: continue
			var budget := maxi(1,settings.capacity/maxi(1,sample_count)/3)
			var count := mini(budget,clampi(ceili(settings.birth_rate/28.0*settings.layer_rates[layer]),1,5))
			if settings.layer_rates[layer] <= 0: continue
			for k in count:
				if particles.size() >= settings.capacity: break
				var phase := seed_value*2.39996+k*1.7+layer
				var cycle := fposmod(clock*settings.rise_speed/108.0+phase,1.0)
				var life := maxf(0.1,settings.lifetime*settings.layer_lifetimes[layer])
				var source_age := float(sample.get("age",0.0))/maxf(float(sample.get("life",1.0)),0.001)
				var age := life*(0.1+cycle*0.35+source_age*0.2)
				var jitter := Vector2(sin(phase+clock*2.0)*settings.sway*0.12,cos(phase+clock)*settings.source_size.y*0.12)/units
				var radius := float(sample.radius)/units*settings.particle_size/27.0*settings.layer_sizes[layer]
				particles.append({"pos":center_point+jitter,"age":age,"life":life,"radius":radius,"rise":0.0,"phase":phase,"layer":layer})
	_clock = clock
	_render_density()

## 爆発の円いっぱいへ炎が広がり、塊ごとに崩れて消える。
func burst(at: Vector2, radius: float, progress: float, clock: float) -> void:
	var samples: Array = [{"pos":at,"radius":radius*0.65,"seed":0}]
	var expand := lerpf(0.3,1.0,smoothstep(0.0,0.18,progress))
	for k in 18:
		var phase := k*2.39996
		var reach := radius*expand*(0.35+0.28*sin(k*1.7)*sin(k*1.7))
		var u := Vector2.from_angle(phase+progress*0.25)
		samples.append({"pos":at+u*reach,"radius":radius*(0.5-progress*0.22)*(0.8+0.2*sin(k*2.8)),"seed":k+1})
	cloud(samples,clock)
	modulate.a = 1.0-smoothstep(0.5,1.0,progress)
