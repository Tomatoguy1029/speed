## Hydra を置いた試遊用の実験場。共有ステージ・セーブ・本番の強さを変更しない。
extends "res://gyms/enemy_lab/enemy_lab.gd"

@export var trial_ship_position := Vector2(400, 0)
@export_range(1.0, 20.0) var trial_attack_multiplier := 6.0
@export var trial_invincible := true
var inspect_tech: StringName=&""
var inspect_attack: StringName=&""
var inspect_pending:=false
var inspect_actor: Node
var capture_path:=""
var capture_at:=1.0
var capturing:=false
var inspect_clock:=0.0
var review_owner: BossActor
var reviewing := false
var review_next:=0.3
var review_counts: Dictionary={}

func _ready() -> void:
	await super._ready()
	if not OS.is_debug_build(): return
	await session.reset({"empty": true, "stage": 4, "ship_pos": [trial_ship_position.x, trial_ship_position.y],
		"invincible": trial_invincible, "hero": "hercules", "config": {"base_attack": ConfigManager.base.base_attack * trial_attack_multiplier}})
	session.perform("boss", {"type": "hydra", "pos": [0, 0]})
	# 読み込み・描画確認用。通常起動の試遊条件を共有設定へ保存しない。
	if OS.get_cmdline_user_args().has("--hydra-split"):
		var hydra=session.run.bosses.actors.back()
		hydra._set_count(8)
		hydra.begin_separation()
	if OS.get_cmdline_user_args().has("--hydra-inspect"):
		session.pinned=trial_ship_position
		session.run.loadout.reset_loadout()
		inspect_actor=session.run.bosses.actors.back()
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--hydra-capture="):capture_path=arg.trim_prefix("--hydra-capture=")
			if arg.begins_with("--hydra-capture-at="):capture_at=float(arg.trim_prefix("--hydra-capture-at="))
			if arg.begins_with("--hydra-tech="):inspect_tech=StringName(arg.trim_prefix("--hydra-tech="))
			if arg.begins_with("--hydra-attack="):inspect_attack=StringName(arg.trim_prefix("--hydra-attack="))
		if inspect_tech!=&"" or inspect_attack!=&"":
			inspect_actor.hsm.set_active(false)
			inspect_actor._set_count(8)
			if inspect_tech in [&"swarm",&"grid"] and not inspect_actor.separated:inspect_actor.begin_separation()
			for n in inspect_actor.necks:n.cd=1e6
			if inspect_attack!=&"" and inspect_actor.def.params.normal_rules.has(inspect_attack):
				var rule: Dictionary=inspect_actor.def.params.normal_rules[inspect_attack]
				var n=inspect_actor._first(rule.kind)
				inspect_actor.table.facing[inspect_actor.body]=-n.base_angle
				n.angle=0.0
				n.length=float(inspect_actor.def.params.neck_rest)
				session.pinned=inspect_actor._head_pos(n)+Vector2(450.0 if float(rule.min)>0.0 else 150.0,0.0)
			inspect_pending=true
	if OS.get_cmdline_user_args().has("--hydra-review"):
		review_owner=session.run.bosses.actors.back()
		reviewing = true
		session.pinned=null
		session.run.state.stats.attack_mult=1000.0
	if OS.get_cmdline_user_args().has("--hydra-arena-edge"):
		var bounds: Rect2=session.run.bosses.actors.back().arena.bounds
		session.pinned=bounds.end-Vector2(220,220)
		session.run.state.ship_pos=session.pinned
		session.run.state.view_center=session.pinned
	_set_mode(3)
	if reviewing:session.live_input=Callable()
	_refresh()

func _notification(what: int)->void:
	if OS.get_cmdline_user_args().has("--hydra-inspect") and what==NOTIFICATION_APPLICATION_FOCUS_OUT:return
	super._notification(what)


func _process(delta: float)->void:
	super._process(delta)
	if capture_path!="" or reviewing:
		session.playing=true
		if session.run.state.phase==RunState.Phase.PAUSED:session.run.command(&"resume")
		inspect_clock+=delta
	if reviewing:
		if not is_instance_valid(review_owner) or not review_owner.has_body():
			print("[hydra-review] PASS drawn routes completed combined growth, separation and bearer defeat; phases=",review_counts)
			get_tree().quit()
			return
		var a=review_owner
		if inspect_clock>40.0:
			print("[hydra-review] FAIL timeout; hp=",a.table.hp[a.body]," count=",a.count," split=",a.separated," phase=",session.run.state.phase," drawing=",session.run.state.drawing," tracing=",session.run.state.tracing," worlds=",session.run.state.world_time)
			get_tree().quit(1)
			return
		review_counts[a.count]=true
		if a.separated:review_counts["separated"]=true
		if inspect_clock>=review_next and a.growth_t<=0.0 and a.separation_t<=0.0 and not session.run.state.tracing and not session.run.state.drawing:
			var at: Vector2=a._head_pos(a.immortal_neck) if a.separated else a.table.pos[a.body]
			var start: Vector2=at-Vector2(180,0)
			session.run.state.ship_pos=start
			session.run.state.ship_vel=Vector2.ZERO
			session.run.state.gauge=1.0
			session.perform("route",{"points":[start,at+Vector2(180,0)],"draw_seconds":0.2})
			review_next=inspect_clock+2.0
	if capture_path!="" and not capturing and is_instance_valid(inspect_actor) and inspect_clock>=capture_at:
		capturing=true
		await RenderingServer.frame_post_draw
		var image: Image=get_viewport().get_texture().get_image()
		var error:=image.save_png(capture_path)
		print("[hydra-visual] ","PASS " if error==OK else "FAIL ",capture_path," tech=",inspect_actor.tech," effects=",inspect_actor.attack_field.effects.size()," world=",inspect_actor._time," phase=",session.run.state.phase)
		get_tree().quit(0 if error==OK else 1)
	if not inspect_pending or not is_instance_valid(inspect_actor) or inspect_actor.separation_t>0.0:return
	if inspect_tech!=&"":
		inspect_actor._tech_cd=0.0
		inspect_actor.combo_wait=0.0
		inspect_pending=not inspect_actor.try_start_tech(inspect_tech,1.0)
	elif inspect_attack!=&"" and inspect_actor.def.params.normal_rules.has(inspect_attack):
		var n=inspect_actor._first(inspect_actor.def.params.normal_rules[inspect_attack].kind)
		n.cd=0.0
		inspect_pending=not inspect_actor.start_normal(inspect_actor.necks.find(n),inspect_attack)
