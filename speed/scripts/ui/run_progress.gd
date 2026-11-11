## C++の時計とボス状態から描く進行表示。独立した時計を進めず、途中開始・復帰も同じ投影を使う。
extends Control
const Phase := preload("res://scripts/data_types/generated/run_ids.gd").ENUMS.Phase
const ART_SIZE := Vector2(640,360)
const LEFT := 205.0
const RIGHT := 435.0
const GAUGE_Y := 39.0
const FADE_OUT := 1.6
const FADE_IN := 1.0
const CYAN := Color("#70d8ec")
const RED := Color("#ff718a")
const SHIP := preload("res://assets/pixel/airship.png")
## 目標アイコンの仮素材。ボスHPには付けない。
const HEAD := preload("res://assets/pixel/monoceros/layers/head_base.png")
const ARMOR := preload("res://assets/pixel/monoceros/layers/head_armor.png")
const GOLD := preload("res://assets/pixel/monoceros/layers/head_gold_armor.png")
var font: Font
var _view := {"progress":0.0,"progress_alpha":0.0,"hp_alpha":0.0,"hp_ratio":0.0,"countdown":""}

static func project(ui: Dictionary) -> Dictionary:
	var clock: Dictionary=ui.get("stage_clock",{})
	var elapsed:=float(ui.get("run_time",0.0))
	var boss_at:=float(clock.get("boss_at",-1.0))
	var view: Dictionary={"progress":clampf(elapsed/maxf(boss_at,0.001),0.0,1.0),"progress_alpha":0.0,"hp_alpha":0.0,"hp_ratio":0.0,"countdown":""}
	var body: Dictionary={}
	for candidate: Dictionary in ui.get("boss_bodies",[]):
		if int(candidate.get("mode",4))<4 and candidate.has("hp"):
			body=candidate
			break
	if not body.is_empty():
		var age:=float(body.get("clock",0.0))
		view.progress=1.0
		view.progress_alpha=1.0-smoothstep(0.0,FADE_OUT,age)
		view.hp_alpha=smoothstep(FADE_OUT,FADE_OUT+FADE_IN,age)
		view.hp_ratio=clampf(float(body.hp)/maxf(1.0,float(body.get("max_hp",1.0))),0.0,1.0)
	elif boss_at>=0.0 and not clock.get("boss_spawned",false):
		view.progress_alpha=1.0
	var limit:=float(clock.get("time_limit",-1.0))
	if limit>=0.0 and limit-elapsed<=300.0:
		var seconds:=maxi(0,ceili(limit-elapsed))
		view.countdown="%d:%02d" % [seconds/60,seconds%60]
	return view

func apply_snapshot(ui: Dictionary,show_status: bool=true) -> void:
	_view=project(ui)
	visible=show_status and float(ui.get("cinematic_bars",0.0))<=0.0 and not ui.get("boss_finish",{}).get("active",false) and int(ui.get("phase",-1)) not in [Phase.Dying,Phase.Finishing,Phase.Ended]
	queue_redraw()

func _art_transform() -> void:
	var factor:=minf(size.x/ART_SIZE.x,size.y/ART_SIZE.y)
	draw_set_transform((size-ART_SIZE*factor)*0.5,0.0,Vector2.ONE*factor)

func _draw() -> void:
	if font==null:return
	_art_transform()
	if _view.progress_alpha>0.0:_draw_progress(_view.progress,_view.progress_alpha)
	if _view.hp_alpha>0.0:_draw_health(_view.hp_ratio,_view.hp_alpha)
	if _view.countdown!="":
		draw_string(font,Vector2(285,GAUGE_Y-13),_view.countdown,HORIZONTAL_ALIGNMENT_CENTER,70,13,RED)
	draw_set_transform(Vector2.ZERO)

func _draw_progress(progress: float,alpha: float) -> void:
	var current:=lerpf(LEFT,RIGHT-24.0,progress)
	draw_line(Vector2(LEFT,GAUGE_Y),Vector2(RIGHT,GAUGE_Y),Color(Color("#385668"),alpha),2)
	for i in 20:
		var x:=LEFT+i*(RIGHT-LEFT)/20.0
		var color:=CYAN if x<=lerpf(LEFT,RIGHT,progress) else Color("#283b49")
		draw_rect(Rect2(x,GAUGE_Y-3,7,6),Color(color,alpha))
	_draw_boss(Vector2(RIGHT,GAUGE_Y),alpha)
	var factor:=minf(size.x/ART_SIZE.x,size.y/ART_SIZE.y)
	draw_set_transform((size-ART_SIZE*factor)*0.5+Vector2(current,GAUGE_Y)*factor,PI/2,Vector2.ONE*factor)
	draw_texture_rect(SHIP,Rect2(-5.1,-11.5,10.2,23),false,Color(Color("#c9f7ff"),alpha))
	_art_transform()

func _draw_health(ratio: float,alpha: float) -> void:
	var area:=Rect2(LEFT,GAUGE_Y-4,RIGHT-LEFT,8)
	draw_rect(area,Color(Color("#241c28"),alpha))
	draw_rect(Rect2(LEFT,GAUGE_Y-3,(RIGHT-LEFT)*ratio,6),Color(RED,alpha))
	draw_line(Vector2(LEFT,GAUGE_Y-3),Vector2(LEFT+(RIGHT-LEFT)*ratio,GAUGE_Y-3),Color(Color("#ffb2c2"),alpha),1)
	draw_rect(area,Color(Color("#7b4357"),alpha),false,1)

func _draw_boss(at: Vector2,alpha: float) -> void:
	draw_circle(at,16,Color(Color("#301825"),alpha))
	draw_arc(at,16,0,TAU,48,Color(RED,alpha),1)
	var destination:=Rect2(at-Vector2(10.78,15.4),Vector2(21.56,30.8))
	for texture: Texture2D in [HEAD,ARMOR,GOLD]:
		draw_texture_rect_region(texture,destination,Rect2(195,130,74,106),Color(Color("#ffc6d0"),alpha))
