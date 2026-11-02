extends WeaponVisual
## ギアアップ：ブースト中、機体が炎をまとう。最初は弱く、進むほど指数関数的に炎が大きく激しくなり、後ろへたなびく。
## 炎は共通ピクセル炎（GearFire）で、機首から機体の下を通って後ろへ流れる。

var gear: GearFire

func setup(render: RunPresentation, owner_behavior) -> void:
	super(render, owner_behavior)
	gear = GearFire.new()
	gear.z_index = -1
	gear.visibility_layer = 1 | RenderPipeline.GLOW_LAYER
	rm._layers.ship.add_child(gear)
	gear.setup(1.82 * cfg.character_scale)
	node = gear

func setup_frame(parent: Node2D, pixel: float) -> void:
	gear = GearFire.new()
	gear.z_index = -1
	gear.visibility_layer = 1 | RenderPipeline.GLOW_LAYER
	parent.add_child(gear)
	gear.setup(pixel)
	node = gear

func tick(_dt: float) -> void:
	frame_tick(world_dt(),state.ship_pos,state.ship_heading,behavior.ctx.loadout.boost_distance/cfg.draw_length,active and state.tracing)

func frame_tick(dt: float, pos: Vector2, heading: Vector2, progress: float, enabled: bool) -> void:
	var x := clampf(progress,0.0,1.0)
	gear.set_power((exp(3.0*x)-1.0)/(exp(3.0)-1.0),enabled)
	gear.position = pos+heading*9.0*gear._cell
	gear.step(dt,heading.angle())
