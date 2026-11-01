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

func tick(_dt: float) -> void:
	var dt := world_dt()
	var x := clampf(behavior.ctx.loadout.boost_distance / cfg.draw_length, 0.0, 1.0)
	gear.set_power((exp(3.0 * x) - 1.0) / (exp(3.0) - 1.0), active and state.tracing)
	gear.position = state.ship_pos + state.ship_heading * 9.0 * 1.82 * cfg.character_scale
	gear.step(dt, state.ship_heading.angle())
