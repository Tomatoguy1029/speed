## セーブを使わない描画確認。各技と決着を独立したウィンドウへ映す。
extends Node
func _ready() -> void:
	var stage: RuntimeStage=ContentManager.runtime_stage(5).duplicate(true)
	stage.boss_enabled=false
	var session:=RunManager.create_session(self,{"lab":true,"stage":stage,"stage_index":5,"seed":305,"hud":false},true)
	session.auto_step=false
	var sim: RunSimulation=session.sim
	sim.field.bodies.clear();sim.ship.invincible=true
	sim.state.phase=RunState.Phase.PLAY
	sim.state.ship_pos=Vector2(300,0);sim.state.enemy_aim=sim.state.ship_pos
	sim.bosses.spawn(load("res://data/bosses/draco.tres"),Vector2.ZERO)
	var actor=sim.bosses.actor
	actor.selection_enabled=false
	for size in [Vector2i(1280,720),Vector2i(900,900)]:
		get_window().size=size
		for id in actor._moves:
			actor.cancel_attack();actor.cycle.cancel();actor.picaro.clear()
			sim.projectiles.clear_hostile();sim.enemies.table.pos[actor.body]=Vector2.ZERO
			actor.position=Vector2.ZERO;actor.rotation=0;sim.enemies.table.facing[actor.body]=0.0
			sim.state.ship_pos=Vector2(300,0);sim.state.enemy_aim=sim.state.ship_pos
			sim.state.view_center=Vector2.ZERO;sim.state.camera_zoom=0.45;sim.state.view_half=Vector2(size)/0.9
			actor.start_attack(id)
			for frame in ceili((float(actor.rule().warn)+1.0)*120.0): actor.sim_tick(1.0/120.0,1.0/120.0)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("/tmp/speed15-draco-%s-%d.png" % [id,size.x])
	actor.cancel_attack();actor.cycle.cancel()
	actor.phase=3;actor.table.guard[actor.body]=0;actor.table.hp[actor.body]=1.0
	sim.combat.damage_enemy(actor.body,1e6,{"cause":&"shot"})
	for target in [&"release",&"combine",&"input",&"strikes",&"last",&"sight",&"split"]:
		for frame in 1200:
			var it:=Intent.new()
			if actor.finale.stage==&"input" and target!=&"input":
				it.press=not actor.finale.began;it.has_cursor=true;it.pen=Vector2(100,100);it.pen_release=actor.finale.began
			actor.advance_finale(1.0/120.0,it)
			if actor.finale.stage==target: break
		actor.advance_finale(0.15,Intent.new())
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/speed15-draco-finale-%s.png" % target)
	session.free()
	print("[draco_visual] captured")
	get_tree().quit()
