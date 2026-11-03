## 独立コピーで実行。値型の死亡通知だけで移動・姿勢・寿命を再現できることを確かめる。
extends SceneTree
const DEATHS := preload("res://scripts/render/elite_deaths.gd")
var scope := ContentResourceScope.new()
var entries := {}
var effect: Node
var failures := 0
const VIEW := Rect2(-1000,-1000,2000,2000)

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func add_look(id: int, name: String, pump := false) -> void:
	var path := "res://data/visuals/looks/%s.tres" % name
	var look := load(path) as EnemyLook
	look = look.duplicate()
	look.prepared = true
	look.source_path = path
	look.painted_armors[""] = look.armor
	scope.resources[path] = look
	entries[id] = {"id":id,"path":path,"paint":"","role":6,"pump":pump,"settings":{"key_energy":1.0,"key_angle":-30.0,"fill_energy":0.2,"fill_angle":120.0,"height":0.4,"ambient":0.08,"normal_strength":1.0}}

func event(id: int, visual := 1) -> Dictionary:
	return {"id":id,"pos":Vector2(20,30),"world_t":10.0,"death_visual":{"visual_id":visual,"velocity":Vector2(80,-40),"radius":30.0,"angle":0.7,"mode":1,"charge":0.6,"timer":0.2,"rest":0.5,"ruler_side":0,"pump_scale":2.0 if visual==2 else 0.0,"pump_full":0.8,"pump_stored":0.6}}

func check_fragment_motion() -> void:
	var baked: Resource = scope.resources[DEATHS.MASKS]
	var texture: Texture2D = baked.get_meta("masks")["res://data/visuals/looks/shield.tres"]
	var atlas := texture.get_image()
	var width := atlas.get_width()/4
	var height := atlas.get_height()/4
	var moved := 0
	var first_matches := true
	var last_empty := true
	for y in height:
		for x in width:
			var first := atlas.get_pixel(x,y)
			first_matches = first_matches and roundi(first.r*255)==x and roundi(first.g*255)==y and first.b>0.99
			last_empty = last_empty and atlas.get_pixel(width*3+x,height*3+y).b<0.01
			for frame in range(1,15):
				var sample := atlas.get_pixel(width*(frame%4)+x,height*(frame/4)+y)
				if sample.b>0.99 and (roundi(sample.r*255)!=x or roundi(sample.g*255)!=y): moved+=1
	check(first_matches,"最初のコマは元画像をそのまま参照")
	check(last_empty,"最後のコマは全破片が消える")
	check(moved>0,"アルファを削るだけでなく破片内の絵も動く")

func run() -> void:
	scope.resources[DEATHS.MASKS] = load(DEATHS.MASKS)
	check_fragment_motion()
	add_look(1,"shield")
	add_look(2,"pump",true)
	effect = DEATHS.new()
	root.add_child(effect)
	effect.setup(scope,entries)
	effect.add_event(event(1),10.0,VIEW)
	effect.add_event(event(2,2),10.0,VIEW)
	effect.step(10.25,VIEW)
	var display: Node = effect._displays[1]
	var row: Dictionary = display._previous_row
	check(Vector2(row.transforms[4],row.transforms[5]).is_equal_approx(Vector2(40,20)),"進行方向と速度を死亡通知から保持")
	check(is_equal_approx(row.colors[0].a,0.5),"0.5秒の中点")
	var pump: RefCounted = effect._displays[2]._pump
	var material: ShaderMaterial = pump._bodies[0].material
	check(is_equal_approx(material.get_shader_parameter("full"),0.8),"ポンプの膨張を保持")
	check(is_equal_approx(material.get_shader_parameter("stored_full"),0.6),"収納量を保持")
	check(not pump._winds[0].visible,"死亡後の吸引風を重ねない")
	effect.step(10.5,VIEW)
	check(effect._active.is_empty(),"0.5秒で確実に寿命終了")
	check(display._parts[0].base.multimesh.visible_instance_count==0,"寿命後の描画を消す")
	effect.add_event(event(3),10.6,VIEW)
	check(effect._active.is_empty(),"遅延した過去イベントを再表示しない")
	var distant := event(4); distant.pos=Vector2(10000,10000)
	effect.add_event(distant,10.0,VIEW)
	check(effect._active.is_empty(),"到達しない画面外の敵を生成しない")
	effect.clear()
	for i in 256: effect.add_event(event(i+100),10.0,VIEW)
	check(effect._active.size()==256,"128体を超えても撃破表示を落とさない")
	var start := Time.get_ticks_usec()
	for i in 60: effect.step(10.0+float(i)/120.0,VIEW)
	var cpu_ms := float(Time.get_ticks_usec()-start)/60000.0
	check(effect._displays.size()==1,"同じ外観は1表示にまとめる")
	check(effect._displays[1]._parts[0].base.multimesh.visible_instance_count==256,"本体の描画をバッチ化")
	effect.clear()
	for i in 128: effect.add_event(event(i+500,2),10.0,VIEW)
	effect.step(10.0,VIEW)
	start = Time.get_ticks_usec()
	for i in 60: effect.step(10.0+float(i)/120.0,VIEW)
	var pump_cpu_ms := float(Time.get_ticks_usec()-start)/60000.0
	check(effect._displays[2]._pump._count==128,"ポンプ同時撃破も保持")
	print("128 pump bodies CPU update mean=%.3f ms (headless; GPU excluded)" % pump_cpu_ms)
	effect.step(9.0,VIEW)
	check(effect._active.is_empty(),"巻き戻しで古い死体を消す")
	print("elite_deaths failures=%d, 256 bodies CPU update mean=%.3f ms (headless; GPU excluded)" % [failures,cpu_ms])
	effect.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
