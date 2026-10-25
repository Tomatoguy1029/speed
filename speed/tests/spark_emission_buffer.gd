## 既存の逐次生成と、最後に残るGPUデータ・リング位置・全体の乱数列を照合する。
extends Node
const BUFFER := preload("res://scripts/render/spark_emission_buffer.gd")
class Reference:
	var capacity: int
	var cursor := 0
	var first := 0
	var pending := PackedFloat32Array()
	func _init(limit: int) -> void: capacity = limit
	func append(pos: Vector2,color: Color,n: int,dir: Vector2,speed: float,life: float,size: float) -> void:
		if pending.is_empty(): first = cursor
		for _i in n:
			var a := randf()*TAU
			var s := speed*(0.3+randf())
			var v := Vector2.from_angle(a)*s*0.6+dir*s*0.8
			var l := life*(0.6+randf()*0.6)
			pending.append_array(PackedFloat32Array([pos.x,pos.y,v.x,v.y,l,l,size*(0.6+randf()*0.8),0.0,color.r*1.6,color.g*1.6,color.b*1.6,1.0]))
			cursor = (cursor+1)%capacity
	func take_frame() -> Dictionary:
		var count := pending.size()/12
		if count>capacity:
			var skip := count-capacity
			pending = pending.slice(skip*12)
			first = (first+skip)%capacity
		var result := {"data":pending,"first":first}
		pending = PackedFloat32Array()
		return result
var passed := 0
var failed := 0
func check(ok: bool,label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)
func exercise(capacity: int,frames: Array,planned := true) -> void:
	var reference := Reference.new(capacity)
	var expected: Array = []
	var randoms: Array = []
	seed(52871)
	for commands: Array in frames:
		for k in commands.size():
			reference.append(Vector2(k*13.3,-8.1),Color(0.45,0.85,0.7),commands[k],Vector2(0.6,-0.8),321.73,0.7,5.0)
			randoms.append([randf(),randi()])
		expected.append(reference.take_frame())
	var next_random := randf()
	var buffer := BUFFER.new(capacity)
	var at := 0
	seed(52871)
	for frame in frames.size():
		var commands: Array = frames[frame]
		if planned:
			var minimum := 0
			for n in commands: minimum += n
			buffer.reserve(minimum)
		for k in commands.size():
			buffer.append(Vector2(k*13.3,-8.1),Color(0.45,0.85,0.7),commands[k],Vector2(0.6,-0.8),321.73,0.7,5.0)
			check([randf(),randi()]==randoms[at],"生成間に使う全体の乱数列を維持")
			at += 1
			if planned: check(buffer._pending.size()<=capacity*12,"予告された発生列は既存の容量以内で組み立てる")
		var actual := buffer.take_frame()
		check(actual.data.to_byte_array()==expected[frame].data.to_byte_array(),"最後に表示される全float32が既存実装とビット一致")
		if not actual.data.is_empty(): check(actual.first==expected[frame].first,"折返し・複数burst・超過後の送信先が一致")
		check(buffer.is_empty(),"フレーム後に保留データを解放")
	check(randf()==next_random,"組立時には全体の乱数を消費しない")
	check(buffer.cursor==reference.cursor,"フレームをまたぐリング位置を維持")
func _ready() -> void:
	for capacity in [1,7,32]:
		exercise(capacity,[[],[0],[1],[capacity-1,1],[capacity,1],[capacity*2+7],[3,0,capacity,2],[1,1,1],[]])
	exercise(16384,[[10,20],[32775],[1000,8000,20000],[2],[0],[]])
	exercise(32,[[70,5],[1,100],[3],[]],false)
	var many: Array = []
	for _i in 1000: many.append(1)
	exercise(32,[many,[1],[]])
	var buffer := BUFFER.new(7)
	buffer.append(Vector2.ZERO,Color.WHITE,20,Vector2.ZERO,1.0,1.0,1.0)
	var cursor: int = buffer.cursor
	buffer.clear()
	check(buffer.take_frame().data.is_empty() and buffer.cursor==cursor,"破棄時はサンプルを解放し、リング順は維持")
	# 予告前の発生と、予告した下限に含めない追加発生も元の末尾選択に一致する。
	var results: Array = []
	for before in [true,false]:
		seed(9201)
		var mixed = Reference.new(32) if before else BUFFER.new(32)
		mixed.append(Vector2.ZERO,Color.WHITE,10,Vector2.UP,200.0,0.7,5.0)
		if not before: mixed.reserve(40)
		mixed.append(Vector2.ONE,Color.RED,15,Vector2.RIGHT,200.0,0.7,5.0)
		mixed.append(Vector2.ONE,Color.GREEN,25,Vector2.DOWN,200.0,0.7,5.0)
		mixed.append(Vector2.ZERO,Color.BLUE,7,Vector2.LEFT,200.0,0.7,5.0)
		if not before: mixed.reserve(70)
		mixed.append(Vector2.ONE,Color.WHITE,50,Vector2.UP,200.0,0.7,5.0)
		mixed.append(Vector2.ZERO,Color.RED,30,Vector2.RIGHT,200.0,0.7,5.0)
		results.append([mixed.take_frame(),randf()])
	check(results[0][0].data.to_byte_array()==results[1][0].data.to_byte_array() \
		and results[0][0].first==results[1][0].first and results[0][1]==results[1][1],"予告前・予告外・同一フレームの複数バッチも粒と乱数が一致")
	print("[spark_emission_buffer] passed=%d failed=%d" % [passed,failed])
	get_tree().quit(1 if failed else 0)
