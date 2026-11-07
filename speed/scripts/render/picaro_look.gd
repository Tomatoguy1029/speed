## ピカロの共通の見た目に使う資源を、実行時に一度だけ作る。
## シェーダー（shaders/picaro.gdshader）へ渡すノイズと、敵の絵ごとの余白つきの絵・距離場・縁の画素を持つ。
extends RefCounted

## 星を吸い込んで形になるまでの秒数（C++ の picaro_form_time と同じ）。
const FORM_TIME := 2.5
## 吸い込む星の数と、1つの星が飛び込む秒数。
const STARS := 24
const FLY := 0.5
## 塊が絵より大きくうねれるように、絵のまわりに足す余白の割合。
const PAD_RATE := 0.4

static var _noise: ImageTexture
static var _forms := {}

## R・G はなめらかな値ノイズ（8テクセルごとの格子、上下左右でつながる）、B・A は1テクセルごとのばらばらの値。
static func noise_texture() -> ImageTexture:
	if _noise != null: return _noise
	var size := 64
	var cells := 8
	var rng := RandomNumberGenerator.new()
	rng.seed = 7341
	var lattice := []
	for channel in 2:
		var grid := PackedFloat32Array()
		for i in cells*cells: grid.append(rng.randf())
		lattice.append(grid)
	var image := Image.create_empty(size,size,false,Image.FORMAT_RGBA8)
	var step := size/cells
	for y in size:
		for x in size:
			var values := []
			for channel in 2:
				var grid: PackedFloat32Array = lattice[channel]
				var cx := x/step
				var cy := y/step
				var fx := float(x%step)/step
				var fy := float(y%step)/step
				fx = fx*fx*(3.0-2.0*fx)
				fy = fy*fy*(3.0-2.0*fy)
				var a := grid[cy*cells+cx]
				var b := grid[cy*cells+(cx+1)%cells]
				var c := grid[((cy+1)%cells)*cells+cx]
				var d := grid[((cy+1)%cells)*cells+(cx+1)%cells]
				values.append(lerpf(lerpf(a,b,fx),lerpf(c,d,fx),fy))
			image.set_pixel(x,y,Color(values[0],values[1],rng.randf(),rng.randf()))
	_noise = ImageTexture.create_from_image(image)
	return _noise

## 敵の絵から、余白つきの絵・符号つき距離場（中が負、画素単位）・面積と同じ円の半径・縁の画素を作る。
static func form(texture: Texture2D) -> Dictionary:
	if texture==null: return {}
	var key := texture.get_rid()
	if _forms.has(key): return _forms[key]
	var source := texture.get_image()
	if source==null: return {}
	if source.is_compressed(): source.decompress()
	source.convert(Image.FORMAT_RGBA8)
	var w := source.get_width()
	var h := source.get_height()
	var pad := ceili(maxf(w,h)*PAD_RATE)
	var width := w+pad*2
	var height := h+pad*2
	var padded := Image.create_empty(width,height,false,Image.FORMAT_RGBA8)
	padded.blit_rect(source,Rect2i(0,0,w,h),Vector2i(pad,pad))
	var inside := PackedByteArray()
	inside.resize(width*height)
	var area := 0
	for y in height:
		for x in width:
			var filled := padded.get_pixel(x,y).a>0.4
			inside[y*width+x] = 1 if filled else 0
			if filled: area += 1
	var outside_distance := _distance(inside,width,height,0)
	var inside_distance := _distance(inside,width,height,1)
	var field := Image.create_empty(width,height,false,Image.FORMAT_RF)
	var edges := PackedVector2Array()
	var center := Vector2(width,height)*0.5
	for y in height:
		for x in width:
			var i := y*width+x
			if inside[i]==1:
				field.set_pixel(x,y,Color(-inside_distance[i]+0.5,0,0))
				if inside_distance[i]<=1.0: edges.append(Vector2(x+0.5,y+0.5)-center)
			else:
				field.set_pixel(x,y,Color(outside_distance[i]-0.5,0,0))
	var result := {"texture":ImageTexture.create_from_image(padded),"sdf":ImageTexture.create_from_image(field),"size":Vector2(width,height),"source_size":Vector2(w,h),"radius":sqrt(area/PI),"edges":edges}
	_forms[key] = result
	return result

## target と違う画素までのおよその距離（縦横1・斜め1.414で前後2回なぞる）。
static func _distance(inside: PackedByteArray,width: int,height: int,target: int) -> PackedFloat32Array:
	var far := float(width+height)
	var d := PackedFloat32Array()
	d.resize(width*height)
	for i in width*height: d[i] = far if inside[i]==target else 0.0
	for y in height:
		for x in width:
			var i := y*width+x
			if d[i]==0.0: continue
			var v := d[i]
			if x>0: v = minf(v,d[i-1]+1.0)
			if y>0:
				v = minf(v,d[i-width]+1.0)
				if x>0: v = minf(v,d[i-width-1]+1.414)
				if x<width-1: v = minf(v,d[i-width+1]+1.414)
			d[i] = v
	for y in range(height-1,-1,-1):
		for x in range(width-1,-1,-1):
			var i := y*width+x
			if d[i]==0.0: continue
			var v := d[i]
			if x<width-1: v = minf(v,d[i+1]+1.0)
			if y<height-1:
				v = minf(v,d[i+width]+1.0)
				if x<width-1: v = minf(v,d[i+width+1]+1.414)
				if x>0: v = minf(v,d[i+width-1]+1.414)
			d[i] = v
	return d

## 星を順に吸い込んで育つ進み：g＝吸い込んだ割合、jig＝吸い込んだ直後の震え、done＝最後の星が届く時刻。
static func growth(age: float,seed: float) -> Dictionary:
	var count := 0
	var jig := 0.0
	for i in STARS:
		var hit := star_start(i,seed)+FLY
		if age>=hit:
			count += 1
			if age-hit<0.18: jig = maxf(jig,1.0-(age-hit)/0.18)
	return {"g":float(count)/STARS,"jig":jig,"done":star_start(STARS-1,seed)+FLY}

static func star_start(index: int,seed: float) -> float:
	return 0.05+index*((FORM_TIME-FLY-0.1)/(STARS-1))+hash01(index*3.3+seed)*0.04

static func hash01(n: float) -> float:
	var s := sin(n*127.1+311.7)*43758.5453
	return s-floorf(s)
